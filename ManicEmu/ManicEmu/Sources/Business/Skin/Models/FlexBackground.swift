//
//  FlexBackground.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/22.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import SmartCodable

struct FlexBackgroundImage {
    var name: String
    var storeLevel: Prefference.StoreLevel
    
    var imageUrl: URL {
        URL(fileURLWithPath: R.Path.Assets.appendingPathComponent(name))
    }
    
    var image: UIImage? {
        try? UIImage(url: imageUrl)
    }
}

struct FlexBackground: SmartCodable, Equatable {
    
    var name: String = ""
    var hash: String = ""
    var games: [String] = []
    var consoles: [String] = []
    var global: Bool = false
    
    static func getAllBackground(isLandScape: Bool? = nil) -> [FlexBackground] {
        if let flexBackgroundStr = Settings.defalut.getExtraString(key: ExtraKey.flexBackground.rawValue),
           let allBackgrounds = [FlexBackground].deserialize(from: flexBackgroundStr) {
#if DEBUG
            Log.debug("[FlexBackground]>>>获取所有背景:\(allBackgrounds.toJSONString(prettyPrint: true) ?? "空")")
#endif
            return allBackgrounds.filter({
                if let isLandScape {
                    return $0.name.contains(isLandScape ? "landscape" : "portrait")
                }
                return true
            })
        }
        return []
    }
    
}
