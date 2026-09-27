//
//  PersistedKit.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/30.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

struct PersistedKit {
    static var incrementID: Int { Int(Date().timeIntervalSince1970ms) }
}
