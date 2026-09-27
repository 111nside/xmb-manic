//
//  PretendoNetworkingConfig.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import SmartCodable

struct PretendoNetworkingConfig: SmartCodable, Equatable {
    var articBaseDone: Bool = false
    var articBaseIpAddress: String? = nil
    var articBaseRegion: String? = nil
    
    
    static func getConfig() -> PretendoNetworkingConfig {
        if let pretendoConfig = Settings.defalut.getExtraString(key: ExtraKey.pretendoConfig.rawValue),
            let config = PretendoNetworkingConfig.deserialize(from: pretendoConfig) {
#if DEBUG
            Log.debug("获取Pretendo网络配置:\n\(config.toJSONString(prettyPrint: true) ?? "")")
#endif
            return config
        }
        Log.debug("获取默认Pretendo网络配置")
        return PretendoNetworkingConfig()
    }
    
    static func updateConfig(_ config: PretendoNetworkingConfig) {
        if let jsonString = config.toJSONString() {
#if DEBUG
            Log.debug("保存Pretendo网络配置:\n\(config.toJSONString(prettyPrint: true) ?? "")")
#endif
            Settings.defalut.updateExtra(key: ExtraKey.pretendoConfig.rawValue, value: jsonString)
        }
    }
}
