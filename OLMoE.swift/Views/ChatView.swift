//
//  ChatView.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 11/20/24.
//

import SwiftUI

public struct UserChatBubble: View {
    var text: String

    public var body: some View {
        HStack(alignment: .top) {
            Spacer()

            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .padding(12)
                .background(Color("Surface"))
                .cornerRadius(12)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
                .font(.body())
        }
    }
}

public struct BotChatBubble: View {
    var text: String
    var isGenerating: Bool = false

    public var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image("BotProfilePicture")
                .resizable()
                .frame(width: 20, height: 20)
                .padding(4)
                .background(Color("Surface"))
                .clipShape(Circle())

            if isGenerating && text.isEmpty {
                TypingIndicator()
            } else {
                Text(text)
                    .padding(.top, -2)
                    .background(Color("BackgroundColor"))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                    .font(.body())
            }
            Spacer()
        }
    }
}

public struct TypingIndicator: View {
    @State private var dotCount = 0

    public var body: some View {
        HStack() {
            Text(String(repeating: ".", count: dotCount))
        }
        .onAppear {
            // Animate dots
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self.dotCount = (self.dotCount + 1) % 4 // Cycle through 0-3 dots
            }
        }
    }
}

struct ScrollState {
    static let BottomScrollThreshold = 120.0
    static let ScrollSpaceName: String = "scrollSpace"

    public var scrollViewHeight: CGFloat = 0
    public var contentHeight: CGFloat = 0
    public var scrollOffset: CGFloat = 0
    public var isAtBottom: Bool = true

    mutating func onScroll(scrollOffset: CGFloat) {
        self.scrollOffset = scrollOffset
        updateState()
    }

    mutating func onContentResized(contentHeight: CGFloat) {
        self.contentHeight = contentHeight
        updateState()
    }

    private mutating func updateState() {
        let needsScroll = contentHeight > scrollViewHeight
        let sizeDelta = contentHeight - scrollViewHeight
        let offsetDelta = abs(sizeDelta) + scrollOffset
        let isAtBottom = !needsScroll || offsetDelta < ScrollState.BottomScrollThreshold
        self.isAtBottom = isAtBottom
    }
}

public struct ChatView: View {
    public static let BottomID = "bottomID"

    public var history: [Chat]
    public var output: String
    @Binding var isGenerating: Bool
    @Binding var isScrolledToBottom: Bool
    @State private var scrollState = ScrollState()
    @StateObject private var keyboardResponder = KeyboardResponder()
    @State var id = UUID()
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // History
                    ForEach(history) { chat in
                        if !chat.content.isEmpty {
                            switch chat.role {
                            case .user:
                                UserChatBubble(text: chat.content)
                            case .bot:
                                BotChatBubble(text: chat.content)
                            }
                        }
                    }
                    
                    // Current output
                    if isGenerating {
                        BotChatBubble(text: output, isGenerating: isGenerating)
                    }
                    
                    Color.clear.frame(height: 1).id(ChatView.BottomID)
                }
                .font(.body.monospaced())
                .foregroundColor(Color("TextColor"))
                .background(scrollTracker())
            }
            .background(scrollHeightTracker())
            .coordinateSpace(name: ScrollState.ScrollSpaceName)
            .preferredColorScheme(.dark)
            .onChange(of: keyboardResponder.keyboardHeight) { _,newHeight in
                let keyboardIsVisible = newHeight > 0
                if keyboardIsVisible {
                    id = UUID() // Trigger refresh by changing the id
                }
            }
            .onAppear() {
                // Scroll on refresh
                proxy.scrollTo(ChatView.BottomID, anchor: .bottom)
            }
            .id(id)
        }
    }

    @ViewBuilder
    private func scrollTracker() -> some View {
        GeometryReader { geo in
            Color.clear
                .onChange(of: geo.frame(in: .named(ScrollState.ScrollSpaceName)).origin.y) { _, offset in
                    scrollState.onScroll(scrollOffset: offset)
                    isScrolledToBottom = scrollState.isAtBottom
                }
                .onAppear {
                    scrollState.onContentResized(contentHeight: geo.size.height)
                }
                .onChange(of: geo.size.height) { _, newHeight in
                    scrollState.onContentResized(contentHeight: newHeight)
                    isScrolledToBottom = scrollState.isAtBottom
                }
        }
    }

    @ViewBuilder
    private func scrollHeightTracker() -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    scrollState.scrollViewHeight = proxy.size.height
                }
                .onChange(of: proxy.size.height) { _, newHeight in
                    scrollState.scrollViewHeight = newHeight
                }
        }
    }
}

#Preview("Replying") {
    let exampleOutput = "This is a bot response that spans multiple lines to better test spacing and alignment in the chat view during development previews in Xcode. This is a bot response that spans multiple lines to better test spacing and alignment in the chat view during development previews in Xcode."
    let exampleHistory: [Chat] = [
        Chat(role: .user, content: "Hi there!"),
        Chat(role: .bot, content: "Hello! How can I help you?"),
        Chat(role: .user, content: "Give me a very long answer (this question has a whole lot of text!)"),
    ]

    ChatView(
        history: exampleHistory,
        output: exampleOutput,
        isGenerating: .constant(true),
        isScrolledToBottom: .constant(true)
    )
    .padding(12)
    .background(Color("BackgroundColor"))
}

#Preview("Thinking") {
    let exampleOutput = ""
    let exampleHistory: [Chat] = [
        Chat(role: .user, content: "Hi there!"),
        Chat(role: .bot, content: "Hello! How can I help you?"),
        Chat(role: .user, content: "Give me a very long answer"),
    ]

    ChatView(
        history: exampleHistory,
        output: exampleOutput,
        isGenerating: .constant(true),
        isScrolledToBottom: .constant(true)
    )
    .padding(12)
    .background(Color("BackgroundColor"))
}

#Preview("BotChatBubble") {
    BotChatBubble(text: "Welcome chat message")
}

#Preview("UserChatBubble") {
    UserChatBubble(text: "Hello Ai, please help me with your knowledge.")
}
