//
//  Prefference.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/1.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import RealmSwift
import IceCream
import SmartCodable

extension Prefference: CKRecordConvertible & CKRecordRecoverable {
    var isDeleted: Bool { return false }
}

class Prefference: Object {
    enum StoreLevel: Int, CaseIterable {
        case game = 0, gameType, global
    }
    
    enum StoreKey {
        case game(gameId: String, extra: String? = nil)
        case gameType(gameType: GameType, extra: String? = nil)
        case global(extra: String? = nil)
        
        var storeLevel: StoreLevel {
            switch self {
            case .game:
                return .game
            case .gameType:
                return .gameType
            case .global:
                return .global
            }
        }
        
        func nextLevel(with kind: Kind) -> StoreKey? {
            switch self {
            case .game(let gameId, let extra):
                if kind.supportStoreLevels.contains([.gameType]) {
                    let realm = Database.realm
                    if let game = realm.object(ofType: Game.self, forPrimaryKey: gameId) {
                        return .gameType(gameType: game.gameType, extra: extra)
                    }
                }
                
                if kind.supportStoreLevels.contains([.global]) {
                    return .global(extra: extra)
                }
            case .gameType(_, let extra):
                if kind.supportStoreLevels.contains([.global]) {
                    return .global(extra: extra)
                }
            default:
                break
            }
            return nil
        }
        
        var key: String? {
            switch self {
            case .game(let gameId, let extra):
                return gameId + (extra ?? "")
            case .gameType(let gameType, let extra):
                return gameType.localizedShortName + (extra ?? "")
            case .global(let extra):
                return extra
            }
        }
        
        static func orientationExtraKey(isLandScape: Bool = false) -> String {
            isLandScape ? "landscape" : "portrait"
        }
        
        static func orientationKey(gameId: String, isLandScape: Bool = false) -> Self {
            return .game(gameId: gameId,
                         extra: orientationExtraKey(isLandScape: isLandScape))
        }
        
        static func orientationKey(gameType: GameType, isLandScape: Bool = false) -> Self {
            return .gameType(gameType: gameType,
                             extra: orientationExtraKey(isLandScape: isLandScape))
        }
        
        static func orientationKey(isLandScape: Bool = false) -> Self {
            return .global(extra: orientationExtraKey(isLandScape: isLandScape))
        }
        
        static func shaderExtraKey(isGlsl: Bool = false) -> String {
            isGlsl ? "Glsl" : "Slang"
        }
        
        static func shaderKey(gameId: String, isGlsl: Bool = false) -> Self {
            return .game(gameId: gameId, extra: shaderExtraKey(isGlsl: isGlsl))
        }
        
        static func shaderKey(gameType: GameType, isGlsl: Bool = false) -> Self {
            return .gameType(gameType: gameType, extra: shaderExtraKey(isGlsl: isGlsl))
        }
        
        static func shaderKey(isGlsl: Bool = false) -> Self {
            return .global(extra: shaderExtraKey(isGlsl: isGlsl))
        }
        
        ///核心配置使用defaultCore作为extra 避免同平台切换核心后配置混用        
        static func coreOptionsKey(gameId: String, defaultCore: Int) -> Self {
            return .game(gameId: gameId, extra: "\(defaultCore)")
        }
        
        static func coreOptionsKey(gameType: GameType, defaultCore: Int) -> Self {
            return .gameType(gameType: gameType, extra: "\(defaultCore)")
        }
    }
    
    enum Kind: String {
        case gameOptionsSort
        case shader
        case triggerPro
        case controllerMapping
        case skin
        case skinMod
        case flexBackground
        case gameShortcut
        case coreOptions
        
