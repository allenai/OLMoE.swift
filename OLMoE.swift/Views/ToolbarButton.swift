//
//  ToolbarButton.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 2/6/25.
//

import SwiftUI

struct ToolbarButton: View {
    let action: () -> Void
    let imageName: String
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: imageName)
                #if targetEnvironment(macCatalyst)
                    .foregroundColor(Color("MacIconColor"))
                    .fontWeight(.bold)
                    .frame(width: 20, height: 20)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(isHovering ? Color.gray.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                #else
                    .foregroundColor(Color("TextColor"))
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
