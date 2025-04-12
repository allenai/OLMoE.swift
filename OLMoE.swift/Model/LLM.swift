import Foundation
import llama


public typealias Token = llama_token
public typealias Model = OpaquePointer

public struct Chat: Identifiable, Equatable {
    public var id: UUID? // Optional unique identifier
    public var role: Role
    public var content: String

    public init(id: UUID? = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// An actor that manages access to LLM inference operations to ensure thread safety
@globalActor public actor InferenceActor {
    static public let shared = InferenceActor()
}

/// Base class for Large Language Model inference
/// Provides functionality for text generation, chat history management, and model state control
open class LLM: ObservableObject {
    /// The underlying LLaMA model pointer
    public var model: Model

    /// Array of chat messages representing the conversation history
    public var history: [Chat]

    /// Closure to preprocess input before sending to the model
    /// - Parameters:
    ///   - input: The raw input string
    ///   - history: Current chat history
    ///   - llmInstance: Reference to the LLM instance
    /// - Returns: Processed input string ready for the model
    public var preprocess: (_ input: String, _ history: [Chat], _ llmInstance: LLM) -> String = { input, _, _ in return input }

    /// Closure called when generation is complete with the final output
    /// - Parameter output: The complete generated response
    public var postprocess: (_ output: String) -> Void = { print($0) }

    /// Closure called during generation with incremental output
    /// - Parameter outputDelta: New text fragment (nil when generation ends)
    public var update: (_ outputDelta: String?) -> Void = { _ in }

    /// Template controlling model input/output formatting
    /// Setting this updates preprocess and stop sequence configuration
    public var template: Template? = nil {
        didSet {
            guard let template else {
                preprocess = { input, _, _ in return input }
                stopSequence = nil
                stopSequenceLength = 0
                return
            }
            preprocess = template.preprocess
            if let stopSequence = template.stopSequence?.utf8CString {
                self.stopSequence = stopSequence
                stopSequenceLength = stopSequence.count - 1
            } else {
                stopSequence = nil
                stopSequenceLength = 0
            }
        }
    }

    /// Top-K sampling parameter - limits vocabulary to K most likely tokens
    public var topK: Int32

    /// Top-P sampling parameter - limits vocabulary to tokens comprising top P probability mass
    public var topP: Float

    /// Temperature parameter controlling randomness of sampling (higher = more random)
    public var temp: Float

    /// Path to the model file
    public var path: [CChar]

    /// Flag to enable test response mode
    public var loopBackTestResponse: Bool = false

    /// Cached model state for continuation of conversations
    public var savedState: Data?

    /// Metrics for tracking inference performance and token counts
    public var metrics = InferenceMetrics()

    /// Current generated output text
    @Published public private(set) var output = ""
    @MainActor public func setOutput(to newOutput: consuming String) {
        output = newOutput.trimmingCharacters(in: .whitespaces)
    }

    private var batch: llama_batch!
    private var context: Context!
    private var decoded = ""
    private var inferenceTask: Task<Void, Never>?
    private var input: String = ""
    private var isAvailable = true
    private let newlineToken: Token
    private let maxTokenCount: Int
    private var multibyteCharacter: [CUnsignedChar] = []
    private var params: llama_context_params
    private var sampler: UnsafeMutablePointer<llama_sampler>?
    private var stopSequence: ContiguousArray<CChar>?
    private var stopSequenceLength: Int
    private let totalTokenCount: Int
    private var updateProgress: (Double) -> Void = { _ in }
    private var nPast: Int32 = 0 // Track number of tokens processed
    private var inputTokenCount: Int32 = 0

    public init(
        from path: String,
        stopSequence: String? = nil,
        history: [Chat] = [],
        seed: UInt32 = .random(in: .min ... .max),
        topK: Int32 = 40,
        topP: Float = 0.95,
        temp: Float = 0.8,
        maxTokenCount: Int32 = 2048
    ) {
        self.path = path.cString(using: .utf8)!
        var modelParams = llama_model_default_params()
        #if targetEnvironment(simulator)
            modelParams.n_gpu_layers = 0
        #endif
        let model = llama_load_model_from_file(self.path, modelParams)!
        self.params = llama_context_default_params()
        let processorCount = Int32(ProcessInfo().processorCount)
        self.maxTokenCount = Int(min(maxTokenCount, llama_n_ctx_train(model)))
        // self.params.seed = seed
        self.params.n_ctx = UInt32(self.maxTokenCount)
        self.params.n_batch = self.params.n_ctx
        self.params.n_threads = processorCount
        self.params.n_threads_batch = processorCount
        self.topK = topK
        self.topP = topP
        self.temp = temp
        self.model = model
        self.history = history
        self.totalTokenCount = Int(llama_n_vocab(model))
        self.newlineToken = model.newLineToken
        self.stopSequence = stopSequence?.utf8CString
        self.stopSequenceLength = (self.stopSequence?.count ?? 1) - 1
        self.batch = llama_batch_init(Int32(self.maxTokenCount), 0, 1)

        /// sampler to run with default parameters
        let sparams = llama_sampler_chain_default_params()
        self.sampler = llama_sampler_chain_init(sparams)

        if let sampler = self.sampler {
            llama_sampler_chain_add(sampler, llama_sampler_init_top_k(topK))
            llama_sampler_chain_add(sampler, llama_sampler_init_top_p(topP, 1))
            llama_sampler_chain_add(sampler, llama_sampler_init_temp(temp))
            llama_sampler_chain_add(sampler, llama_sampler_init_dist(seed))
        }
    }

    deinit {
        llama_free_model(self.model)
    }

    public convenience init(
        from url: URL,
        template: Template,
        history: [Chat] = [],
        seed: UInt32 = .random(in: .min ... .max),
        topK: Int32 = 40,
        topP: Float = 0.95,
        temp: Float = 0.8,
        maxTokenCount: Int32 = 2048
    ) {
        self.init(
            from: url.path,
            stopSequence: template.stopSequence,
            history: history,
            seed: seed,
            topK: topK,
            topP: topP,
            temp: temp,
            maxTokenCount: maxTokenCount
        )
        self.preprocess = template.preprocess
        self.template = template
    }

    /// Stops ongoing text generation
    @InferenceActor
    public func stop() {
        guard self.inferenceTask != nil else { return }

        self.inferenceTask?.cancel()
        self.inferenceTask = nil
        self.batch.clear()
    }

    @InferenceActor
    private func predictNextToken() async -> Token {
        /// Ensure context exists; otherwise, return end token
        guard let context = self.context else { return self.model.endToken }

        /// Check if the task has been canceled
        guard !Task.isCancelled else { return self.model.endToken }
        guard self.inferenceTask != nil else { return self.model.endToken }

        /// Ensure the batch is valid
        guard self.batch.n_tokens > 0 else {
            print("Error: Batch is empty or invalid.")
            return model.endToken
        }

        /// Check if the batch size is within limits
        guard self.batch.n_tokens < self.maxTokenCount else {
            print("Error: Batch token limit exceeded.")
            return model.endToken
        }

        guard let sampler = self.sampler else {
            fatalError("Sampler not initialized")
        }

        /// Sample the next token with a valid context
        let token = llama_sampler_sample(sampler, context.pointer, self.batch.n_tokens - 1) // Use batch token count for correct context

        metrics.recordToken()

        self.batch.clear()
        self.batch.add(token, self.nPast, [0], true)
        self.nPast += 1 // Increment the token count after predicting a new token
        context.decode(self.batch)
        return token
    }

    /// Clears conversation history and resets model state
    @InferenceActor
    public func clearHistory() async {
        history.removeAll()
        nPast = 0 /// Reset token count when clearing history
        await setOutput(to: "")
        context = nil
        savedState = nil
        self.batch.clear()
        /// Reset any other state variables if necessary
        /// For example, if you have a variable tracking the current conversation context:
        /// currentContext = nil
    }

    @InferenceActor
    private func tokenizeAndBatchInput(message input: borrowing String) -> Bool {
        guard self.inferenceTask != nil else { return false }
        guard !input.isEmpty else { return false }
        context = context ?? .init(model, params)
        let tokens = encode(input)
        self.inputTokenCount = Int32(tokens.count)

        metrics.inputTokenCount = self.inputTokenCount

        if self.maxTokenCount <= self.nPast + self.inputTokenCount {
            self.trimKvCache()
        }
        for (i, token) in tokens.enumerated() {
            let isLastToken = i == tokens.count - 1

            self.batch.add(token, self.nPast, [0], isLastToken)
            nPast += 1
        }

        /// Check batch has not been cleared by a side effect (stop button) at the time of decoding
        guard self.batch.n_tokens > 0 else { return false }

        self.context.decode(self.batch)
        return true
    }

    /// Decodes a token, checks for the stop sequence, and yields decoded text.
    /// If the complete stop sequence is found, it stops yielding and returns false.
    @InferenceActor
    private func emitDecoded(token: Token, to output: borrowing AsyncStream<String>.Continuation) -> Bool {
        struct saved {
            static var stopSequenceEndIndex = 0
            static var letters: [CChar] = []
        }
        guard self.inferenceTask != nil else { return false }
        guard token != model.endToken else { return false }

        let word = decode(token) /// Decode the token directly

        guard let stopSequence else {
            output.yield(word)
            return true
        }

        /// Existing stop sequence handling logic
        var found = 0 < saved.stopSequenceEndIndex
        var letters: [CChar] = []
        for letter in word.utf8CString {
            guard letter != 0 else { break }
            if letter == stopSequence[saved.stopSequenceEndIndex] {
                saved.stopSequenceEndIndex += 1
                found = true
                saved.letters.append(letter)
                guard saved.stopSequenceEndIndex == stopSequenceLength else { continue }
                saved.stopSequenceEndIndex = 0
                saved.letters.removeAll()
                return false
            } else if found {
                saved.stopSequenceEndIndex = 0
                if !saved.letters.isEmpty {
                    let prefix = String(cString: saved.letters + [0])
                    output.yield(prefix + word)
                    saved.letters.removeAll()
                }
                output.yield(word)
                return true
            }
            letters.append(letter)
        }
        if !letters.isEmpty {
            output.yield(found ? String(cString: letters + [0]) : word)
        }
        return true
    }

    @InferenceActor
    private func generateResponseStream(from input: String) -> AsyncStream<String> {
        AsyncStream<String> { output in
            Task { [weak self] in
                guard let self = self else { return output.finish() } /// Safely unwrap `self`
                /// Use `self` safely now that it's unwrapped

                guard self.inferenceTask != nil else { return output.finish() }

                defer {
                    if !FeatureFlags.useLLMCaching {
                        self.context = nil
                    }
                }

                guard self.tokenizeAndBatchInput(message: input) else {
                    return output.finish()
                }

                metrics.start()
                var token = await self.predictNextToken()
                while self.emitDecoded(token: token, to: output) {
                    if self.nPast >= self.maxTokenCount {
                        self.trimKvCache()
                    }
                    token = await self.predictNextToken()
                }

                metrics.stop()
                output.finish()
            }
        }
    }

    /// Halves the llama_kv_cache by removing the oldest half of tokens and shifting the newer half to the beginning.
    /// Updates `nPast` to reflect the reduced cache size.
    @InferenceActor
    private func trimKvCache() {
        let seq_id: Int32 = 0
        let beginning: Int32 = 0
        let middle = Int32(self.maxTokenCount / 2)

        /// Remove the oldest half
        llama_kv_cache_seq_rm(self.context.pointer, seq_id, beginning, middle)

        /// Shift the newer half to the start
        llama_kv_cache_seq_add(
            self.context.pointer,
            seq_id,
            middle,
            Int32(self.maxTokenCount), -middle
        )

        /// Update nPast
        let kvCacheTokenCount: Int32 = llama_get_kv_cache_token_count(self.context.pointer)
        self.nPast = kvCacheTokenCount
        print("kv cache trimmed: llama_kv_cache(\(kvCacheTokenCount)    nPast(\(self.nPast))")
    }

    private func getTestLoopbackResponse() -> AsyncStream<String> {
        return AsyncStream { continuation  in
            Task {
                continuation.yield("This is a test loop-back response:\n")
                for i in 0...5 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000 / 2)
                    continuation.yield("\(i) - \(input)\n")
                }
                continuation.finish()
            }
        }
    }

