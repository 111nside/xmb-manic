//
//  ControllerMapping.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/4/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift

import IceCream

extension ControllerMapping: CKRecordConvertible & CKRecordRecoverable {}

class ControllerMapping: Object, ObjectUpdatable {
    ///主键 由创建时间戳ms来生成
    @Persisted(primaryKey: true) var id: Int = PersistedKit.incrementID
    ///控制器名称 相同型号的控制器会使用这份映射 无法避免
    @Persisted var controllerName: String
    ///游戏平台类型
    @Persisted var gameType: GameType
    ///映射的储存信息
    @Persisted var mapping: String
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    ///额外数据备用
    @Persisted var extras: Data?
        
    var inputMapping: GameControllerInputMappingProtocol? {
        try? GameControllerInputMapping(mapping: mapping)
    }
    
    func getExtra(key: String) -> Any? {
        if let extras {
            return Self.getExtra(extras: extras, key: key)
        }
        return nil
    }
    
    func updateExtra(key: String, value: Any?) {
        if let extras, let data = Self.updateExtra(extras: extras, key: key, value: value) {
            Self.change { realm in
                self.extras = data
            }
        } else if let data = [key: value].jsonData() {
            Self.change { realm in
                self.extras = data
            }
        }
    }
}

extension GameControllerInputMapping {
    init(mapping: String) throws {
        let data = mapping.data(using: .utf8)!
        
        let decoder = PropertyListDecoder()
        self = try decoder.decode(GameControllerInputMapping.self, from: data)
    }
    
    func genMapping() -> String {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        if let data = try? encoder.encode(self), let mapping = String(data: data, encoding: .utf8) {
            return mapping
        }
        return ""
    }
}
