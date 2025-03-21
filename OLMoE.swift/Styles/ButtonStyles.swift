//
//  ButtonStyles.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 11/20/24.
//


import SwiftUI

struct PrimaryButton: ButtonStyle {
    var minWidth: CGFloat?

    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration.label
            .frame(minWidth: minWidth ?? 100)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.lightGreen)
            .cornerRadius(23)
            .font(.body())
            .fontWeight(.semibold)
            .foregroundColor(Color("TextColorButton"))
    }
}

extension ButtonStyle where Self == PrimaryButton {
    static var PrimaryButton: Self {
        .init()
    }
}

struct SecondaryButton: ButtonStyle {
    var minWidth: CGFloat?

    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration.label
            .frame(minWidth: minWidth ?? 100)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(Color.background)
            .cornerRadius(12)
            .font(.body())
            .fontWeight(.semibold)
            .foregroundColor(Color("AccentColor"))
            .preferredColorScheme(.dark)
    }
}

extension ButtonStyle where Self == SecondaryButton {
    static var SecondaryButton: Self {
        .init()
    }
}


#Preview("Primary") {
    Button("Button") { print("Tapped") }
        .buttonStyle(.PrimaryButton)
}

#Preview("Secondary") {
    Button("Button") { print("Tapped") }
        .buttonStyle(.SecondaryButton)
}


