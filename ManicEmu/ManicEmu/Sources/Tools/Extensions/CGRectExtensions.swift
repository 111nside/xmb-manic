//
//  CGRectExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/26.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension CGRect {
    func rounded(_ numberOfDecimalPlaces: Int = 2) -> CGRect {
        return CGRect(x: self.origin.x.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .towardZero),
                      y: self.origin.y.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .towardZero),
                      width: self.size.width.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .towardZero),
                      height: self.size.height.rounded(numberOfDecimalPlaces: numberOfDecimalPlaces, rule: .towardZero))
    }
    
    func adjustSize(add: Double) -> CGRect {
        let newWidth = size.width + add
        let newHeight = size.height + add
        return CGRect(x: self.origin.x,
                      y: self.origin.y,
                      width: newWidth < 0 ? size.width : newWidth,
                      height: newHeight < 0 ? size.height : newHeight)
    }
}
