//
//  ASProgress.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASProgress {
    var value: Float = 0
    var minColor = R.Color.Main
    var maxColor = R.Color.BackgroundTertiary
    var interaction: Interaction = .disabled(.small)
    var showValue: Bool = false
    var valueDisplayFormatter: ((Float) -> String)? = nil
    
    enum Interaction {
        enum Size {
            case small
            case large
        }
        
        case enabled
        case disabled(Size)
    }
}
