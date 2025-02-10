//
//  ContentView.swift
//  OLMoE.swift
//
//  Created by Luca Soldaini on 2024-09-16.
//


import SwiftUI
import os

class Bot: LLM {
    static let modelFileURL = URL.modelsDirectory.appendingPathComponent(AppConstants.Model.filename).appendingPathExtension("gguf")

    convenience init() {
        let deviceName = UIDevice.current.model
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let currentDate = dateFormatter.string(from: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: Date())

        let systemPrompt = "You are OLMoE (Open Language Mixture of Expert), a small language model running on \(deviceName). You have been developed at the Allen Institute for AI (Ai2) in Seattle, WA, USA. Today is \(currentDate). The time is \(currentTime)."

        guard FileManager.default.fileExists(atPath: Bot.modelFileURL.path) else {
            fatalError("Model file not found. Please download it first.")
        }

//        self.init(from: Bot.modelFileURL, template: .OLMoE(systemPrompt))
        self.init(from: Bot.modelFileURL, template: .OLMoE())
    }
}

struct BotView: View {
    @StateObject var bot: Bot
    @State var input = ""
    @State private var isGenerating = false
    @State private var stopSubmitted = false
    @State private var scrollToBottom = false
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var isSharingConfirmationVisible = false
    @State private var isDeleteHistoryConfirmationVisible = false
    @State private var isScrolledToBottom = true
    @FocusState private var isTextEditorFocused: Bool
    let disclaimerHandlers: DisclaimerHandlers

    // Add new state for text sharing
    @State private var showTextShareSheet = false

    private var hasValidInput: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isInputDisabled: Bool {
        isGenerating || isSharing
    }

    private var isDeleteButtonDisabled: Bool {
        isInputDisabled || bot.history.isEmpty
    }

    private var isChatEmpty: Bool {
        bot.history.isEmpty && !isGenerating && bot.output.isEmpty
    }

    init(_ bot: Bot, disclaimerHandlers: DisclaimerHandlers) {
        _bot = StateObject(wrappedValue: bot)
        self.disclaimerHandlers = disclaimerHandlers
    }

    func shouldShowScrollButton() -> Bool {
        return !isScrolledToBottom
    }

    func respond() {
        isGenerating = true
        #if targetEnvironment(macCatalyst)
            isTextEditorFocused = true
        #else
            isTextEditorFocused = false
        #endif
        stopSubmitted = false
        let originalInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = "" // Clear the input after sending

        // Add the user message to history immediately
        bot.history.append(Chat(role: .user, content: originalInput))
        Task {
            await bot.respond(to: originalInput)
            await MainActor.run {
                bot.setOutput(to: "")
                isGenerating = false
                stopSubmitted = false
                #if targetEnvironment(macCatalyst)
                    isTextEditorFocused = true  // Mac Only. Re-focus after response
                #endif
            }
        }
    }

    func stop() {
        self.stopSubmitted = true
        bot.stop()
    }

    func deleteHistory() {
        Task { @MainActor in
            await bot.clearHistory()
            bot.setOutput(to: "")
             input = "" // Clear the input
        }
    }

    private func formatConversationForSharing() -> String {
        let deviceName = UIDevice.current.model
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        let timestamp = dateFormatter.string(from: Date())

        let header = """
        Conversation with OLMoE (Open Language Mixture of Expert)
        ----------------------------------------

        """

        let conversation = bot.history.map { chat in
            let role = chat.role == .user ? "User" : "OLMoE"
            return "\(role): \(chat.content)"
        }.joined(separator: "\n\n")

        let footer = """

        ----------------------------------------
        Shared from OLMoE - AI2's Open Language Model
        https://github.com/allenai/OLMoE
        """

        return header + conversation + footer
    }

