//
//  ObjectUpdatable.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift

protocol ObjectUpdatable {
    static func change(action: ((_ realm: Realm) throws ->Void))
    static func getExtra(extras: Any, key: String) -> Any?
    static func updateExtra(extras: Any, key: String, value: Any?) -> Data?
    func getExtra(key: String) -> Any?
    func getExtraString(key: String) -> String?
    func getExtraInt(key: String) -> Int?
    func updateExtra(key: String, value: Any?)
}

extension ObjectUpdatable {
    static func change(action: ((_ realm: Realm) throws ->Void)) {
        do {
            let realm = Database.realm
            try realm.write {
                try action(realm)
            }
        } catch {
            Log.error("更新\(type(of: self))失败")
        }
    }
    
    static func getExtra(extras: Any, key: String) -> Any? {
        var extraData: Data? = nil
        if extras is Data {
            extraData = extras as? Data
        } else if extras is String {
            extraData = (extras as! String).data(using: .utf8)
        }
        
        if let extraData, let extraInfos = try? extraData.jsonObject() as? [String: Any] {
            return extraInfos[key]
        }
        return nil
    }
    
    static func updateExtra(extras: Any, key: String, value: Any?) -> Data? {
        var extraData: Data? = nil
        if extras is Data {
            extraData = extras as? Data
        } else if extras is String {
            extraData = (extras as! String).data(using: .utf8)
        }
        
        if let extraData, var extraInfos = try? extraData.jsonObject() as? [String: Any] {
            extraInfos[key] = value
            return extraInfos.jsonData()
        }
        return nil
    }
    
    func getExtraString(key: String) -> String? {
        if let string = self.getExtra(key: key) as? String {
            return string
        }
        return nil
    }
    
    func getExtraInt(key: String) -> Int? {
        if let integer = self.getExtra(key: key) as? Int {
            return integer
        }
        return nil
    }
    
    func getExtraBool(key: String) -> Bool? {
        if let bool = self.getExtra(key: key) as? Bool {
            return bool
        }
        return nil
    }
    
    func getExtraDouble(key: String) -> Double? {
        if let double = self.getExtra(key: key) as? Double {
            return double
        }
        return nil
    }
}
