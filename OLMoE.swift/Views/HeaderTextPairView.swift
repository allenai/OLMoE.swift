//
//  HeaderTextPair.swift
//  OLMoE.swift
//
//  Created by Thomas Jones on 11/26/24.
//


import SwiftUI
import MarkdownUI

struct HeaderTextPair: Identifiable {
    let id = UUID()
    let header: String
    let text: String
}

struct HeaderTextPairView : View {
    let header: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !header.isEmpty {
                Text(header)
                    .font(.subheader())
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
            }

            Markdown(text)
                .font(.body())
                .multilineTextAlignment(.leading)
                .markdownTextStyle {
                    FontSize(AppFontSizes.body)
                }
                .markdownTextStyle(\.link) {
                    ForegroundColor(Color("AccentColor"))
                    UnderlineStyle(.single)
                }
        }
    }
}
