//
//  CreamAssetExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import IceCream
import RealmSwift

extension CreamAsset: ObjectUpdatable {
    func deleteAndClean(realm: Realm) {
        if !Settings.defalut.iCloudSyncEnable {
            //如果没有开启同步功能 需要自己手动删除本地的资源
            try? FileManager.safeRemoveItem(at: self.filePath)
        }
        realm.delete(self)
    }
    
    static func batchDeleteAndClean(assets: [CreamAsset], realm: Realm) {
        if !Settings.defalut.iCloudSyncEnable {
            //如果没有开启同步功能 需要自己手动删除本地的资源
            assets.forEach { asset in
                try? FileManager.safeRemoveItem(at: asset.filePath)
            }
        }
        realm.delete(assets)
    }
    
    func getExtra(key: String) -> Any? {
        return nil
    }
    
    func updateExtra(key: String, value: Any?) {}
}
