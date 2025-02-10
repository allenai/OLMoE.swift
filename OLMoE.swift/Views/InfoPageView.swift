//
//  InfoPageView.swift
//  OLMoE.swift
//
//  Created by Thomas Jones on 11/14/24.
//


import SwiftUI

struct InfoButton: View {
    let action: () -> Void

    var body: some View {
        ToolbarButton(action: action, imageName: "info.circle")
        #if targetEnvironment(macCatalyst)
            .padding(.trailing, 12)
            .padding(.top, 4)
        #endif
    }
}

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .foregroundColor(Color("TextColor"))
        }
        .buttonStyle(.plain)
        .clipShape(Circle())
    }
}

struct InfoContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(InfoText.content) { text in
                HeaderTextPairView(header: text.header, text: text.text)
                    .padding([.horizontal], 12)
            }
        }
        .padding([.bottom], 24)
    }
}

struct InfoView: View {
    @Binding var isPresented: Bool

    var body: some View {
        #if targetEnvironment(macCatalyst)
        VStack(spacing: 0) {
            // Fixed header
            HStack {
                Spacer()
                CloseButton(action: { isPresented = false })
            }
            .padding([.top, .horizontal], 12)

            // Scrollable content
            ScrollView {
                InfoContent()
            }
        }
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    CloseButton(action: { isPresented = false })
                }

                InfoContent()
            }
            .padding([.bottom], 24)
        }
        #endif
    }
}

#Preview("InfoView") {
    InfoView(isPresented: .constant(true))
}
