//
//  HighlightedCodeBlock.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 3/11/25.
//

import SwiftUI
import MarkdownUI
import HighlightSwift

struct HighlightedCodeBlock: View {
    let code: String
    let language: String?

    @State private var highlightResult: HighlightResult?
    @State private var displayLanguage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Language label and copy button
            HStack {
                if let displayLanguage = displayLanguage {
                    Text(displayLanguage)
                        .font(.system(size: AppFontSizes.code))
                        .foregroundColor(Color.gray)
                }

                Spacer()

                CopyButton(
                    textToCopy: code,
                    fontSize: .system(size: AppFontSizes.code),
                    helpText: "Copy code"
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color("Surface").opacity(0.70))
            .cornerRadius(15, corners: [.topLeft, .topRight])
            .cornerRadius(3, corners: [.bottomLeft, .bottomRight])

            // Code content
            CodeText(code)
                .font(.system(size: AppFontSizes.code))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("Surface").opacity(0.70))
                .cornerRadius(3, corners: [.topLeft, .topRight])
                .cornerRadius(15, corners: [.bottomLeft, .bottomRight])
        }
        .onAppear {
            displayLanguage = getDisplayLanguage()

            Task(priority: .userInitiated) {
                await highlightCode()
            }
        }
        .onChange(of: highlightResult) { _, _ in
            displayLanguage = getDisplayLanguage()
        }
    }

    /// Helper method to get clean language display name
    private func getDisplayLanguage() -> String? {
        // First try explicit language from markdown
        if let explicitLanguage = language, !explicitLanguage.isEmpty {
            return explicitLanguage.capitalized
        }

        // Then try detected language name from highlight result
        if let languageName = highlightResult?.languageName, !languageName.isEmpty {
            return languageName.replacingOccurrences(of: "?", with: "").capitalized
        }

        return "Plain Text"
    }

    /// Helper method to detect language
    private func highlightCode() async {
        // Return immediately if we already have a result
        if highlightResult != nil { return }

        do {
            let highlight = Highlight()
            let result = try await highlight.request(code)

            self.highlightResult = result
        } catch {
            print("Error highlighting code: \(error)")
        }
    }
}
