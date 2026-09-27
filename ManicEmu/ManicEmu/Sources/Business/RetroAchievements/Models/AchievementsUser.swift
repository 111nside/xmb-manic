//
//  AchievementsUser.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/25.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SmartCodable

struct AchievementsUser: SmartCodable {
    var username: String = ""
    var password: String = ""
    var token: String = ""
    
    static func getUser() -> AchievementsUser? {
        if let jsonString = Settings.defalut.getExtraString(key: ExtraKey.achievementsUser.rawValue), !jsonString.isEmpty,
           let user = AchievementsUser.deserialize(from: jsonString),
           user.isValid() {
            return user
        }
        return nil
    }
    
    static func updateUser(username: String, password: String, token: String) {
        if let json = AchievementsUser(username: username, password: password, token: token).toJSONString() {
            Settings.defalut.updateExtra(key: ExtraKey.achievementsUser.rawValue, value: json)
        }
    }
    
    func isValid() -> Bool {
        if !username.isEmpty && !password.isEmpty && !token.isEmpty {
            return true
        }
        return false
    }
    
    
}
