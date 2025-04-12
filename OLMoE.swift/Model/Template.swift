//
//  Template.swift
//  OLMoE.swift
//
//  Created by Ken Adamson on 11/17/24.
//


import Foundation
import llama

/// A structure that defines how to format conversations for different LLM architectures
public struct Template {
    /// Represents prefix and suffix text to wrap around different message types
    public typealias Attachment = (prefix: String, suffix: String)

    /// Formatting for system messages
    public let system: Attachment

    /// Formatting for user messages
    public let user: Attachment

    /// Formatting for bot/assistant messages
    public let bot: Attachment

    /// Optional system prompt to set context for the conversation
    public let systemPrompt: String?

    /// Sequence that indicates the end of the model's response
    public let stopSequence: String?

    /// Text to prepend to the entire conversation
    public let prefix: String

    /// Whether to drop the last character of the bot prefix
    public let shouldDropLast: Bool

    /// Creates a new template for formatting conversation messages
    /// - Parameters:
    ///   - prefix: Text to prepend to the entire conversation
    ///   - system: Formatting for system messages
    ///   - user: Formatting for user messages
    ///   - bot: Formatting for bot/assistant messages
    ///   - stopSequence: Sequence indicating end of response
    ///   - systemPrompt: Initial system message for context
    ///   - shouldDropLast: Whether to drop last character of bot prefix
    public init(
        prefix: String = "",
        system: Attachment? = nil,
        user: Attachment? = nil,
        bot: Attachment? = nil,
        stopSequence: String? = nil,
        systemPrompt: String?,
        shouldDropLast: Bool = false
    ) {
        self.system = system ?? ("", "")
        self.user = user  ?? ("", "")
        self.bot = bot ?? ("", "")
        self.stopSequence = stopSequence
        self.systemPrompt = systemPrompt
        self.prefix = prefix
        self.shouldDropLast = shouldDropLast
    }

    /// Closure that formats input and history into model-ready prompt
    /// - Parameters:
    ///   - input: Current user input to process
    ///   - history: Previous conversation messages
    ///   - llmInstance: Reference to LLM instance for state checking
    /// - Returns: Formatted string ready for model inference
    /// - Note: Handles both new conversations and continued chats with saved state
    public var preprocess: (_ input: String, _ history: [Chat], _ llmInstance: LLM) -> String {
        return { [self] input, history, llmInstance in
            // If the state is restored, only preprocess the new input
            if llmInstance.savedState != nil {

                // Return only the new user input formatted
                var processed = prefix
                processed += "\(user.prefix)\(input)\(user.suffix)"
                processed += bot.prefix

                return processed
            } else {
                // Full preprocessing for the first input or reset state
                var processed = prefix
                if let systemPrompt {
                    processed += "\(system.prefix)\(systemPrompt)\(system.suffix)"
                }
                // Create a new array without the last chat since we're adding current input separately
                let historyWithoutLast = history.dropLast()

                for chat in historyWithoutLast {
                    if chat.role == .user {
                        processed += "\(user.prefix)\(chat.content)\(user.suffix)"
                    } else {
                        processed += "\(bot.prefix)\(chat.content)\(bot.suffix)"
                    }
                }
                // Add the current user input
                processed += "\(user.prefix)\(input)\(user.suffix)"
                // Handle bot prefix for the new response
                if shouldDropLast {
                    processed += bot.prefix.dropLast()
                } else {
                    processed += bot.prefix
                }
                return processed
            }
        }
    }

    /// Creates a template for OLMoE-style models
    /// - Parameter systemPrompt: Optional system message for context
    /// - Returns: Template configured for OLMoE format
    public static func OLMoE(_ systemPrompt: String? = nil) -> Template {
        return Template(
            prefix: "<|endoftext|>",
            system: ("<|system|>\n", "\n"),
            user: ("<|user|>\n", "\n"),
            bot: ("<|assistant|>\n", "\n"),
            stopSequence: "<|endoftext|>",
            systemPrompt: systemPrompt
        )
    }

    /// Creates a template for ChatML format
    /// - Parameter systemPrompt: Optional system message for context
    /// - Returns: Template configured for ChatML format
    public static func chatML(_ systemPrompt: String? = nil) -> Template {
        return Template(
            system: ("<|im_start|>system\n", "<|im_end|>\n"),
            user: ("<|im_start|>user\n", "<|im_end|>\n"),
            bot: ("<|im_start|>assistant\n", "<|im_end|>\n"),
            stopSequence: "<|im_end|>",
            systemPrompt: systemPrompt
        )
    }

    /// Creates a template for Alpaca-style models
    /// - Parameter systemPrompt: Optional system message for context
    /// - Returns: Template configured for Alpaca format
    public static func alpaca(_ systemPrompt: String? = nil) -> Template {
        return Template(
            system: ("", "\n\n"),
            user: ("### Instruction:\n", "\n\n"),
            bot: ("### Response:\n", "\n\n"),
            stopSequence: "###",
            systemPrompt: systemPrompt
        )
    }

    /// Creates a template for LLaMA-style models
    /// - Parameter systemPrompt: Optional system message for context
    /// - Returns: Template configured for LLaMA format
    public static func llama(_ systemPrompt: String? = nil) -> Template {
        return Template(
            prefix: "[INST] ",
            system: ("<<SYS>>\n", "\n<</SYS>>\n\n"),
            user: ("", " [/INST]"),
            bot: (" ", "</s><s>[INST] "),
            stopSequence: "</s>",
            systemPrompt: systemPrompt,
            shouldDropLast: true
        )
    }

    /// Template configured for Mistral-style models
    public static let mistral = Template(
        user: ("[INST] ", " [/INST]"),
        bot: ("", "</s> "),
        stopSequence: "</s>",
        systemPrompt: nil
    )
}