        var supportStoreLevels: [StoreLevel] {
            switch self {
            case .gameOptionsSort:
                [.global]
            case .shader:
                StoreLevel.allCases
            case .triggerPro:
                [.game, .gameType]
            case .controllerMapping:
                [.game, .gameType]
            case .skin:
                [.game, .gameType]
            case .skinMod:
                [.game, .gameType]
            case .flexBackground:
                StoreLevel.allCases
            case .gameShortcut:
                StoreLevel.allCases
            case .coreOptions:
                [.game, .gameType]
            }
        }
    }
    
    enum Result {
        case skinId(skinId: String, level: StoreLevel)
        case flexBackground(background: FlexBackgroundImage)
        case shader(relativePath: String)
        case gameOptionsSort([[GameOption]]?)
        case gameShortcut([GameOption])
        case triggerPro(id: Int)
        case coreOptions([String: String]?)
        
        var skinValue: (skinId: String, level: StoreLevel)? {
            if case let .skinId(skinId, level) = self {
                return (skinId, level)
            }
            return nil
        }
        
        var flexBackgroundValue: FlexBackgroundImage? {
            if case let .flexBackground(background) = self {
                return background
            }
            return nil
        }
        
        var shaderValue: String? {
            if case let .shader(relativePath) = self {
                return relativePath
            }
            return nil
        }
        
        var gameOptionsSortValue: [[GameOption]]? {
            if case let .gameOptionsSort(result) = self {
                return result
            }
            return nil
        }
        
        var gameShortcutValue: [GameOption]? {
            if case let .gameShortcut(result) = self {
                return result
            }
            return nil
        }
        
        var triggerProValue: Int? {
            if case let .triggerPro(result) = self {
                return result
            }
            return nil
        }
        
        var coreOptionsValue: [String: String]? {
            if case let .coreOptions(result) = self {
                return result
            }
            return nil
        }
    }
    
    static let defaultName = "PrefferenceDefault"
    
    static let defalut: Prefference  = {
        return Database.realm.object(ofType: Prefference.self, forPrimaryKey: Prefference.defaultName)!
    }()
    
    
    @Persisted(primaryKey: true) var name: String = Prefference.defaultName
    @Persisted var gamePrefference: Data?
    @Persisted var gameTypePrefference: Data?
    @Persisted var globalPrefference: Data?
    @Persisted var extras: Data?
    
    private func getStoreDataAndKey(kind: Kind, storeKey: StoreKey, genAnyway: Bool = false) -> (data: Data, key: String?)? {
        guard kind.supportStoreLevels.contains([storeKey.storeLevel]) else {
            return nil
        }
        
        var storeData: Data? = nil
        let key: String? = storeKey.key
        switch storeKey {
        case .game:
            storeData = Prefference.defalut.gamePrefference
        case .gameType:
            storeData = Prefference.defalut.gameTypePrefference
        case .global:
            storeData = Prefference.defalut.globalPrefference
        }
        if let storeData {
            return (storeData, key)
        } else if genAnyway, let genData = [:].jsonData() {
            return (genData, key)
        } else {
            return nil
        }
    }
    
