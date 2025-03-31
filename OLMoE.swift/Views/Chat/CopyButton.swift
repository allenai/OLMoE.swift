//
//  CopyButton.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 3/11/25.
//

import SwiftUI

/// Reusable copy button with feedback
struct CopyButton: View {
    let textToCopy: String
    let foregroundColor: Color
    let showLabel: Bool
    let fontSize: Font
    let helpText: String

    @State private var showCopyFeedback = false

    init(
        textToCopy: String,
        foregroundColor: Color = .gray,
        showLabel: Bool = false,
        fontSize: Font = .caption,
        helpText: String = "Copy"
    ) {
        self.textToCopy = textToCopy
        self.foregroundColor = foregroundColor
        self.showLabel = showLabel
        self.fontSize = fontSize
        self.helpText = helpText
    }

    var body: some View {
        Button(action: {
            copyToClipboard()
        }) {
            HStack(spacing: 4) {
                if showCopyFeedback {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color("AccentColor"))
                        .font(fontSize)
                } else {
                    Image("CopyIcon")
                        .font(fontSize)
                }

                if showLabel && showCopyFeedback {
                    Text("Copied")
                        .font(fontSize)
                }
            }
            .foregroundColor(foregroundColor)
        }
        .buttonStyle(PlainButtonStyle())
        .help(helpText)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = textToCopy

        // Show feedback
        withAnimation {
            showCopyFeedback = true
        }

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Hide feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopyFeedback = false
            }
        }
    }
}
