//
//  UIimageExtensions.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/5/9.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import DominantColors

extension UIImage {
    
    static func symbolImage(_ symbol: SFSymbol) -> UIImage {
        UIImage(symbol: symbol)
    }

    /// 生成SFSymbol
    /// - Parameters:
    ///   - symbol: symbol
    ///   - size: 尺寸 默认:R.Size.SymbolSize
    ///   - weight: 字重 默认:regular
    ///   - font: 字体大小，如果设置了font，则size、weight无效 默认:nil
    ///   - color: 颜色 默认:R.Color.LabelPrimary
    ///   - colors: 调色盘 如果设置了colors，则color无效 默认:nil
    convenience init(symbol: SFSymbol,
                     size: CGFloat = R.Size.SymbolSize,
                     weight: UIFont.Weight = .regular,
                     font: UIFont? = nil,
                     color: UIColor = R.Color.LabelPrimary,
                     colors: [UIColor]? = nil) {
        let sizeConfig = UIImage.SymbolConfiguration(font: font ?? UIFont.systemFont(ofSize: size))
        let colorConfig = UIImage.SymbolConfiguration(paletteColors: colors ?? [color])
        self.init(systemSymbol: symbol, withConfiguration: sizeConfig.applying(colorConfig))
    }
    
//    static func symbolImage()
    
    
//    convenience init(symbol: SFSymbol,
//                     font: UIFont? = nil,
//                     colors: [UIColor]? = nil) {
//        var sizeConfig: UIImage.SymbolConfiguration? = nil
//        var colorConfig: UIImage.SymbolConfiguration? = nil
//        if let font {
//            sizeConfig = UIImage.SymbolConfiguration(font: font)
//        }
//        if let colors, colors.count > 0 {
//            colorConfig = UIImage.SymbolConfiguration(paletteColors: colors)
//        }
//        
//        var symbolConfig: UIImage.SymbolConfiguration? = nil
//        if let sizeConfig {
//            symbolConfig = sizeConfig
//        }
//        if let colorConfig {
//            if symbolConfig != nil {
//                symbolConfig = symbolConfig?.applying(colorConfig)
//            } else {
//                symbolConfig = colorConfig
//            }
//        }
//        
//        if let symbolConfig {
//            self.init(systemSymbol: symbol, withConfiguration: symbolConfig)
//        } else {
//            self.init(systemSymbol: symbol)
//        }
//    }
    
    /// 生成一个可以设定背景大小的SFSymbol
    /// - Parameters:
    ///   - backgroundColor: 背景颜色
    ///   - imageSize: 整个图片大小
    convenience init(symbol: SFSymbol,
                     size: CGFloat = R.Size.SymbolSize,
                     weight: UIFont.Weight = .regular,
                     font: UIFont? = nil,
                     color: UIColor = R.Color.LabelPrimary,
                     colors: [UIColor]? = nil,
                     backgroundColor: UIColor,
                     imageSize: CGSize) {
        let symbolImage = UIImage(symbol: symbol, size: size, weight: weight, font: font, color: color, colors: colors)
        let format = UIGraphicsImageRendererFormat()
        guard let image = UIGraphicsImageRenderer(size: imageSize, format: format).image(actions: { context in
            backgroundColor.setFill()
            context.fill(context.format.bounds)
            symbolImage.draw(in: CGRect(center: CGPoint(x: imageSize.width/2, y: imageSize.height/2), size: CGSize(width: size, height: size)))
        }).cgImage else {
            self.init()
            return
        }
        self.init(cgImage: image, scale: UIWindow.applicationWindow?.screen.scale ?? 1, orientation: .up)
    }
    
    /// 自定义SFSymbol配置
    /// - Parameters:
    ///   - symbol: symbol
    ///   - size: 尺寸 默认:R.Size.SymbolSize
    ///   - weight: 字重 默认:regular
    ///   - font: 字体大小，如果设置了font，则size、weight无效 默认:nil
    ///   - color: 颜色 默认:R.Color.LabelPrimary
    ///   - colors: 调色盘 如果设置了colors，则color无效 默认:nil
    func applySymbolConfig(size: CGFloat = R.Size.SymbolSize,
                           weight: UIFont.Weight = .regular,
                           font: UIFont? = nil,
                           color: UIColor = R.Color.LabelPrimary,
                           colors: [UIColor]? = nil) -> UIImage {
        let sizeConfig = UIImage.SymbolConfiguration(font: font ?? UIFont.systemFont(ofSize: size))
        let colorConfig = UIImage.SymbolConfiguration(paletteColors: colors ?? [color])
        return self.withConfiguration(sizeConfig.applying(colorConfig))
    }
    
