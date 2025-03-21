//
//  ManropeFont.swift
//  OLMoE.swift
//
//  Created by Luca Soldaini on 2024-09-18.
//

import SwiftUI

extension Font {
    enum ManropeWeight: String {
        case extraLight = "ExtraLight"
        case light = "Light"
        case regular = "Regular"
        case medium = "Medium"
        case semiBold = "SemiBold"
        case bold = "Bold"
        case extraBold = "ExtraBold"

        var weight: Weight {
            switch self {
            case .extraLight: return .light
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semiBold: return .semibold
            case .bold: return .bold
            case .extraBold: return .heavy
            }
        }
    }

    static func manrope(_ weight: ManropeWeight = .regular, textStyle: TextStyle = .body) -> Font {
        custom(AppFonts.manrope, size: UIFont.preferredFont(forTextStyle: textStyle.uiTextStyle).pointSize)
            .weight(weight.weight)
    }
    static func manrope(_ weight: Weight = .regular, size: CGFloat) -> Font {
        custom(AppFonts.manrope, size: size)
            .weight(weight)
    }
}

extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}
