//
//  DeadZoneControl.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

struct DeadZoneControl {
    static func show(hideCompletion: (() -> Void)? = nil) {
        let values = Array(stride(from: Double(0), through: Double(1), by: Double(0.05)))
        let datas = values.map({ $0.roundedDecimal(scale: 2) }).map({ "\($0.stringValue(minFraction: 2, maxFraction: 2))" })
        let oldValue = Settings.defalut.getExtraDouble(key: ExtraKey.deadZone.rawValue) ?? 0
        let currentIndex = values.firstIndex(where: { $0 == oldValue }) ?? 0
        ASSheetView.show(.init(style: .step(title: R.string.localizable.deadZoneSetting(),
                                            detail: R.string.localizable.deadZoneDesc(),
                                            step: .quickStep(titles: datas,
                                                             currentIndex: currentIndex,
                                                             fixedWidth: true))),
                         action: { action, _ in
            if let index = action.stepValue?.index {
                let newValue = values[index]
                Settings.defalut.updateExtra(key: ExtraKey.deadZone.rawValue, value: newValue)
                ExternalGameControllerManager.shared.deadZone = Float(newValue)
            }
            return .none
        }, dismiss: {
            hideCompletion?()
        })
    }
}
