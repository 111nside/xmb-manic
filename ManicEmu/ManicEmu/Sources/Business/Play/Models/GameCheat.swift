//
//  GameCheat.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import RealmSwift
import IceCream

extension GameCheat: CKRecordConvertible & CKRecordRecoverable {}

enum GameCheatSortType: Int, CaseIterable {
    case dateAscending, dateDescending, nameAscending, nameDescending, status
    var title: String {
        switch self {
        case .dateAscending:
            R.string.localizable.gameSortAddTime() + R.string.localizable.ascending()
        case .dateDescending:
            R.string.localizable.gameSortAddTime() + R.string.localizable.descending()
        case .nameAscending:
            R.string.localizable.gameSortTitleType() + R.string.localizable.ascending()
        case .nameDescending:
            R.string.localizable.gameSortTitleType() + R.string.localizable.descending()
        case .status:
            R.string.localizable.cheatCodeStatus()
        }
    }
}

class GameCheat: Object, ObjectUpdatable {
    ///主键 由创建时间戳ms来生成
    @Persisted(primaryKey: true) var id: Int = PersistedKit.incrementID
    ///名称
    @Persisted var name: String
    ///代码
    @Persisted var code: String
    ///类型
    @Persisted var type: String
    ///是否启用
    @Persisted var activate: Bool = false
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    ///额外数据备用
    @Persisted var extras: Data?
    
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