    /// 获取缺省图
    /// - Parameter preferenceSize: 调整大小
    /// - Returns: 图片
    static var placeHolderImageCaches = [String: UIImage]()
    static func placeHolder(preferenceSize: CGSize? = nil,
                            color: UIColor? = nil) -> UIImage {
        let logoImage = R.image.logo_iconSymbols() ?? UIImage(systemSymbol: .photo)
        let contentSize = preferenceSize ?? CGSize(100)
        let fontSize = contentSize.minDimension*0.6
        
        let sizeHash = "\(contentSize.width)_\(contentSize.height)"
        if let cacheImage = placeHolderImageCaches[sizeHash] {
            return cacheImage
        }
        
        let lightImage = logoImage.applySymbolConfig(size: fontSize,
                                                     color: (color ?? R.Color.BackgroundTertiary).forceStyle(.light))
        let darkImage = logoImage.applySymbolConfig(size: fontSize,
                                                    color: (color ?? R.Color.BackgroundTertiary).forceStyle(.dark))
        
        let lightContentCgImage = UIGraphicsImageRenderer(size: contentSize, format: UIGraphicsImageRendererFormat()).image(actions: { context in
            lightImage.draw(in: CGRect(center: CGPoint(x: contentSize.width/2, y: contentSize.height/2), size: lightImage.size))
        }).cgImage
        
        let darkContentCgImage = UIGraphicsImageRenderer(size: contentSize, format: UIGraphicsImageRendererFormat()).image(actions: { context in
            darkImage.draw(in: CGRect(center: CGPoint(x: contentSize.width/2, y: contentSize.height/2), size: darkImage.size))
        }).cgImage
        
        let resultImage: UIImage
        if let lightContentCgImage, let darkContentCgImage {
            let lightContentImage = UIImage(cgImage: lightContentCgImage, scale: UIWindow.applicationWindow?.screen.scale ?? 1, orientation: .up)
            let darkContentImage = UIImage(cgImage: darkContentCgImage, scale: UIWindow.applicationWindow?.screen.scale ?? 1, orientation: .up)
            resultImage = UIImage(.dm, light: lightContentImage, dark: darkContentImage)
        } else {
            resultImage = UIImage(.dm, light: lightImage, dark: darkImage)
        }
        placeHolderImageCaches[sizeHash] = resultImage
        return resultImage
    }
    
    /// 根据尺寸缩放图片 如果传入的尺寸比例和原图不一致还会进行居中裁剪
    func scaled(toSize: CGSize, opaque: Bool = false) -> UIImage? {
        guard toSize != .zero else { return self }
        
        var toSize = toSize
        if let scene = ApplicationSceneDelegate.applicationScene, self.scale != scene.screen.scale {
            //scale不同需要对size做一些处理
            let ratio = scene.screen.scale/self.scale
            toSize = CGSize(width: toSize.width * ratio, height: toSize.height * ratio)
        }
        
        var isMaxHeight: Bool = false
        var isSideEqual: Bool = false
        let scaledImage: UIImage?
        if toSize.width == toSize.height {
            scaledImage = scaled(toHeight: toSize.height, opaque: opaque)
            isSideEqual = true
        } else if toSize.width > toSize.height {
            scaledImage = scaled(toHeight: toSize.height, opaque: opaque)
        }  else {
            scaledImage = scaled(toWidth: toSize.width, opaque: opaque)
            isMaxHeight = true
        }
        
        guard let scaledImage = scaledImage else { return self }
        
        if isSideEqual {
            return scaledImage
        } else {
            let croppedRect = CGRect(origin: isMaxHeight ? .init(x: (scaledImage.size.width - toSize.width)/2, y: 0) : .init(x: 0, y: (scaledImage.size.height - toSize.height)/2), size: toSize)
            return scaledImage.cropped(to: croppedRect)
        }
    }
    
