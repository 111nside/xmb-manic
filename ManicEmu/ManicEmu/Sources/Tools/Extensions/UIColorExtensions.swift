//
//  UIColorExtensions.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/5/9.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import DominantColors

extension UIColor {
    func forceStyle(_ style: DMUserInterfaceStyle) -> UIColor {
        self.resolvedColor(.dm, with: DMTraitCollection(userInterfaceStyle: style))
    }
    
    func reverseStyle() -> UIColor {
        UIColor(.dm, light: self.resolvedColor(.dm, with: DMTraitCollection(userInterfaceStyle: .dark)), dark: self.resolvedColor(.dm, with: DMTraitCollection(userInterfaceStyle: .light)))
    }
    
    var isDarkColor: Bool {
        var r, g, b, a: CGFloat
        (r, g, b, a) = (0, 0, 0, 0)
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return  lum < 0.50
    }
    
    static func gradientColor(bounds: CGRect, colors: [UIColor]) -> UIColor? {
        let gradientLayer = UIColor.getGradientLayer(bounds: bounds, colors: colors)
        UIGraphicsBeginImageContext(gradientLayer.bounds.size)
        gradientLayer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return UIColor(patternImage: image!)
    }
    
    static func getGradientLayer(bounds : CGRect, colors: [UIColor]) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        // gradient colors in order which they will visually appear
        gradient.colors = colors.map { $0.cgColor }
        
        // Gradient from left to right
        gradient.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1.0, y: 0.5)
        return gradient
    }
    
    func blended(with foreground: UIColor, fraction: CGFloat) -> UIColor {
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        foreground.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        let a = fraction * fa
        return UIColor(
            red: br * (1 - a) + fr * a,
            green: bg * (1 - a) + fg * a,
            blue: bb * (1 - a) + fb * a,
            alpha: 1
        )
    }
}
