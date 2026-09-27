//
//  PSPNetworkingConfig.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import SmartCodable

struct PSPNetworkingConfig: SmartCodable, Equatable {
    enum ConfigType: Int, Decodable, Encodable {
        case local, online
    }
    
    var enable: Bool = false
    var type: ConfigType = .local
    var asHost: Bool = false
    var asHostPort: Int32 = 1000
    var connectedHost: String = "socom.cc"
    var connectedLocalIP: String? = nil
    var hostList: [String] = []
    
    static func getConfig() -> PSPNetworkingConfig {
        if let pspConfig = Settings.defalut.getExtraString(key: ExtraKey.pspConfig.rawValue),
            let config = PSPNetworkingConfig.deserialize(from: pspConfig) {
#if DEBUG
            Log.debug("获取PSP网络配置:\n\(config.toJSONString(prettyPrint: true) ?? "")")
#endif
            return config
        }
        Log.debug("获取默认PSP网络配置")
        return PSPNetworkingConfig()
    }
    
    static func updateConfig(_ config: PSPNetworkingConfig) {
        if let jsonString = config.toJSONString() {
#if DEBUG
            Log.debug("保存PSP网络配置:\n\(config.toJSONString(prettyPrint: true) ?? "")")
#endif
            Settings.defalut.updateExtra(key: ExtraKey.pspConfig.rawValue, value: jsonString)
        }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.enable == rhs.enable,
                lhs.type == rhs.type,
                lhs.asHost == rhs.asHost,
                lhs.asHostPort == rhs.asHostPort,
                lhs.connectedHost == rhs.connectedHost,
                lhs.connectedLocalIP == rhs.connectedLocalIP,
                lhs.hostList == rhs.hostList else {
            return false
        }
        return true
    }
}
