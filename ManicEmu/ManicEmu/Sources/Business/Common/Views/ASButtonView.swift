//
//  ASButtonView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit

class ASButtonView: UIVisualEffectView {
    
    private let containerView = UIStackView()
    private let titleLabel = ASLabelView()
    private let imageView = ASIconView()
    private var containerInsets = R.Size.ButtonInsets
    
    var button: ASButton { didSet { updateViews() } }
    
    private var buttonAttributes: ASButton.Attributes {
        get { button.allAttributes[button.state] ?? button.allAttributes[.normal]! }
    }
    
    func setIcon(_ icon: ASIcon?, state: ASButton.State = .normal) {
        var attributes = button.allAttributes[state] ?? button.allAttributes[.normal]!
        attributes.icon = icon
        button = button.setAttributes(attributes, state: state)
    }
    
    func setTitle(_ title: ASText?, state: ASButton.State = .normal) {
        var attributes = button.allAttributes[state] ?? button.allAttributes[.normal]!
        attributes.title = title
        button = button.setAttributes(attributes, state: state)
    }
    
    func setTitleAttributes(_ titleAttributes: ASText.Attributes?, state: ASButton.State = .normal) {
        let attributes = button.allAttributes[state] ?? button.allAttributes[.normal]!
        var text = attributes.title ?? ASText()
        text.attributes = titleAttributes
        setTitle(text, state: state)
    }
    
    func setTitleString(_ titleString: String?, state: ASButton.State = .normal) {
        let attributes = button.allAttributes[state] ?? button.allAttributes[.normal]!
        let text = attributes.title ?? ASText()
        var textAttributes = text.attributes
        textAttributes?.text = titleString ?? ""
        setTitleAttributes(textAttributes, state: state)
    }
    
    var titlePosition: UITextLayoutDirection {
        get { button.titlePosition }
        set {
            button.titlePosition = newValue
        }
    }
    
    var enableGlass: Bool {
        get { button.enableGlass }
        set {
            button.enableGlass = newValue
        }
    }
    
    var cornerStyle: ASCornerStyle {
        get { button.cornerStyle }
        set {
            button.cornerStyle = newValue
        }
        
    }
    
    func setBorder(_ border: ASBorderStyle?, state: ASButton.State = .normal) {
        var attributes = button.allAttributes[state] ?? button.allAttributes[.normal]!
        attributes.border = border
        button = button.setAttributes(attributes, state: state)
    }
    
    var state: ASButton.State {
        get { button.state }
        set {
            if button.state != newValue {
                button.state = newValue
            }
        }
    }
    
    func setBackgroundColor(_ color: UIColor?) {
        var attributes = button.allAttributes[state] ?? button.allAttributes[.normal]!
        attributes.background = color ?? .clear
        button = button.setAttributes(attributes, state: state)
    }
    
    var didTapButton: (() -> Void)? = nil
    
    var didLongPressButton: ((UIGestureRecognizer.State) -> Void)? = nil
    
