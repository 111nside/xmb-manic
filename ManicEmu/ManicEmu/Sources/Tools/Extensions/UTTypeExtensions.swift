//
//  UTTypeExtensions.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UniformTypeIdentifiers


extension UTType {
    static var gamesaveTypes: [UTType] { allSystemTypes.gamesaveTypes }
    
    static var gameTypes: [UTType] { allSystemTypes.gameTypes }
    
    static var skinTypes: [UTType] { allSystemTypes.skinTypes }
    
    static var binTypes: [UTType] {
        if let uttype = UTType("public.aoshuang.bios") {
            return getAllTypes([uttype])
        }
        return []
    }
    
    static var configTypes: [UTType] {
        if let uttype = UTType("public.aoshuang.config") {
            return getAllTypes([uttype])
        }
        return []
    }
    
    static func getGameTypes(gameType: GameType) -> [UTType] {
        if let uttype = UTType(gameType.rawValue) {
            return getAllTypes([uttype])
        }
        return []
    }
    
    static var allInfoPlistTypes: [UTType] {
        let (gameTypes, gamesaveTypes, skinTypes, zipTypes) = infoPlistTypes
        return gameTypes + gamesaveTypes + skinTypes + zipTypes
    }
    
    static var allTypes: [UTType] {
        let (gameTypes, gamesaveTypes, skinTypes, zipTypes) = allSystemTypes
        return gameTypes + gamesaveTypes + skinTypes + zipTypes
    }
    
    ///在infoPlistTypes的基础之上 遍历系统种其他App注册的同后缀的UTType
    private static var allSystemTypes: (gameTypes: [UTType], gamesaveTypes: [UTType], skinTypes: [UTType], zipTypes: [UTType]) {
        let (gameTypes, gamesaveTypes, skinTypes, zipTypes) = infoPlistTypes
        return (getAllTypes(gameTypes), getAllTypes(gamesaveTypes), getAllTypes(skinTypes), getAllTypes(zipTypes))
    }
    
    ///info.plist中注册的UTType
    private static var infoPlistTypes: (gameTypes: [UTType], gamesaveTypes: [UTType], skinTypes: [UTType], zipTypes: [UTType]) {
        var gameTypes: [UTType] = []
        var gamesaveTypes: [UTType] = []
        var skinTypes: [UTType] = []
        var zipTypes: [UTType] = []
        //获取自己注册的UTType
        if let declarations: [[String: Any]] = R.Config.value(forKey: "UTExportedTypeDeclarations") {
            for declaration in declarations {
                if let identifier = declaration["UTTypeIdentifier"] as? String {
                    if identifier.hasPrefix("public.aoshuang.game."), let uttype = UTType(identifier) {
                        gameTypes.append(uttype)
                    } else if identifier.hasPrefix("public.aoshuang.gamesave"), let uttype = UTType(identifier) {
                        gamesaveTypes.append(uttype)
                    } else if identifier.hasPrefix("public.aoshuang.skin"), let uttype = UTType(identifier) {
                        skinTypes.append(uttype)
                    } else if identifier.hasPrefix("public.aoshuang.zip"), let uttype = UTType(identifier) {
                        zipTypes.append(uttype)
                    }
                }
            }
        }
        return (gameTypes, gamesaveTypes, skinTypes, zipTypes)
    }
    
    ///遍历系统中其他App注册的UTType
    private static func getAllTypes(_ selfRegisterTypes: [UTType]) -> [UTType] {
        //查询系统中其他App注册的UTType
        var allTypes = Set<UTType>()
        for type in selfRegisterTypes {
            if let extensions = type.tags[.filenameExtension] {
                for extens in extensions {
                    UTType.types(tag: extens, tagClass: .filenameExtension, conformingTo: nil).forEach { allTypes.insert($0) }
                }
            }
        }
        return Array(allTypes)
    }
}
