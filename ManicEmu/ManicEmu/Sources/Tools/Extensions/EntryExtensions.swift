//
//  EntryExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import ZIPFoundation
import UniversalDetector

extension Entry {
    var decodedPath: String {
        let detector = UniversalDetector()
        detector.analyze(pathData)
        if let string = NSString(data: pathData, encoding: detector.encoding()) {
            return string as String
        }
        return path
    }
}