    func shareConversation() {
        isSharing = true
        disclaimerHandlers.setShowDisclaimerPage(false)
        Task {
            do {
                let attestationResult = try await AppAttestManager.performAttest()

                // Prepare payload
                let apiKey = Configuration.apiKey
                let apiUrl = Configuration.apiUrl

                let modelName = AppConstants.Model.filename
                let systemFingerprint = "\(modelName)-\(AppInfo.shared.appId)"

                let messages = bot.history.map { chat in
                    ["role": chat.role == .user ? "user" : "assistant", "content": chat.content]
                }

                let payload: [String: Any] = [
                    "model": modelName,
                    "system_fingerprint": systemFingerprint,
                    "created": Int(Date().timeIntervalSince1970),
                    "messages": messages,
                    "key_id": attestationResult.keyID,
                    "attestation_object": attestationResult.attestationObjectBase64
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: payload)

                guard let url = URL(string: apiUrl), !apiUrl.isEmpty else {
                    print("Invalid URL")
                    await MainActor.run {
                        isSharing = false
                    }
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.httpBody = jsonData
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let responseString = String(data: data, encoding: .utf8)!
                    if let jsonData = responseString.data(using: .utf8),
                       let jsonResult = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                       let body = jsonResult["body"] as? String,
                       let bodyData = body.data(using: .utf8),
                       let bodyJson = try JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
                       let urlString = bodyJson["url"] as? String,
                       let url = URL(string: urlString) {
                        await MainActor.run {
                            self.shareURL = url
                            self.showShareSheet = true
                        }
                        print("Conversation shared successfully")
                    } else {
                        print("Failed to parse response")
                    }
                } else {
                    print("Failed to share conversation")
                }
            } catch {
                let attestError = error as NSError
                if attestError.domain == "AppAttest" {
                    print("Error: \(attestError.localizedDescription)")
                } else {
                    print("Error sharing conversation: \(error)")
                }
            }

            await MainActor.run {
                isSharing = false
            }
        }
    }

    @ViewBuilder
    func shareButton() -> some View {
        if isSharing {
            SpinnerView(color: Color("AccentColor"))
        } else {
            ToolbarButton(action: {
                isTextEditorFocused = false
                // disclaimerHandlers.setActiveDisclaimer(Disclaimers.ShareDisclaimer())
                // disclaimerHandlers.setCancelAction({ disclaimerHandlers.setShowDisclaimerPage(false) })
                // disclaimerHandlers.setAllowOutsideTapDismiss(true)
                // disclaimerHandlers.setConfirmAction({ shareConversation() })
                // disclaimerHandlers.setShowDisclaimerPage(true)
                showTextShareSheet = true
            }, imageName: "square.and.arrow.up")
             .disabled(isSharing || bot.history.isEmpty || isGenerating)
             .opacity(isSharing || bot.history.isEmpty || isGenerating ? 0.5 : 1)
        }
    }

    @ViewBuilder
    func trashButton() -> some View {
        ToolbarButton(action: {
            isTextEditorFocused = false
            isDeleteHistoryConfirmationVisible = true
            stop()
        }, imageName: "trash.fill")
            .alert("Delete history?", isPresented: $isDeleteHistoryConfirmationVisible, actions: {
                Button("Delete", action: deleteHistory)
                Button("Cancel", role: .cancel) {
                    isDeleteHistoryConfirmationVisible = false
                }
            })
            .disabled(isDeleteButtonDisabled)
            .opacity(isDeleteButtonDisabled ? 0.5 : 1)
    }

