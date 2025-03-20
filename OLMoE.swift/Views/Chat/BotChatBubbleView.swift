//
//  BotChatBubbleView.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 3/4/25.
//

import SwiftUI
import MarkdownUI

struct ChatConstants {
    static let generatingDotMarker = "[•](GeneratingDot)"
}

public struct BotChatBubble: View {
    var text: String
    var maxWidth: CGFloat
    var isGenerating: Bool = false
    var hideCopyButton: Bool = false

    private var copyButtonIsVisible: Bool {
        !hideCopyButton && !isGenerating && text != "..."
    }

    private var textWithGeneratingIndicator: String {
        if isGenerating && !text.isEmpty {
            return text + ChatConstants.generatingDotMarker
        } else {
            return text
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Bot profile picture
            Image("BotProfilePicture")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .padding(5)
                .background(Color("AccentColor"))
                .clipShape(Circle())

            if isGenerating && text.isEmpty {
                TypingIndicator()
            } else {
                VStack(alignment: .leading) {
                    // Markdown content with styling
                    Markdown(textWithGeneratingIndicator)
                        .padding(.top, -2)
                        .background(Color("BackgroundColor"))
                        .frame(alignment: .leading)
                        .font(.body())
                        .markdownTextStyle {
                            FontSize(AppFontSizes.body)
                        }
                        // Style for links
                        .markdownTextStyle(\.link) {
                            ForegroundColor(Color("AccentColor"))
                        }
                        // Style for inline code
                        .markdownTextStyle(\.code) {
                            FontFamilyVariant(.monospaced)
                            FontSize(AppFontSizes.body * 0.85)
                            BackgroundColor(Color("Surface").opacity(0.35))
                        }
                        // Style for lists
                        .markdownNumberedListMarker(
                            BlockStyle { configuration in
                              Text("\(configuration.itemNumber)")
                                .monospacedDigit()
                                .foregroundColor(Color("AccentColor"))
                                .fontWeight(.semibold)
                                .padding(.trailing, 5)
                            }
                        )
                        .markdownBulletedListMarker(
                            BlockStyle { configuration in
                                let systemNames = ["circle.fill", "circle", "square.fill"]
                                let index = (configuration.listLevel - 1) % systemNames.count
                                let systemName = systemNames[index]

                                Image(systemName: systemName)
                                    .foregroundColor(Color("AccentColor"))
                                    .font(.system(size: 6))
                                    .padding(.trailing, 8)
                            }
                        )
                        // Style for code blocks
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            // For code blocks, we use the original content without the generating dot
                            let cleanCode = configuration.content.replacingOccurrences(
                                of: ChatConstants.generatingDotMarker,
                                with: ""
                            )

                            return HighlightedCodeBlock(code: cleanCode, language: configuration.language)
                                .markdownMargin(top: 8, bottom: 8)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = cleanCode
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                    }) {
                                        Label("Copy Code", systemImage: "doc.on.doc")
                                    }
                                }
                        }
                        .textSelection(.enabled) // Enable text selection for manual copying

                    // Copy button for full text
                    if copyButtonIsVisible {
                        CopyButton(
                            textToCopy: text,
                            foregroundColor: Color("AccentColor"),
                            showLabel: true,
                            fontSize: .body(),
                            helpText: "Copy message"
                        )
                        .padding(.top, 1)
                    }
                }
            }
            Spacer()
        }
        .padding([.leading], 12)
    }
}

// MARK: - Previews
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            BotChatBubble(
                text: "",
                maxWidth: UIScreen.main.bounds.width,
                isGenerating: true
            )

            BotChatBubble(
                text: "...",
                maxWidth: UIScreen.main.bounds.width
            )

            BotChatBubble(
                text: "This text is being generated and may span multiple lin",
                maxWidth: UIScreen.main.bounds.width,
                isGenerating: true
            )

            BotChatBubble(
                text: """
                ### Code
                ```python
                print("Hello World")
                ```

                ```swift
                struct Example {
                    let value: String
                    func process() -> String {
                        return "Processed: \\(value)"
                    }
                }
                ```

                ```
                let numbers = [1, 2, 3, 4, 5]
                let order = numbers.sort((a, b) => {
                    return a;
                })
                console.log(order);
                ```

                ```
                Plain text, this is not a valid programming language
                ```

                ### Lists

                1. Install dependencies
                   1. Run `npm install` for frontend packages
                2. Configure environment
                3. Start development server

                - Frontend
                  - Redux state management
                    - Reducers
                      - Data reducer
                        - Backend
                            - API endpoints

                """,
                maxWidth: UIScreen.main.bounds.width
            )

            BotChatBubble(
                text: "Welcome Message!",
                maxWidth: UIScreen.main.bounds.width,
                hideCopyButton: true
            )
        }
        .padding(.vertical, 20)
        .background(Color("BackgroundColor"))
        .preferredColorScheme(.dark)
    }
}
