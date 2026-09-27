//
//  ASSwitch.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ASSwitch {
    enum State {
        case on, off, disabled
    }
    var state: State
    var onColor: UIColor = R.Color.Main
    var offColor: UIColor = R.Color.Switch
}