    @ViewBuilder
    func scrollToBottomButton() -> some View {
        VStack {
            Spacer()

            Button(action: {
                scrollToBottom = true
            }) {
                Image(systemName: "arrow.down")
                    .aspectRatio(contentMode: .fit)
                    .padding(10)
                    .foregroundColor(Color("BackgroundColor"))
                    .background(Color("LightGreen"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(shouldShowScrollButton() ? 1 : 0)
            .transition(.opacity)
            .animation(
                shouldShowScrollButton()
                ? .easeIn(duration: 0.1)
                : .easeOut(duration: 0.3).delay(0.1),
                value: shouldShowScrollButton())
        }
        .padding([.bottom], 4)
    }

    var body: some View {
        GeometryReader { geometry in
            contentView(in: geometry)
        }
    }

    private func contentView(in geometry: GeometryProxy) -> some View {
        ZStack {
            Color("BackgroundColor")
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading) {
                if !isChatEmpty {
                    ScrollViewReader { proxy in
                        ZStack {
                            ChatView(
                                history: bot.history,
                                output: bot.output.trimmingCharacters(in: .whitespacesAndNewlines),
                                isGenerating: $isGenerating,
                                isScrolledToBottom: $isScrolledToBottom,
                                stopSubmitted: $stopSubmitted
                            )
                                .onChange(of: scrollToBottom) { _, newValue in
                                    if newValue {
                                        withAnimation {
                                            proxy.scrollTo(ChatView.BottomID, anchor: .bottom)
                                        }
                                        scrollToBottom = false
                                    }
                                }
                                .gesture(TapGesture().onEnded({
                                    isTextEditorFocused = false
                                }))

                            scrollToBottomButton()
                        }
                    }
                } else {
                    ZStack {
                        VStack{
                            Spacer()
                            Image("Ai2Icon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: min(geometry.size.width, geometry.size.height) * 0.18)
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                if (isChatEmpty) {
                    BotChatBubble(text: String(localized: "Welcome chat message", comment: "Default chat bubble when conversation is empty"), maxWidth: geometry.size.width)
                }

                MessageInputView(
                    input: $input,
                    isGenerating: $isGenerating,
                    stopSubmitted: $stopSubmitted,
                    isTextEditorFocused: $isTextEditorFocused,
                    isInputDisabled: isInputDisabled,
                    hasValidInput: hasValidInput,
                    respond: respond,
                    stop: stop
                )
            }
            .padding(12)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .sheet(isPresented: $showTextShareSheet) {
            ActivityViewController(activityItems: [formatConversationForSharing()])
        }
        .gesture(TapGesture().onEnded({
            isTextEditorFocused = false
        }))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                HStack(spacing: 20) {
                    shareButton()
                    trashButton()
                }
            }
        }
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}


// Add this struct to handle the UIActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

struct ContentView: View {
    /// A shared instance of the background download manager.
    @StateObject private var downloadManager = BackgroundDownloadManager.shared

    /// The state of the disclaimer handling.
    @StateObject private var disclaimerState = DisclaimerState()

    /// The bot instance used for conversation.
    @State private var bot: Bot?

    /// A flag indicating whether to show the info page.
    @State private var showInfoPage: Bool = false

    /// A flag indicating whether the device is supported.
    @State private var isSupportedDevice: Bool = isDeviceSupported()

    /// A flag indicating whether to use mocked model responses.
    @State private var useMockedModelResponse: Bool = false

    /// Logger for tracking events in the ContentView.
    let logger = Logger(subsystem: "com.allenai.olmoe", category: "ContentView")

    public var body: some View {
        ZStack {
            NavigationStack {
                VStack {
                    if !isSupportedDevice && !useMockedModelResponse {
                        UnsupportedDeviceView(
                            proceedAnyway: { isSupportedDevice = true },
                            proceedMocked: {
                                bot?.loopBackTestResponse = true
                                useMockedModelResponse = true
                            }
                        )
                    } else if let bot = bot {
                        BotView(bot, disclaimerHandlers: DisclaimerHandlers(
                            setActiveDisclaimer: { self.disclaimerState.activeDisclaimer = $0 },
                            setAllowOutsideTapDismiss: { self.disclaimerState.allowOutsideTapDismiss = $0 },
                            setCancelAction: { self.disclaimerState.onCancel = $0 },
                            setConfirmAction: { self.disclaimerState.onConfirm = $0 },
                            setShowDisclaimerPage: { self.disclaimerState.showDisclaimerPage = $0 }
                        ))
                    } else {
                        ModelDownloadView()
                    }
                }
                .onChange(of: downloadManager.isModelReady) { newValue in
                    if newValue && bot == nil {
                        initializeBot()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    AppToolbar(
                        leadingContent: {
                            InfoButton(action: { showInfoPage = true })
                        }
                    )
                }
            }
            .onAppear {
                disclaimerState.showInitialDisclaimer()
            }
            .sheet(isPresented: $showInfoPage) {
                SheetWrapper {
                    InfoView(isPresented: $showInfoPage)
                }
            }
            .sheet(isPresented: $disclaimerState.showDisclaimerPage) {
                SheetWrapper {
                    DisclaimerPage(
                        message: disclaimerState.activeDisclaimer?.text ?? "",
                        title: disclaimerState.activeDisclaimer?.title ?? "",
                        titleText: disclaimerState.activeDisclaimer?.headerTextContent ?? [],
                        confirm: DisclaimerPage.PageButton(
                            text: disclaimerState.activeDisclaimer?.buttonText ?? "",
                            onTap: {
                                disclaimerState.onConfirm?()
                            }
                        ),
                        cancel: disclaimerState.onCancel.map { cancelAction in
                            DisclaimerPage.PageButton(
                                text: "Cancel",
                                onTap: {
                                    cancelAction()
                                    disclaimerState.activeDisclaimer = nil
                                }
                            )
                        }
                    )
                }
                .interactiveDismissDisabled(!disclaimerState.allowOutsideTapDismiss)
            }
        }
    }

    /// Checks if the model is ready and initializes the bot if it is.
    private func checkModelAndInitializeBot() {
        if FileManager.default.fileExists(atPath: Bot.modelFileURL.path) {
            downloadManager.isModelReady = true
            initializeBot()
        }
    }

    /// Initializes the bot instance and sets the loopback test response flag.
    private func initializeBot() {
        bot = Bot()
        bot?.loopBackTestResponse = useMockedModelResponse
    }
}
