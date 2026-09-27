//
//  ShaderToy.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

struct ShaderToy {
    
    enum Style: Int, CaseIterable {
        case none
        case mellowVoronoi
        case synthwaveSunset
        case paperScroll
        case insideTheMatrix
        case singularity
        case floatingPlaystationShapes
        case harmonicSineWave
        case gradientFlow
        case pS3HomeBackground
        case pSPXMB
        case custom
    }
    
    var style: Style
    var customFileName: String? = nil
    
    
    var author: String? {
        switch style {
        case .mellowVoronoi:
            "Mipmap"
        case .synthwaveSunset:
            "nyri0"
        case .paperScroll:
            "Ping2_0"
        case .insideTheMatrix:
            "And390"
        case .singularity:
            "Xor"
        case .floatingPlaystationShapes:
            "will7007"
        case .harmonicSineWave:
            "trinketMage"
        case .gradientFlow:
            "hahnzhu"
        case .pS3HomeBackground:
            "ejonghyuck"
        case .pSPXMB:
            "ChatGPT"
        default:
            nil
        }
    }
    
    var script: String? {
        switch style {
        case .none:
            return nil
        case .mellowVoronoi:
            return Self.MellowVoronoi
        case .synthwaveSunset:
            return Self.SynthwaveSunset
        case .paperScroll:
            return Self.PaperScroll
        case .insideTheMatrix:
            return Self.InsideTheMatrix
        case .singularity:
            return Self.Singularity
        case .floatingPlaystationShapes:
            return Self.floatingPlaystationShapesScript(darkBlue: UIColor(.dm,
                                                                          light: R.Color.BackgroundPrimary.forceStyle(.light),
                                                                          dark: .black),
                                                        lightBlue: UIColor(.dm,
                                                                           light: .white,
                                                                           dark: R.Color.BackgroundPrimary.forceStyle(.dark)),
                                                        shapeGray: R.Color.LabelTertiary)
        case .harmonicSineWave:
            return Self.harmonicSineWaveScript(backgroundColor: UIColor(.dm,
                                                                        light: UIColor(white: 0.9, alpha: 1),
                                                                        dark: .black),
                                               waveColor: UIColor(.dm,
                                                                  light: .white,
                                                                  dark: R.Color.BackgroundPrimary.forceStyle(.dark)))
        case .gradientFlow:
            return Self.gradientFlowScript(colors: R.Color.Gradient)
        case .pS3HomeBackground:
            if UIDevice.isDarkMode {
                return Self.pS3HomeBackgroundScript(top: R.Color.BackgroundPrimary,
                                                    bottom: .black,
                                                    wave: UIColor(white: 0.3, alpha: 1))
            } else {
                return Self.pS3HomeBackgroundScript()
            }
            
        case .pSPXMB:
            // 浅色 ≈ PlayStation 银色主题；深色 ≈ 黑色主题
            return Self.pSPXMBScript(
                backgroundBottom: UIColor(.dm,
                                          light: UIColor(red: 0.88, green: 0.89, blue: 0.91, alpha: 1),
                                          dark: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)),
                backgroundTop: UIColor(.dm,
                                       light: UIColor(red: 0.62, green: 0.64, blue: 0.68, alpha: 1),
                                       dark: UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)),
                waveTop: UIColor(.dm,
                                 light: UIColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1),
                                 dark: UIColor(red: 0.22, green: 0.23, blue: 0.27, alpha: 1)),
                waveBottom: UIColor(.dm,
                                    light: UIColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1),
                                    dark: UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1)),
                highlight: UIColor(.dm,
                                   light: .white,
                                   dark: UIColor(red: 0.38, green: 0.40, blue: 0.46, alpha: 1)))

        case .custom:
            if let customFileName {
                return try? String(contentsOfFile: R.Path.Assets.appendingPathComponent(customFileName),
                                   encoding: .utf8)
            }
            return nil
        }
    }
    
    var title: String {
        switch style {
        case .none:
            return R.string.localizable.disableTitle()
        case .mellowVoronoi:
            return "Mellow Voronoi"
        case .synthwaveSunset:
            return "Synthwave sunset"
        case .paperScroll:
            return "Paper scroll"
        case .insideTheMatrix:
            return "Matrix Rain"
        case .singularity:
            return "Singularity"
        case .floatingPlaystationShapes:
            return "Floating Shapes"
        case .harmonicSineWave:
            return "Harmonic Sine Wave"
        case .gradientFlow:
            return "Gradient Flow"
        case .pS3HomeBackground:
            return "Wave Flow"
        case .pSPXMB:
            return "Flat Wave Flow"
        case .custom:
            if let customFileName {
                return customFileName.deletingPathExtension
            }
            return ""
            
        }
    }
    
    var icon: ASIcon {
        switch style {
        case .none:
                .symbol(.nosign)
        case .mellowVoronoi:
                .image(R.image.mellowVoronoi(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .synthwaveSunset:
                .image(R.image.synthwaveSunset(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .paperScroll:
                .image(R.image.paperScroll(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .insideTheMatrix:
                .image(R.image.insideTheMatrix(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .singularity:
                .image(R.image.singularity(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .floatingPlaystationShapes:
                .image(R.image.floatingPlaystationShapes(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .harmonicSineWave:
                .image(R.image.harmonicSineWave(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .gradientFlow:
                .image(R.image.gradientFlow(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .pS3HomeBackground:
                .image(R.image.pS3HomeBackground(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .pSPXMB:
                .image(R.image.pSPXMB(), cornerStyle: .radius(R.Size.CornerRadiusMicro))
        case .custom:
                .symbolImage(R.image.advance_shader_iconSymbols())
        }
    }
    
    ///横屏背景 MetalToy 渲染分辨率比例。边缘硬的脚本略提高以减锯齿。
    var preferredRenderScale: CGFloat {
        switch style {
        case .synthwaveSunset:
            return 0.55
        case .none:
            return 0.35
        default:
            return 0.35
        }
    }
    
    static func getUsingShaderToy() -> Self {
        if let value = Settings.defalut.getExtra(key: ExtraKey.landscapeShaderToy.rawValue) {
            if let value = value as? Int,
               let style = ShaderToy.Style(rawValue: value),
                style != .custom {
                return ShaderToy(style: style)
            } else if let value = value as? String {
                return ShaderToy(style: .custom, customFileName: value)
            }
        }
        return ShaderToy(style: .harmonicSineWave)
    }
    
    static func getBuildInShaderToys() -> [Self] {
        return ShaderToy.Style.allCases.filter({ $0 != .custom }).map({
            ShaderToy(style: $0)
        })
    }
    
    static func getCustomShaderToys() -> [Self] {
        if let contents = (try? FileManager.default.contentsOfDirectory(atPath: R.Path.Assets))?.filter({
            $0.pathExtension.lowercased() == "glsl"
        }) {
            return contents.map({ ShaderToy(style: .custom, customFileName: $0) })
        }
        return []
    }
}