    @InferenceActor
    public func performInference(to input: String, with makeOutputFrom: @escaping (AsyncStream<String>) async -> String) async {
        self.inferenceTask?.cancel() /// Cancel any ongoing inference task
        self.inferenceTask = Task { [weak self] in
            guard let self = self else { return }

            self.input = input
            let processedInput = self.preprocess(input, self.history, self)
            let responseStream = self.loopBackTestResponse
                ? self.getTestLoopbackResponse()
                : self.generateResponseStream(from: processedInput)

            /// Generate the output string using the async closure
            let output = (await makeOutputFrom(responseStream)).trimmingCharacters(in: .whitespacesAndNewlines)

            await MainActor.run {
                if !output.isEmpty {
                    /// Update history and process the final output on the main actor
                    self.history.append(Chat(role: .bot, content: output))
                }


                self.postprocess(output)
            }

            self.inputTokenCount = 0
            /// Save the state after generating a response
            if FeatureFlags.useLLMCaching {
                self.savedState = saveState()
            }

            if Task.isCancelled {
                return
            }
        }

        await inferenceTask?.value
    }

    /// Generates a response to the given input
    /// - Parameter input: User input text to respond to
    /// - Note: Updates history and output property with generated response
    open func respond(to input: String) async {
        /// Restore the state before generating a response
        if let savedState = FeatureFlags.useLLMCaching ? self.savedState : nil {
            restoreState(from: savedState)
        }

        await performInference(to: input) { [self] response in
            await setOutput(to: "")
            for await responseDelta in response {
                update(responseDelta)
                await setOutput(to: output + responseDelta)
            }
            update(nil)
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)


            self.rollbackLastUserInputIfEmptyResponse(trimmedOutput)

            await setOutput(to: trimmedOutput)
            return output
        }
    }

    /// If the model fails to produce a response (empty output), remove the last user input's tokens
    /// from the KV cache to prevent the model's internal state from being "poisoned" by bad input.
    private func rollbackLastUserInputIfEmptyResponse(_ response: String) {
        if response.isEmpty && self.inputTokenCount > 0 {
            let seq_id = Int32(0)
            let startIndex = self.nPast - self.inputTokenCount
            let endIndex = self.nPast
            llama_kv_cache_seq_rm(self.context.pointer, seq_id, startIndex, endIndex)
        }
    }

    private func decode(_ token: Token) -> String {
        multibyteCharacter.removeAll(keepingCapacity: true) /// Reset multibyte buffer
        return model.decode(token, with: &multibyteCharacter)
    }

    /// Encodes text into model tokens
    /// - Parameter text: Input text to encode
    /// - Returns: Array of token IDs
    @inlinable
    public func encode(_ text: borrowing String) -> [Token] {
        model.encode(text)
    }
}