    func getPrefference(kind: Kind, storeKey: StoreKey, bestEfforts: Bool = false) -> Result? {
        logPrefferences(title: "getPrefference, kind:\(kind), storeKey:\(storeKey), bestEfforts:\(bestEfforts)")
        guard let dataAndKey = getStoreDataAndKey(kind: kind, storeKey: storeKey) else {
            if bestEfforts, let nextStoreKey = storeKey.nextLevel(with: kind) {
                return getPrefference(kind: kind, storeKey: nextStoreKey, bestEfforts: bestEfforts)
            }
            return nil
        }
        var storeValue: String? = nil
        let realStoreLevel: StoreLevel = storeKey.storeLevel
        if let jsonObject = try? JSONSerialization.jsonObject(with: dataAndKey.data) as? [String: Any] {
            if storeKey.storeLevel == .global {
                storeValue = jsonObject[kind.rawValue + (dataAndKey.key ?? "")] as? String
            } else if let key = dataAndKey.key,
                      let prefference = jsonObject[kind.rawValue] as? [String: String] {
                storeValue = prefference[key]
            }
        }
        
        if storeValue == nil, bestEfforts, let nextStoreKey = storeKey.nextLevel(with: kind) {
            //Try looking for storage at other levels
            return getPrefference(kind: kind, storeKey: nextStoreKey, bestEfforts: bestEfforts)
        }
        
        guard let storeValue else { return nil }
        
        switch kind {
        case .gameOptionsSort:
            if let jsonData = storeValue.data(using: .utf8),
                let sorts = try? JSONSerialization.jsonObject(with: jsonData) as? [[Int]] {
                let gameOptions = sorts.compactMap({ $0.compactMap({ GameOption(rawValue: $0) }) })
                return .gameOptionsSort(gameOptions)
            }
            return .gameOptionsSort(nil)
            
        case .shader:
            return .shader(relativePath: storeValue)
        case .triggerPro:
            return .triggerPro(id: Int(storeValue) ?? -1)
        case .controllerMapping:
            return nil
        case .skin:
            return .skinId(skinId: storeValue, level: realStoreLevel)
        case .skinMod:
            return nil
        case .flexBackground:
            return .flexBackground(background: .init(name: storeValue,
                                                     storeLevel: realStoreLevel))
        case .gameShortcut:
            return .gameShortcut(storeValue.components(separatedBy: ",").compactMap({
                Int($0.trimmed)
            }).compactMap({
                GameOption(rawValue: $0)
            }))
        case .coreOptions:
            if let jsonData = storeValue.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
                return .coreOptions(json)
            }
            return .coreOptions(nil)
            
        }
    }
    
    func storePrefference(kind: Kind, storeKey: StoreKey, storeValue: String) {
        guard let dataAndKey = getStoreDataAndKey(kind: kind, storeKey: storeKey, genAnyway: true) else { return }
        
        var jsonObject = (try? JSONSerialization.jsonObject(with: dataAndKey.data) as? [String: Any]) ?? [String: Any]()
        if case .global = storeKey {
            jsonObject[kind.rawValue + (dataAndKey.key ?? "")] = storeValue
        } else {
            guard let key = dataAndKey.key, !key.isEmpty else { return }
            if var prefference = jsonObject[kind.rawValue] as? [String: String] {
                prefference[key] = storeValue
                jsonObject[kind.rawValue] = prefference
            } else {
                jsonObject[kind.rawValue] = [key: storeValue]
            }
        }
        Prefference.change { realm in
            switch storeKey {
            case .game:
                Prefference.defalut.gamePrefference = jsonObject.jsonData()
            case .gameType:
                Prefference.defalut.gameTypePrefference = jsonObject.jsonData()
            case .global:
                Prefference.defalut.globalPrefference = jsonObject.jsonData()
            }
        }
        
        //remove low level store
        switch storeKey {
        case .game:
            break
        case .gameType(let gameType, let extra):
            //remove gamePrefference
            let realm = Database.realm
            let games = realm.objects(Game.self).where({ $0.gameType == gameType })
            let storeKeys = games.map({ StoreKey.game(gameId: $0.id, extra: extra) })
            storeKeys.forEach({
                deletePrefference(kind: kind, storeKey: $0)
            })
            
        case .global(let extra):
            //remove gamePrefference & gameTypePrefference
            deletePrefference(kind: kind, level: .gameType, extra: extra)
            deletePrefference(kind: kind, level: .game, extra: extra)
        }
        
        logPrefferences(title: "storePrefference, kind:\(kind), storeKey:\(storeKey), storeValue:\(storeValue)")
    }
    
    func deletePrefference(kind: Kind, level: StoreLevel, extra: String? = nil) {
        if kind.supportStoreLevels.contains([level]) {
            var data: Data? = nil
            switch level {
            case .game:
                data = Prefference.defalut.gamePrefference
            case .gameType:
                data = Prefference.defalut.gameTypePrefference
            case .global:
                data = Prefference.defalut.globalPrefference
            }
            if let data {
                if var jsonObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    if level == .global {
                        guard jsonObject[kind.rawValue+(extra ?? "")] != nil else { return }
                        jsonObject[kind.rawValue+(extra ?? "")] = nil
                    } else {
                        guard jsonObject[kind.rawValue] != nil else { return }
                        if let extra,
                           var prefference = jsonObject[kind.rawValue] as? [String: String] {
                            prefference.removeAll(keys: prefference.keys.filter({ $0.hasSuffix(extra) }))
                            jsonObject[kind.rawValue] = prefference
                        } else {
                            jsonObject[kind.rawValue] = nil
                        }
                    }
                    Prefference.change { realm in
                        switch level {
                        case .game:
                            Prefference.defalut.gamePrefference = jsonObject.jsonData()
                        case .gameType:
                            Prefference.defalut.gameTypePrefference = jsonObject.jsonData()
                        case .global:
                            Prefference.defalut.globalPrefference = jsonObject.jsonData()
                        }
                    }
                }
            }
            logPrefferences(title: "deletePrefference, kind:\(kind), level:\(level)")
        }
    }
    
    func deletePrefference(kind: Kind, storeKey: StoreKey) {
        guard let dataAndKey = getStoreDataAndKey(kind: kind, storeKey: storeKey) else { return }
        if var jsonObject = try? JSONSerialization.jsonObject(with: dataAndKey.data) as? [String: Any] {
            if storeKey.storeLevel == .global {
                let extra = storeKey.key
                guard jsonObject[kind.rawValue + (extra ?? "")] != nil else { return }
                jsonObject[kind.rawValue + (extra ?? "")] = nil
                Prefference.change { realm in
                    Prefference.defalut.globalPrefference = jsonObject.jsonData()
                }
            } else if let key = dataAndKey.key,
                      var prefference = jsonObject[kind.rawValue] as? [String: String] {
                guard prefference[key] != nil else { return }
                prefference[key] = nil
                jsonObject[kind.rawValue] = prefference
                
                if storeKey.storeLevel == .game {
                    Prefference.change { realm in
                        Prefference.defalut.gamePrefference = jsonObject.jsonData()
                    }
                } else if storeKey.storeLevel == .gameType {
                    Prefference.change { realm in
                        Prefference.defalut.gameTypePrefference = jsonObject.jsonData()
                    }
                }
            }
            logPrefferences(title: "deletePrefference, kind:\(kind), storeKey:\(storeKey)")
        }
    }
    
    func valueExists(kind: Kind, value: String) -> Bool {
        logPrefferences(title: "valueExists, kind:\(kind), value:\(value)")
        if let gamePrefference = getGamePrefference(kind: kind),
           gamePrefference.contains(where: { $0.value == value }) {
            return true
        } else if let gameTypePrefference = getGameTypePrefference(kind: kind),
                  gameTypePrefference.contains(where: { $0.value == value }) {
            return true
        } else if let globalPrefference = getGlobalPrefference(kind: kind),
                  globalPrefference.contains(where: { $0.value == value }) {
            return true
        }
        return false
    }
    
    func deletePrefference(kind: Kind, value: String) {
        func deletePrefference(_ prefference: [String: String], level: StoreLevel) {
            var needToUpdate = false
            var prefference = prefference
            for (k, v) in prefference {
                if v == value {
                    needToUpdate = true
                    prefference.removeValue(forKey: k)
                }
            }
            if needToUpdate {
                updatePrefference(kind: kind, level: level, prefference: prefference)
            }
        }
        
        if let gamePrefference = getGamePrefference(kind: kind) {
            deletePrefference(gamePrefference, level: .game)
        }
        
        if let gameTypePrefference = getGameTypePrefference(kind: kind) {
            deletePrefference(gameTypePrefference, level: .gameType)
        }
        
        if let globalPrefference = getGlobalPrefference(kind: kind) {
            deletePrefference(globalPrefference, level: .global)
        }
        logPrefferences(title: "deletePrefference, kind:\(kind), value:\(value)")
    }
    
    func replaceValue(kind: Kind, value: String, replace: String) {
        func replacePrefference(_ prefference: [String: String], level: StoreLevel) {
            var needToUpdate = false
            var prefference = prefference
            for (k, v) in prefference {
                if v == value {
                    needToUpdate = true
                    prefference[k] = replace
                }
            }
            if needToUpdate {
                updatePrefference(kind: kind, level: level, prefference: prefference)
            }
        }
        
        if let gamePrefference = getGamePrefference(kind: kind) {
            replacePrefference(gamePrefference, level: .game)
        }
        
        if let gameTypePrefference = getGameTypePrefference(kind: kind) {
            replacePrefference(gameTypePrefference, level: .gameType)
        }
        
        if let globalPrefference = getGlobalPrefference(kind: kind) {
            replacePrefference(globalPrefference, level: .global)
        }
        logPrefferences(title: "replaceValue, kind:\(kind), value:\(value), replace:\(replace)")
    }
    
    ///If level=global, then kind will be invalid, and the preference will directly override the global configuration.
    private func updatePrefference(kind: Kind, level: StoreLevel, prefference: [String: String]) {
        switch level {
        case .game:
            if let data = Prefference.defalut.gamePrefference,
               var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                jsonObject[kind.rawValue] = prefference
                Prefference.change { realm in
                    Prefference.defalut.gamePrefference = jsonObject.jsonData()
                }
            } else {
                Prefference.change { realm in
                    Prefference.defalut.gamePrefference = [kind.rawValue: prefference].jsonData()
                }
            }
            
        case .gameType:
            if let data = Prefference.defalut.gameTypePrefference,
               var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                jsonObject[kind.rawValue] = prefference
                Prefference.change { realm in
                    Prefference.defalut.gameTypePrefference = jsonObject.jsonData()
                }
            } else {
                Prefference.change { realm in
                    Prefference.defalut.gameTypePrefference = [kind.rawValue: prefference].jsonData()
                }
            }
            
        case .global:
            Prefference.change { realm in
                Prefference.defalut.globalPrefference = prefference.jsonData()
            }
        }
    }
    
    func getGamePrefference(kind: Kind) -> [String: String]? {
        if let data = Prefference.defalut.gamePrefference,
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let prefference = jsonObject[kind.rawValue] as? [String: String] {
            return prefference
        }
        return nil
    }
    
    func getGameTypePrefference(kind: Kind) -> [String: String]? {
        if let data = Prefference.defalut.gameTypePrefference,
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let prefference = jsonObject[kind.rawValue] as? [String: String] {
            return prefference
        }
        return nil
    }
    
    func getGlobalPrefference(kind: Kind) -> [String: String]? {
        if let data = Prefference.defalut.globalPrefference,
           let prefference = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return prefference
        }
        return nil
    }
    
    private func logPrefferences(title: String = "") {
#if DEBUG
        var debugString = "[\(title.isEmpty ? "Prefference" : title)] Results:\n"
        if let data = Prefference.defalut.gamePrefference,
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            debugString += ("gamePrefference:\n" + (jsonObject.jsonString(prettify: true) ?? "nil") + "\n")
        }
        if let data = Prefference.defalut.gameTypePrefference,
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            debugString += ("gameTypePrefference:\n" + (jsonObject.jsonString(prettify: true) ?? "nil") + "\n")
        }
        if let data = Prefference.defalut.globalPrefference,
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            debugString += ("globalPrefference:\n" + (jsonObject.jsonString(prettify: true) ?? "nil") + "\n")
        }
        Log.debug(debugString)
#endif
    }
}

extension Prefference: ObjectUpdatable {
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
