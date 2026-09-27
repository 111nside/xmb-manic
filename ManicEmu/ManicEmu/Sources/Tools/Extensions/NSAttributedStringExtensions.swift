//
//  NSAttributedStringExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/17.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension NSAttributedString {
    func highlightString(_ string: String?, font: UIFont? = nil, color: UIColor = R.Color.Main, caseSensitive: Bool = false) -> NSAttributedString {
        if let string = string, self.string.contains(string, caseSensitive: caseSensitive) {
            let matt = NSMutableAttributedString(attributedString: self)
            var nsRanges: [NSRange] = []
            var startIndex = matt.string.startIndex
            while let range = matt.string.range(of: string, options: caseSensitive ? [] : .caseInsensitive, range: startIndex..<matt.string.endIndex) {
                let nsRange = NSRange(range, in: matt.string)
                nsRanges.append(nsRange)
                startIndex = range.upperBound // 从找到的上一个位置继续查找
            }
            nsRanges.forEach { range in
                var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]
                if let font = font {
                    attributes[.font] = font
                }
                matt.addAttributes(attributes, range: range)
            }
            return matt
        }
        return self
    }
}
