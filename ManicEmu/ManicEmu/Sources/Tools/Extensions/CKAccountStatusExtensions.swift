//
//  CKAccountStatusExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import CloudKit

extension CKAccountStatus {
    var description: String {
        switch self {
        case .couldNotDetermine:
            "couldNotDetermine"
        case .available:
            "available"
        case .restricted:
            "restricted"
        case .noAccount:
            "noAccount"
        case .temporarilyUnavailable:
            "temporarilyUnavailable"
        default:
            "unknown"
        }
    }
}