extension LLM {
    /// Saves the current model state
    /// - Returns: Data object containing serialized state, or nil if saving fails
    /// - Note: Used for continuing conversations across multiple interactions
    public func saveState() -> Data? {
        /// Ensure the context exists
        guard let contextPointer = self.context?.pointer else {
            print("Error: llama_context pointer is nil.")
            return nil
        }

        /// Get the size of the state
        let stateSize = llama_state_get_size(contextPointer)
        guard stateSize > 0 else {
            print("Error: Unable to retrieve state size.")
            return nil
        }

        /// Allocate a buffer for the state data
        var stateData = Data(count: stateSize)
        stateData.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            if let baseAddress = pointer.baseAddress {
                let bytesWritten = llama_state_get_data(contextPointer, baseAddress.assumingMemoryBound(to: UInt8.self), stateSize)
                assert(bytesWritten == stateSize, "Error: Written state size does not match expected size.")
            }
        }
        return stateData
    }

    /// Restores a previously saved model state
    /// - Parameter stateData: Serialized state data from saveState()
    public func restoreState(from stateData: Data) {
        /// Ensure the context exists
        guard let contextPointer = self.context?.pointer else {
            print("Error: llama_context pointer is nil.")
            return
        }

        /// Set the state data
        stateData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            if let baseAddress = pointer.baseAddress {
                let bytesRead = llama_state_set_data(contextPointer, baseAddress.assumingMemoryBound(to: UInt8.self), stateData.count)
                assert(bytesRead == stateData.count, "Error: Read state size does not match expected size.")
            }
        }

        let beginningOfSequenceOffset: Int32 = 1
        self.nPast = llama_get_kv_cache_token_count(self.context.pointer) + beginningOfSequenceOffset
    }
}


