//
//  Typography.swift
//  OLMoE.swift
//
//  Created by Jon Ryser on 2024-11-20.
//


import SwiftUI

// Font constants
public enum AppFonts {
    public static let telegraf = "PP Telegraf Custom"
    public static let manrope = "Manrope"
}

// Font size constants with platform-specific values
public enum AppFontSizes {
    #if targetEnvironment(macCatalyst)
    public static let title: CGFloat = 21
    public static let body: CGFloat = 14
    public static let subheader: CGFloat = 14
    public static let code: CGFloat = 13
    #else
    public static let title: CGFloat = 24
    public static let body: CGFloat = 17
    public static let subheader: CGFloat = 17
    public static let code: CGFloat = 14
    #endif
}

extension Font {
    static func title(_ weight: Font.Weight = .regular) -> Font {
        #if targetEnvironment(macCatalyst)
        return scaledCustomFont(name: AppFonts.telegraf, size: AppFontSizes.title,
                               textStyle: .title3, weight: weight)
        #else
        return .telegraf(weight, size: AppFontSizes.title)
        #endif
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        #if targetEnvironment(macCatalyst)
        return scaledCustomFont(name: AppFonts.manrope, size: AppFontSizes.body,
                               textStyle: .body, weight: weight)
        #else
        return .manrope(weight, size: AppFontSizes.body)
        #endif
    }

    static func subheader() -> Font {
        #if targetEnvironment(macCatalyst)
        return scaledCustomFont(name: AppFonts.manrope, size: AppFontSizes.subheader,
                               textStyle: .body, weight: .bold)
        #else
        return .manrope(.bold, size: AppFontSizes.subheader)
        #endif
    }

    #if targetEnvironment(macCatalyst)
    /// This is a helper function to dynamically scale custom fonts for Mac Catalyst using as base the system's size.
    private static func scaledCustomFont(name: String, size: CGFloat, textStyle: UIFont.TextStyle, weight: Font.Weight) -> Font {
        let baseFont = UIFont(name: name, size: size)!
        let weightedFont = applyWeight(to: baseFont, weight: weight)
        let scaledFont = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: weightedFont)
        return Font(scaledFont)
    }

    private static func applyWeight(to font: UIFont, weight: Font.Weight) -> UIFont {
        // Map SwiftUI Font.Weight to UIKit UIFont.Weight
        let uiWeight: UIFont.Weight

        switch weight {
        case .ultraLight: uiWeight = .ultraLight
        case .thin: uiWeight = .thin
        case .light: uiWeight = .light
        case .regular: uiWeight = .regular
        case .medium: uiWeight = .medium
        case .semibold: uiWeight = .semibold
        case .bold: uiWeight = .bold
        case .heavy: uiWeight = .heavy
        case .black: uiWeight = .black
        default: uiWeight = .regular
        }

        let descriptor = font.fontDescriptor.addingAttributes(
            [.traits: [UIFontDescriptor.TraitKey.weight: uiWeight]]
        )
        return UIFont(descriptor: descriptor, size: 0) // Size 0 means keep the original size
    }
    #endif
}
