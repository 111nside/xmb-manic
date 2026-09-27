//
//  FileType.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later



enum FileType {
    case game
    case gameSave
    case skin
    case zip
    
    init?(fileExtension: String) {
        if FileType.skin.extensions.contains(fileExtension.lowercased()) {
            self = .skin
        } else if FileType.gameSave.extensions.contains(fileExtension.lowercased()) {
            self = .gameSave
        } else if FileType.game.extensions.contains(fileExtension.lowercased()) {
            self = .game
        } else if FileType.zip.extensions.contains(fileExtension) {
            self = .zip
        } else {
            return nil
        }
    }
    
    static func allSupportFileExtension() -> [String] {
        FileType.game.extensions + FileType.gameSave.extensions + FileType.skin.extensions + FileType.zip.extensions
    }
    
    var extensions: [String] {
        FileType.getFileExtensions(for: self)
    }
    
    private static func getFileExtensions(for fileType: FileType) -> [String] {
        var results: [String] = []
        if let declarations: [[String: Any]] = R.Config.value(forKey: "UTExportedTypeDeclarations") {
            for declaration in declarations {
                let prefixItem: String
                switch fileType {
                case .game:
                    prefixItem = "game"
                case .gameSave:
                    prefixItem = "gamesave"
                case .skin:
                    prefixItem = "skin"
                case .zip:
                    prefixItem = "zip"
                }
                if let identifier = declaration["UTTypeIdentifier"] as? String,
                   identifier.contains("public.aoshuang.\(prefixItem)") {
                    if let specification = declaration["UTTypeTagSpecification"] as? [String: Any], let extensions = specification["public.filename-extension"] as? [String] {
                        results.append(contentsOf: extensions.map { $0.lowercased() }) 
                    }
                }
            }
        }
        return results
    }
    
    static func get3DSExtensions() -> [String] {
        var results: [String] = []
        if let declarations: [[String: Any]] = R.Config.value(forKey: "UTExportedTypeDeclarations") {
            for declaration in declarations {
                if let identifier = declaration["UTTypeIdentifier"] as? String,
                   identifier.contains("public.aoshuang.game.3ds") {
                    if let specification = declaration["UTTypeTagSpecification"] as? [String: Any], let extensions = specification["public.filename-extension"] as? [String] {
                        results.append(contentsOf: extensions.map { $0.lowercased() })
                    }
                }
            }
        }
        return results
    }
    
    static func humanReadableFileSize(_ sizeInBytes: UInt64, numeralSystem: Double = 1024, decimalPlaces: Int = 2) -> String? {
        let units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
        var size = Double(sizeInBytes)
        var unitIndex = 0

        while size >= numeralSystem && unitIndex < units.count - 1 {
            size /= numeralSystem
            unitIndex += 1
        }

        if size == 0 {
            return nil
        }
        if decimalPlaces == 0 {
            return String(format: "%.0f %@", size, units[unitIndex])
        } else {
            return String(format: "%.\(decimalPlaces)f %@", size, units[unitIndex])
        }
        
    }
}
