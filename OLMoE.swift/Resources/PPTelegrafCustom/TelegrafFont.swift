//
//  TelegrafFont.swift
//  OLMoE.swift
//
//  Created by Stanley Jovel on 11/18/24.
//

import SwiftUI

extension Font {
    static func telegraf(_ weight: Weight = .regular, textStyle: TextStyle = .body) -> Font {
        custom(AppFonts.telegraf, size: UIFont.preferredFont(forTextStyle: textStyle.uiTextStyle).pointSize)
            .weight(weight)
    }

    static func telegraf(_ weight: Weight = .regular, size: CGFloat) -> Font {
        custom(AppFonts.telegraf, size: size)
            .weight(weight)
    }
}
