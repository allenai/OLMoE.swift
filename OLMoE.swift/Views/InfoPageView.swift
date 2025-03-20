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
        #if targetEnvironment(macCatalyst)
        ToolbarButton(action: action, systemName: "info.circle", foregroundColor: Color("AccentColor"))
        #else
        ToolbarButton(action: action, assetName: "InfoIcon", foregroundColor: Color("AccentColor"))
        #endif
    }
}

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("CloseButtonIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 12))
        }
        .buttonStyle(.plain)
    }
}

struct InfoContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(InfoText.content) { text in
                HeaderTextPairView(header: text.header, text: text.text)
                    .padding([.horizontal], 24)
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
            // Fixed header with logo and close button
            HStack {
                Ai2LogoView(height: 30, leadingPadding: 12)

                Spacer()

                CloseButton(action: { isPresented = false })
            }
            .padding(EdgeInsets(top: 24, leading: 12, bottom: 12, trailing: 12))

            // Scrollable content
            ScrollView {
                InfoContent()
            }
        }
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with logo and close button
                HStack {
                    Ai2LogoView(height: 30, leadingPadding: 12)

                    Spacer()

                    CloseButton(action: { isPresented = false })
                }
                .padding(EdgeInsets(top: 24, leading: 12, bottom: 8, trailing: 12))

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
