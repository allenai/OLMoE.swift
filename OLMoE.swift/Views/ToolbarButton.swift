//
//  ToolbarButton.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 2/6/25.
//

import SwiftUI

struct ToolbarButton: View {
    let action: () -> Void
    let systemName: String?
    let assetName: String?
    let foregroundColor: Color?
    let width: CGFloat?
    let height: CGFloat?
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    init(action: @escaping () -> Void, systemName: String, foregroundColor: Color? = Color("TextColor"), width: CGFloat? = nil, height: CGFloat? = nil) {
        self.action = action
        self.systemName = systemName
        self.assetName = nil
        self.foregroundColor = foregroundColor
        self.width = width
        self.height = height
    }

    init(action: @escaping () -> Void, assetName: String, foregroundColor: Color? = Color("TextColor"), width: CGFloat? = nil, height: CGFloat? = nil) {
        self.action = action
        self.systemName = nil
        self.assetName = assetName
        self.foregroundColor = foregroundColor
        self.width = width
        self.height = height
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let systemName = systemName {
                    Image(systemName: systemName)
                } else if let asset = assetName {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                }
            }
            #if targetEnvironment(macCatalyst)
                .foregroundColor(isEnabled ? Color("MacIconColor") : Color("MacIconColor").opacity(0.5))
                .fontWeight(.bold)
                .frame(width: width, height: height)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(isHovering ? Color.gray.opacity(0.2) : Color.clear)
                .cornerRadius(6)
            #else
                .foregroundColor(isEnabled ? foregroundColor : Color("TextColor").opacity(0.25))
            #endif
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        #if targetEnvironment(macCatalyst)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
    }
}
