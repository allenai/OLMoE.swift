import Foundation

enum AppConstants {
    enum Model {
        static let filename = "OLMoE-latest"
        static let downloadURL = "https://dolma-artifacts.org/app/\(filename).gguf"
        static let playgroundURL = "https://playground.allenai.org/?model=olmoe-0125"
    }

    static let UnableToAnswerMessage = NSLocalizedString("UnableToAnswerMessage", comment: "Message shown when the model is unable to answer")
    static let maxResponseAttempts = 3 // How many times the model will attempt to answer the question before showing the unable to answer message
}