    ///尝试将data转换成图片 如果失败则返回缺省图
    static func tryDataImageOrPlaceholder(tryData: Data?, preferenceSize: CGSize? = nil) -> UIImage {
        if let tryData = tryData, let image = UIImage(data: tryData, scale: ApplicationSceneDelegate.applicationScene?.screen.scale ?? 1) {
            if let preferenceSize = preferenceSize {
                return image.scaled(toSize: preferenceSize) ?? image
            }
            return image
        } else {
            return UIImage.placeHolder(preferenceSize: preferenceSize)
        }
    }
    
    /// 为image生成主背景
    var dominantBackground: UIColor {
        return dominantColors().background ?? R.Color.BackgroundSecondary
    }
    
    func dominantColors() -> (background: UIColor?, primary: UIColor?, secondary: UIColor?) {
        if let cgImage = self.cgImage,
            let colors = try? DominantColors.dominantColors(image: cgImage, options: [.excludeGray]),
            let contrastColors = ContrastColors(orderedColors: colors, ignoreContrastRatio: true) {
            return (contrastColors.background.uiColor, contrastColors.primary.uiColor, contrastColors.secondary?.uiColor)
        }
        return (nil, nil, nil)
    }
    
    func processGameSnapshop() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let imageScale = R.Numbers.GameSnapshotScaleRatio
        let imageSize = CGSize(width: self.size.width * imageScale, height: self.size.height * imageScale)
        
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        let screenshotData = renderer.pngData { (context) in
            context.cgContext.interpolationQuality = .none
            self.draw(in: CGRect(origin: .zero, size: imageSize))
        }
        return screenshotData
    }
    
    static func  radialGradientImage(size: CGSize,
                                    colors: [UIColor],
                                    completion: ((UIImage?)->Void)? = nil) {
        DispatchQueue.global().async {
            let scale = UIScreen.main.scale
            
            let locations = colors.gradientLocations()
            
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            guard let context = UIGraphicsGetCurrentContext() else {
                DispatchQueue.main.async {
                    completion?(nil)
                }
                return
            }
            
            let cgColors = colors.map { $0.cgColor } as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace,
                                      colors: cgColors,
                                      locations: locations)
            
            // 渐变中心：底部中点 (0.5, 1.0)
            let center = CGPoint(x: size.width*0.5 - 50, y: size.height*1.0)
            let radius = size.height - 10
            
            context.drawRadialGradient(
                gradient!,
                startCenter: center,
                startRadius: 0,
                endCenter: CGPoint(x: center.x + 50, y: center.y),
                endRadius: radius,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            DispatchQueue.main.async {
                completion?(image)
            }
        }
    }
    
    
    static func radialGradientImage(size: CGSize,
                                    colors: [UIColor],
                                    startCenter: CGPoint = .init(x: 0.5, y: 0.5),
                                    endCenter: CGPoint? = nil,
                                    startRadius: CGFloat? = nil,
                                    endRadius: CGFloat? = nil,
                                    completion: ((UIImage?)->Void)? = nil) {
        DispatchQueue.global().async {
            let scale = UIScreen.main.scale
            
            let locations = colors.gradientLocations()
            
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            guard let context = UIGraphicsGetCurrentContext() else {
                DispatchQueue.main.async {
                    completion?(nil)
                }
                return
            }
            
            let cgColors = colors.map { $0.cgColor } as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace,
                                      colors: cgColors,
                                      locations: locations)
            
            let sCenter = CGPoint(x: size.width*startCenter.x, y: size.height*startCenter.y)
            var eCenter = sCenter
            if let endCenter {
                eCenter = CGPoint(x: size.width*endCenter.x, y: size.height*endCenter.y)
            }
            
            
            context.drawRadialGradient(
                gradient!,
                startCenter: sCenter,
                startRadius: startRadius ?? 0,
                endCenter: eCenter,
                endRadius: endRadius ?? size.height,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            DispatchQueue.main.async {
                completion?(image)
            }
        }
    }
}
