//
//  SymbolButton.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import UIKit

class SymbolButton: BaseView {
    // iOS 26+ 使用 UIButton 作为 glass 容器
    private var glassButton: UIButton?
    private let containerView = UIView()
    
    /// 返回应该接收手势识别器的视图（iOS 26 返回内部按钮，iOS 25 返回自身）
    var interactiveView: UIView {
        if #available(iOS 26.0, tvOS 26.0, *), let glassButton = glassButton {
            return glassButton
        }
        return self
    }
    
    lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()
    
    let titleLabel = UILabel()
    
    /// 是否启用 Glass 效果（仅 iOS 26+ 有效）
    private var isGlassEnabled: Bool = false
    
    var enableRoundCorner: Bool = false {
        didSet {
            updateCornerRadius()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if enableRoundCorner {
            updateCornerRadius()
        }
    }
    
    private func updateCornerRadius() {
        if enableRoundCorner {
            let radius = height/2
            layer.cornerRadius = radius
            
            // 同时更新 glassButton 的圆角
            if #available(iOS 26.0, tvOS 26.0, *), let glassButton = glassButton {
                glassButton.layer.cornerRadius = radius
                glassButton.clipsToBounds = true
            }
        }
    }
    
    convenience init(symbol: SFSymbol,
                     title: String,
                     titleFont: UIFont = R.Font.Caption(),
                     titleColor: UIColor = R.Color.LabelPrimary,
                     titleAlignment: NSTextAlignment = .center,
                     edgeInsets: UIEdgeInsets? = nil,
                     horizontalContian: Bool = false,
                     titlePosition: UITextLayoutDirection = .down,
                     imageAndTitlePadding: CGFloat = R.Size.ContentSpaceTiny,
                     enableGlass: Bool = false,
                     cornerStyle: UIButton.Configuration.CornerStyle = .capsule) {
        self.init(image: .symbolImage(symbol), title: title, titleFont: titleFont, titleColor: titleColor, titleAlignment: titleAlignment, edgeInsets: edgeInsets, horizontalContian: horizontalContian, titlePosition: titlePosition, imageAndTitlePadding: imageAndTitlePadding, enableGlass: enableGlass, cornerStyle: cornerStyle)
    }
    
    init(image: UIImage?,
         title: String,
         titleFont: UIFont = R.Font.Caption(),
         titleColor: UIColor = R.Color.LabelPrimary,
         titleAlignment: NSTextAlignment = .center,
         edgeInsets: UIEdgeInsets? = nil,
         horizontalContian: Bool = false,
         titlePosition: UITextLayoutDirection = .down,
         imageAndTitlePadding: CGFloat = R.Size.ContentSpaceTiny,
         enableGlass: Bool = false,
         cornerStyle: UIButton.Configuration.CornerStyle = .capsule) {
        super.init(frame: .zero)
        
        isAccessibilityElement = true
        accessibilityTraits = .button
        
        self.isGlassEnabled = enableGlass
        
        // 只有 iOS 26+ 且 enableGlass 为 true 时才使用 glass 效果
        if #available(iOS 26.0, tvOS 26.0, *), enableGlass {
            // iOS 26 + Glass enabled: 使用 UIButton.Configuration.glass() 作为容器
            setupGlassButton(image: image,
                             title: title,
                             titleFont: titleFont,
                             titleColor: titleColor,
                             titleAlignment: titleAlignment,
                             edgeInsets: edgeInsets,
                             horizontalContian: horizontalContian,
                             titlePosition: titlePosition,
                             imageAndTitlePadding: imageAndTitlePadding,
                             cornerStyle: cornerStyle)
        } else {
            // iOS 25 及以下 或 enableGlass 为 false: 使用传统样式 + enablePressEffect 动画
            setupTraditionalView(image: image,
                                 title: title,
                                 titleFont: titleFont,
                                 titleColor: titleColor,
                                 titleAlignment: titleAlignment,
                                 edgeInsets: edgeInsets,
                                 horizontalContian: horizontalContian,
                                 titlePosition: titlePosition,
                                 imageAndTitlePadding: imageAndTitlePadding)
        }
        setupFocusConfirm()
    }
    
    @available(iOS 26.0, *)
    private func setupGlassButton(image: UIImage?, 
                                  title: String,
                                  titleFont: UIFont,
                                  titleColor: UIColor,
                                  titleAlignment: NSTextAlignment,
                                  edgeInsets: UIEdgeInsets?,
                                  horizontalContian: Bool,
                                  titlePosition: UITextLayoutDirection,
                                  imageAndTitlePadding: CGFloat,
                                  cornerStyle: UIButton.Configuration.CornerStyle = .capsule) {
        backgroundColor = .clear
        
        // 创建 glass 容器按钮（只提供 glass 效果，不显示内容）
        var config = UIButton.Configuration.glass()
        config.cornerStyle = cornerStyle
        
        let button = UIButton(configuration: config)
        button.isUserInteractionEnabled = true // iOS 26 的 Liquid Glass 需要处理触摸以显示视觉效果
        glassButton = button
        addSubview(button)
        
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 在 glass 容器内添加 containerView，使用 UIImageView 和 UILabel
        button.addSubview(containerView)
        containerView.addSubviews([imageView, titleLabel])
        
        containerView.snp.makeConstraints { make in
            if let edgeInsets = edgeInsets {
                make.leading.equalToSuperview().inset(edgeInsets.left)
                make.top.equalToSuperview().inset(edgeInsets.top)
                make.trailing.equalToSuperview().inset(edgeInsets.right)
                make.bottom.equalToSuperview().inset(edgeInsets.bottom)
            } else {
                make.center.equalToSuperview()
            }
            if horizontalContian {
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
            }
        }
        
        imageView.snp.makeConstraints { make in
            switch titlePosition {
            case .right:
                make.leading.top.bottom.equalToSuperview()
                make.width.greaterThanOrEqualTo(0)
            case .left:
                make.trailing.top.bottom.equalToSuperview()
                make.width.greaterThanOrEqualTo(0)
            case .up:
                make.leading.trailing.bottom.equalToSuperview()
            case .down:
                make.leading.top.trailing.equalToSuperview()
            default:
                break
            }
        }
        imageView.image = image
        
        titleLabel.font = titleFont
        titleLabel.textColor = titleColor
        titleLabel.textAlignment = titleAlignment
        titleLabel.snp.makeConstraints { make in
            switch titlePosition {
            case .right:
                make.top.trailing.bottom.equalToSuperview()
                make.leading.equalTo(imageView.snp.trailing).offset(imageAndTitlePadding)
            case .left:
                make.top.leading.bottom.equalToSuperview()
                make.trailing.equalTo(imageView.snp.leading).offset(-imageAndTitlePadding)
            case .up:
                make.top.trailing.leading.equalToSuperview()
                make.bottom.equalTo(imageView.snp.top).offset(-imageAndTitlePadding)
            case .down:
                make.leading.trailing.bottom.equalToSuperview()
                make.top.equalTo(imageView.snp.bottom).offset(imageAndTitlePadding)
            default:
                break
            }
        }
        titleLabel.text = title
    }
    
    private func setupTraditionalView(image: UIImage?,
                                     title: String,
                                     titleFont: UIFont,
                                     titleColor: UIColor,
                                     titleAlignment: NSTextAlignment,
                                     edgeInsets: UIEdgeInsets?,
                                     horizontalContian: Bool,
                                     titlePosition: UITextLayoutDirection,
                                     imageAndTitlePadding: CGFloat) {
        enablePressEffect = true
        backgroundColor = R.Color.BackgroundSecondary
        layerCornerRadius = R.Size.CornerRadiusMedium
        
        addSubview(containerView)
        containerView.addSubviews([imageView, titleLabel])
        
        containerView.snp.makeConstraints { make in
            if let edgeInsets = edgeInsets {
                make.leading.equalToSuperview().inset(edgeInsets.left)
                make.top.equalToSuperview().inset(edgeInsets.top)
                make.trailing.equalToSuperview().inset(edgeInsets.right)
                make.bottom.equalToSuperview().inset(edgeInsets.bottom)
            } else {
                make.center.equalToSuperview()
            }
            if horizontalContian {
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
            }
        }
        
        imageView.snp.makeConstraints { make in
            switch titlePosition {
            case .right:
                make.leading.top.bottom.equalToSuperview()
                make.width.greaterThanOrEqualTo(0)
            case .left:
                make.trailing.top.bottom.equalToSuperview()
                make.width.greaterThanOrEqualTo(0)
            case .up:
                make.leading.trailing.bottom.equalToSuperview()
            case .down:
                make.leading.top.trailing.equalToSuperview()
            default:
                break
            }
        }
        imageView.image = image
        
        titleLabel.font = titleFont
        titleLabel.textColor = titleColor
        titleLabel.textAlignment = titleAlignment
        titleLabel.snp.makeConstraints { make in
            switch titlePosition {
            case .right:
                make.top.trailing.bottom.equalToSuperview()
                make.leading.equalTo(imageView.snp.trailing).offset(imageAndTitlePadding)
            case .left:
                make.top.leading.bottom.equalToSuperview()
                make.trailing.equalTo(imageView.snp.leading).offset(-imageAndTitlePadding)
            case .up:
                make.top.trailing.leading.equalToSuperview()
                make.bottom.equalTo(imageView.snp.top).offset(-imageAndTitlePadding)
            case .down:
                make.leading.trailing.bottom.equalToSuperview()
                make.top.equalTo(imageView.snp.bottom).offset(imageAndTitlePadding)
            default:
                break
            }
        }
        titleLabel.text = title
    }
    
    convenience init(symbol: SFSymbol, symbolFont: UIFont? = nil, symbolColor: UIColor = R.Color.LabelPrimary, enableGlass: Bool = false, cornerStyle: UIButton.Configuration.CornerStyle = .capsule) {
        self.init(image: .symbolImage(symbol).applySymbolConfig(font: symbolFont, color: symbolColor), enableGlass: enableGlass, cornerStyle: cornerStyle)
    }
    
    init(image: UIImage?, enableGlass: Bool = false, cornerStyle: UIButton.Configuration.CornerStyle = .capsule) {
        super.init(frame: .zero)
        
        isAccessibilityElement = true
        accessibilityTraits = .button
        
        self.isGlassEnabled = enableGlass
        
        // 只有 iOS 26+ 且 enableGlass 为 true 时才使用 glass 效果
        if #available(iOS 26.0, tvOS 26.0, *), enableGlass {
            // iOS 26 + Glass enabled: 使用 UIButton.Configuration.glass() 作为容器
            backgroundColor = .clear
            
            var config = UIButton.Configuration.glass()
            config.cornerStyle = cornerStyle
            
            let button = UIButton(configuration: config)
            button.isUserInteractionEnabled = true // iOS 26 的 Liquid Glass 需要处理触摸以显示视觉效果
            glassButton = button
            addSubview(button)
            
            button.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            // 在 glass 容器内添加 imageView
            button.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            imageView.image = image
        } else {
            // iOS 25 及以下 或 enableGlass 为 false: 使用传统样式 + enablePressEffect 动画
            enablePressEffect = true
            backgroundColor = R.Color.BackgroundSecondary
            
            addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            imageView.image = image
        }
        setupFocusConfirm()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupFocusConfirm() {
        isFocusable = true
        onFocusConfirm = { [weak self] in
            self?.triggerTapGesture()
            return true
        }
    }
    
    /// 重写 addGestureRecognizer，确保手势识别器添加到正确的视图
    /// iOS 26: 添加到内部的 glassButton
    /// iOS 25: 添加到父视图自身
    override func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if #available(iOS 26.0, tvOS 26.0, *), let glassButton = glassButton {
            glassButton.addGestureRecognizer(gestureRecognizer)
        } else {
            super.addGestureRecognizer(gestureRecognizer)
        }
    }
    
    /// 重写 removeGestureRecognizer，确保从正确的视图移除
    override func removeGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if #available(iOS 26.0, tvOS 26.0, *), let glassButton = glassButton {
            glassButton.removeGestureRecognizer(gestureRecognizer)
        } else {
            super.removeGestureRecognizer(gestureRecognizer)
        }
    }
    
    func triggerTapGesture() {
        if #available(iOS 26.0, tvOS 26.0, *), let glassButton = glassButton {
            glassButton.sendActions(for: .touchUpInside)
            for gestureRecognizer in glassButton.gestureRecognizers ?? [] {
                if let tapGesture = gestureRecognizer as? UITapGestureRecognizer {
                    tapGesture.state = .ended
                }
            }
        } else {
            _ = fk_fireTapGestures()
        }
    }
}
