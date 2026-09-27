//
//  ArrayExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension Array where Element == UIColor {
    func gradientLocations(factor: CGFloat = 0.5) -> [CGFloat] {
        let colorCount = self.count
        guard colorCount > 1 else { return [0.0] }
        let lastIndex = CGFloat(colorCount - 1)
        return (0..<colorCount).map { i in
            let x = CGFloat(i) / lastIndex
            return pow(x, factor)   // factor < 1 时，前大后小
        }
    }
}
