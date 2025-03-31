//
//  UserChatBubbleView.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 3/31/25.
//

import SwiftUI

public struct UserChatBubble: View {
    var text: String
    var maxWidth: CGFloat

    public var body: some View {
        HStack(alignment: .top) {
            Spacer()
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color("Surface"))
                .cornerRadius(24)
                .frame(maxWidth: maxWidth * 0.75, alignment: .trailing)
                .font(.body(.medium))
                .textSelection(.enabled)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    UserChatBubble(text: "Hello, this is a sample message!", maxWidth: 400)
        .padding()
        .background(Color("BackgroundColor"))
}
