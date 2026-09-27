//
//  GlobalCoreSwitch.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import SmartCodable

import RealmSwift

struct GlobalCoreSwitch: SmartCodable, Equatable {
    private var globalCoreConfigs = [String: String]()
    
    func getUsingCoreName(gameType: GameType) -> String? {
        return globalCoreConfigs[gameType.localizedShortName]
    }
    
    func getUsingCoreIndex(gameType: GameType) -> Int? {
        let coreName = getUsingCoreName(gameType: gameType)
        return gameType.supportCores.firstIndex(where: { $0 == coreName })
    }
    
    mutating func setUsingCoreName(gameType: GameType, coreName: String) {
        globalCoreConfigs[gameType.localizedShortName] = coreName
        Self.updateConfig(self)
    }
    
    static func getConfig(realm: Realm? = nil) -> GlobalCoreSwitch {
        var coreConfig: String? = nil
        if let realm, let settings = realm.object(ofType: Settings.self, forPrimaryKey: Settings.defaultName) {
            coreConfig = settings.getExtraString(key: ExtraKey.globalCoreConfigs.rawValue)
        } else {
            coreConfig = Settings.defalut.getExtraString(key: ExtraKey.globalCoreConfigs.rawValue)
        }
        
        if let coreConfig, var config = GlobalCoreSwitch.deserialize(from: coreConfig) {
#if DEBUG
            Log.debug("获取GlobalCoreSwitch配置:\n\(config.toJSONString(prettyPrint: true) ?? "")")
#endif
            //The default core for the 3DS has been changed to Azahar.
            if config.getUsingCoreName(gameType: GameType._3ds) == nil {
                config.globalCoreConfigs[GameType._3ds.localizedShortName] = EmulationCore.Azahar.name
            }
            return config
        }
        Log.debug("获取默认GlobalCoreSwitch配置")
        
        var configs = [String: String]()
        let gameTypes = System.allGameTypes.filter({ $0.supportCores.count > 0 })
        for gameType in gameTypes {
            if gameType == ._3ds {
                //The default core for the 3DS has been changed to Azahar.
                configs[gameType.localizedShortName] = EmulationCore.Azahar.name
            } else {
                configs[gameType.localizedShortName] = gameType.supportCores.first(where: { !$0.isEmpty })
            }
        }
        return GlobalCoreSwitch(globalCoreConfigs: configs)
    }
    
    static func updateConfig(_ config: GlobalCoreSwitch) {
        if let jsonString = config.toJSONString() {
#if DEBUG
            Log.debug("保存GlobalCoreSwitch配置:\n\(config.toJSONString(prettyPrint: true) ?? "")")
#endif
            Settings.defalut.updateExtra(key: ExtraKey.globalCoreConfigs.rawValue, value: jsonString)
        }
    }
}
