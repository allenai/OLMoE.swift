//
//  DisclaimerPageView.swift
//  OLMoE.swift
//
//  Created by Thomas Jones on 11/13/24.
//


import SwiftUI

struct DisclaimerHandlers {
    /// A closure to set the active disclaimer.
    var setActiveDisclaimer: (Disclaimer?) -> Void

    /// A closure to set whether outside tap dismiss is allowed.
    var setAllowOutsideTapDismiss: (Bool) -> Void

    /// A closure to set the cancel action.
    var setCancelAction: ((() -> Void)?) -> Void

    /// A closure to set the confirm action.
    var setConfirmAction: (@escaping () -> Void) -> Void

    /// A closure to set whether to show the disclaimer page.
    var setShowDisclaimerPage: (Bool) -> Void
}

class DisclaimerState: ObservableObject {
#if DEBUG
    @Published private var hasSeenDisclaimer: Bool = false
#else
    @AppStorage("hasSeenDisclaimer") private var hasSeenDisclaimer : Bool = false
#endif
    /// A published property indicating whether to show the disclaimer page.
    @Published var showDisclaimerPage: Bool = false

    /// A published property holding the active disclaimer.
    @Published var activeDisclaimer: Disclaimer? = nil

    /// A published property indicating whether outside tap dismiss is allowed.
    @Published var allowOutsideTapDismiss: Bool = false

    /// A closure for the confirmation action.
    var onConfirm: (() -> Void)?

    /// A closure for the cancellation action.
    var onCancel: (() -> Void)?

    /// The index of the current disclaimer page.
    private var disclaimerPageIndex: Int = 0

    /// An array of disclaimers.
    let disclaimers: [Disclaimer] = [
        Disclaimers.FullDisclaimer()
    ]

    /// Displays the initial disclaimer if it hasn't been seen yet.
    func showInitialDisclaimer() {
        if !hasSeenDisclaimer {
            activeDisclaimer = disclaimers[disclaimerPageIndex]
            allowOutsideTapDismiss = false
            onCancel = nil
            onConfirm = nextDisclaimerPage
            showDisclaimerPage = true
        }
    }

    /// Advances to the next disclaimer page or dismisses the disclaimer if all have been seen.
    private func nextDisclaimerPage() {
        disclaimerPageIndex += 1
        if disclaimerPageIndex >= disclaimers.count {
            activeDisclaimer = nil
            disclaimerPageIndex = 0
            onConfirm = nil
            showDisclaimerPage = false
            hasSeenDisclaimer = true
        } else {
            activeDisclaimer = disclaimers[disclaimerPageIndex]
            onConfirm = nextDisclaimerPage
            onCancel = nil
            showDisclaimerPage = true
        }
    }
}

struct DisclaimerPageData {
    /// The title of the disclaimer page.
    let title: String

    /// The text content of the disclaimer.
    let text: String

    /// The text for the confirmation button.
    let buttonText: String
}

struct DisclaimerPage: View {
    /// A typealias for a button configuration.
    typealias PageButton = (text: String, onTap: () -> Void)

    /// The message content of the disclaimer.
    let message: String

    /// The title of the disclaimer.
    let title: String

    /// An array of header-text pairs for additional information.
    let titleText: [HeaderTextPair]

    /// The configuration for the confirmation button.
    let confirm: PageButton

    /// The configuration for the optional cancel button.
    let cancel: PageButton?

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !title.isEmpty {
                    Text(title)
                        .font(.title())
                        .multilineTextAlignment(.center)
                }

                if !message.isEmpty {
                    Text(.init(message))
                        .font(.body())
                        .multilineTextAlignment(.leading)
                }

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(titleText) { t in
                        HeaderTextPairView(header: t.header, text: t.text)
                    }
                }

                HStack(spacing: 12) {
                    if let cancel = cancel {
                        Button(cancel.text) {
                            cancel.onTap()
                        }
                        .buttonStyle(.SecondaryButton)
                    }

                    Button(confirm.text) {
                        confirm.onTap()
                    }
                    .buttonStyle(.PrimaryButton)
                }
            }
            .padding([.horizontal], 12)
            .padding([.vertical], 24)
        }
    }
}

#Preview("DisclaimerPage") {
    DisclaimerPage(
        message: "Message",
        title: "Title",
        titleText: [HeaderTextPair](),
        confirm: (text: "Confirm", onTap: { print("Confirmed") }),
        cancel: (text: "Cancel", onTap: { print("Cancelled") })
    )
}
