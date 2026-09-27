//
//  ShaderConfig.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/22.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import SmartCodable

@available(*, deprecated)
struct ShaderConfig: SmartCodable {
    
    var coreConfigs: [String: String] = [:] // "NES" : "/xxx/xxx/xxx.glslp"
    var globalConfig: String?
    
    static func getConfig() -> ShaderConfig? {
        if let shaderConfigString = Settings.defalut.getExtraString(key: ExtraKey.shaderConfig.rawValue),
           let shaderConfig = ShaderConfig.deserialize(from: shaderConfigString) {
            return shaderConfig
        }
        return nil
    }
}
