//
//  HomeMenuImage.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit


class HomeMenuImage: UIImage, @unchecked Sendable {
    
    private static var cache = NSCache<NSString, UIImage>()
    
    convenience init(size: CGSize, gameType: GameType, isDSi: Bool) {
        let cacheKey = NSString(string: "\(gameType.rawValue)_\(R.Style.GameCoverStyle.rawValue)_\(isDSi)_\(size.width)x\(size.height)")
        
        if let cachedImage = HomeMenuImage.cache.object(forKey: cacheKey) {
            self.init(cgImage: cachedImage.cgImage!)
            return
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let composedImage = renderer.image { context in
            guard let bg = R.image.home_menu_bg(), let icon = R.image.home_menu_icon() else { return }
            
            // Draw backgroundImage - aspect fill
            bg.scaled(toSize: size)?.draw(in: CGRect(origin: .zero, size: CGSize(width: size.width + 0.5, height: size.height)))

            // Draw iconImage
            let iconSize = CGSize(width: size.width*0.6, height: size.width*0.6)
            icon.scaled(toSize: iconSize)?.draw(at: CGPoint(x: (size.width - iconSize.width)/2, y: (size.height-iconSize.height)/2))
            
            // Draw detailImage - bottom right with insets, no scaling
            var brand: UIImage? = nil
            let brandRatio = R.Style.GameCoverStyle == .style1 ? 0.066 : 0.06
            if gameType == .ds {
                if isDSi {
                    brand = R.image.home_menu_dsi()?.scaled(toHeight: size.height * brandRatio)
                } else {
                    brand = R.image.home_menu_nds()?.scaled(toHeight: size.height * brandRatio)
                }
            } else if gameType == ._3ds {
                brand = R.image.home_menu_3ds()?.scaled(toHeight: size.height * brandRatio)
            } else if gameType == .dos {
                brand = R.image.home_menu_dos()?.scaled(toHeight: size.height * brandRatio)
            } else if gameType == .symbian {
                brand = R.image.symbian_group_brand(compatibleWith: .init(userInterfaceStyle: .light))?.scaled(toHeight: size.height * brandRatio)
            }
            if let brand {
                if R.Style.GameCoverStyle == .style1 {
                    brand.draw(at: CGPoint(x: size.width - brand.size.width - size.width*0.0333, y: size.height - brand.size.height - size.height*0.0444))
                } else if R.Style.GameCoverStyle == .style2 {
                    brand.draw(at: CGPoint(x: (size.width - brand.size.width)/2, y: (size.height-iconSize.height)/2 + iconSize.height + size.height*0.0444))
                } else {
                    brand.draw(at: CGPoint(x: size.width - brand.size.width - size.width*0.0333, y: size.height - brand.size.height - size.height*0.1))
                }
            }
        }

        HomeMenuImage.cache.setObject(composedImage, forKey: cacheKey)
        self.init(cgImage: composedImage.cgImage!)
    }
}