    init(_ button: ASButton) {
        
        //init
        self.button = button
        super.init(effect: nil)
        
        //init views
        containerView.alignment = .center
        containerView.distribution = .fill
        containerView.spacing = R.Size.PaddingSmall
        
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        contentView.addSubview(containerView)
        
        //layer
        masksToBounds = true
        
        //update
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if case .circle = cornerStyle {
            layerCornerRadius = height/2
        } else if case .radius(let radius) = cornerStyle {
            layerCornerRadius = radius
        }
        if let border = buttonAttributes.border {
            layerBorderColor = border.color
            layerBorderWidth = border.width
        } else {
            layerBorderColor = nil
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let fittingSize = containerView.systemLayoutSizeFitting(
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        )
        return CGSize(
            width: fittingSize.width + containerInsets.horizontal,
            height: fittingSize.height + containerInsets.vertical
        )
    }
    
    private func updateViews() {
        //tap action & accessibility
        if state == .disabled {
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            self.gestureRecognizers?.filter({ $0 is UITapGestureRecognizer }).forEach({ $0.removeFromView() })
            onFocusConfirm = nil
        } else {
            isUserInteractionEnabled = true
            isAccessibilityElement = true
            accessibilityTraits = .button
            accessibilityLabel = buttonAttributes.title?.attributes?.text
            self.addTapGesture { [weak self] gesture in
                guard let self, self.state != .disabled else { return }
                self.didTapButton?()
            }
            self.addLongPressGesture(handler: { [weak self] gesture in
                guard let self, self.state != .disabled else { return }
                self.didLongPressButton?(gesture.state)
            })
            onFocusConfirm = { [weak self] in
                guard let self, self.state != .disabled else { return false }
                self.didTapButton?()
                return true
            }
        }
        
        //glass effect for above os26
        if #available(iOS 26.0, tvOS 26.0, *), enableGlass {
            if let effect = effect as? UIGlassEffect {
                effect.isInteractive = state != .disabled
            } else {
                let glassEffect = UIGlassEffect(style: .clear)
                glassEffect.tintColor = buttonAttributes.background.withAlphaComponent(0.2)
                glassEffect.isInteractive = true
                effect = glassEffect
            }
            
            if !button.ignoreBackgroundInGlass {
                backgroundColor = buttonAttributes.background
            }
        } else {
            //tap interactive animated
            enablePressEffect = state != .disabled
            backgroundColor = buttonAttributes.background
        }
        isFocusable = state != .disabled
        
        //subbiews
        let hasImage = buttonAttributes.icon != nil
        let hasTitle = buttonAttributes.title != nil
        
        containerView.axis = (titlePosition == .left || titlePosition == .right) ? .horizontal : .vertical
        
        imageView.icon = buttonAttributes.icon
        
        if let title = buttonAttributes.title {
            titleLabel.text = title
        } else {
            titleLabel.text = nil
        }
        
        containerView.removeArrangedSubviews()
        let arrangedSubviews: [UIView] = {
            guard hasImage, hasTitle else {
                if hasImage { return [imageView] }
                if hasTitle { return [titleLabel] }
                return []
            }
            
            switch titlePosition {
            case .right, .down:
                return [imageView, titleLabel]
            case .left, .up:
                return [titleLabel, imageView]
            default:
                return [imageView, titleLabel]
            }
        }()
        arrangedSubviews.forEach {
            containerView.addArrangedSubview($0)
        }
        
        containerView.snp.remakeConstraints { make in
            switch button.sizeStyle {
            case .fixHeight(let height, let insets):
                containerInsets = insets
                make.width.greaterThanOrEqualTo(containerView.snp.height)
                make.height.equalTo(height - insets.vertical).priority(.low)
            case .fixSize(let size, let insets):
                containerInsets = insets
                make.size.equalTo(CGSize(width: max(size.width, R.Size.ButtonSizeAccessory.width) - insets.horizontal,
                                         height: max(size.height, R.Size.ButtonSizeAccessory.height) - insets.vertical)).priority(.low)
            }
            
            make.top.equalToSuperview().inset(containerInsets.top)
            make.bottom.equalToSuperview().inset(containerInsets.bottom)
            make.leading.equalToSuperview().inset(containerInsets.left)
            make.trailing.equalToSuperview().inset(containerInsets.right)
            
        }
        
        if hasImage {
            imageView.snp.remakeConstraints { make in
                if let fontPointSize = buttonAttributes.title?.attributes?.font.pointSize {
                    make.size.equalTo(CGSize(fontPointSize/R.Size.ButtonIconSizeToFontSizeRatio))
//                    make.size.equalTo(CGSize(fontPointSize))
                } else {
                    let size: CGSize
                    switch button.sizeStyle {
                    case .fixHeight(let height, let insets):
                        size = CGSize(height - insets.vertical)
                    case .fixSize(let temp, let insets):
                        size = CGSize(width: max(temp.width, R.Size.ButtonSizeAccessory.width) - insets.horizontal,
                                      height: max(temp.height, R.Size.ButtonSizeAccessory.height) - insets.vertical)
                    }
                    make.size.equalTo(size)
                }
            }
        }
        
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}
