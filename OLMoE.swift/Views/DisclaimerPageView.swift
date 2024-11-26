//
//  DisclaimerPageView.swift
//  OLMoE.swift
//
//  Created by Thomas Jones on 11/13/24.
//

import SwiftUI

struct DisclaimerHandlers {
    var setActiveDisclaimer: (Disclaimer?) -> Void
    var setAllowOutsideTapDismiss: (Bool) -> Void
    var setCancelAction: ((() -> Void)?) -> Void
    var setConfirmAction: (@escaping () -> Void) -> Void
    var setShowDisclaimerPage: (Bool) -> Void
}

class DisclaimerState: ObservableObject {
#if DEBUG
    @Published private var hasSeenDisclaimer: Bool = false
#else
    @AppStorage("hasSeenDisclaimer") private var hasSeenDisclaimer : Bool = false
#endif
    @Published var showDisclaimerPage : Bool = false
    @Published var activeDisclaimer: Disclaimer? = nil
    @Published var allowOutsideTapDismiss: Bool = false
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    private var disclaimerPageIndex: Int = 0

    let disclaimers: [Disclaimer] = [
        Disclaimers.LimitationDisclaimer(),
        Disclaimers.PrivacyDisclaimer(),
        Disclaimers.AcknowledgementDisclaimer()
    ]

    func showInitialDisclaimer() {
        if !hasSeenDisclaimer {
            activeDisclaimer = disclaimers[disclaimerPageIndex]
            allowOutsideTapDismiss = false
            onCancel = nil
            onConfirm = nextDisclaimerPage
            showDisclaimerPage = true
        }
    }

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
    let title: String
    let text: String
    let buttonText: String
}

struct DisclaimerPage: View {
    typealias PageButton = (text: String, onTap: () -> Void)

    let allowOutsideTapDismiss: Bool
    @Binding var isPresented: Bool
    let message: String
    let title: String
    let confirm: PageButton
    let cancel: PageButton?

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title())
                .multilineTextAlignment(.center)

            Text(.init(message))
                .font(.body())

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
    }
}

#Preview("DisclaimerPage") {
    DisclaimerPage(
        allowOutsideTapDismiss: false,
        isPresented: .constant(true),
        message: "Message",
        title: "Title",
        confirm: (text: "Confirm", onTap: { print("Confirmed") }),
        cancel: (text: "Cancel", onTap: { print("Cancelled") })
    )
}
