//
//  ASLabelView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import AttributedString

class ASLabelView: BaseView {
    
    private let label = UILabel()
    
    var text: ASText? {
        didSet {
            updateViews()
        }
    }
    
    var title: String? {
        get {
            text?.attributes?.text
        }
        set {
            if var attributes = text?.attributes {
                attributes.text = newValue ?? ""
                text?.attributes = attributes
            } else if let newValue {
                text?.attributes = ASText.Attributes(text: newValue)
            } else {
                return
            }
            updateViews()
        }
    }
    
    var didTapLabelView: ((ASText.TapType) -> Void)? = nil
    
    var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet {
            guard preferredMaxLayoutWidth != oldValue else { return }
            label.preferredMaxLayoutWidth = preferredMaxLayoutWidth
            invalidateIntrinsicContentSize()
        }
    }
    
    private var lastBoundsWidth: CGFloat = 0.0
    
    init(text: ASText? = nil) {
        self.text = text
        super.init(frame: .zero)
        
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        fittingContentSize()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        syncPreferredMaxLayoutWidthIfNeeded()
        lastBoundsWidth = width
    }
    
    private var isMultiline: Bool {
        text?.attributes?.numberOfLines == 0
    }
    
    private func resolvedLayoutDimension(_ attribute: NSLayoutConstraint.Attribute) -> CGFloat? {
        switch attribute {
        case .width where bounds.width > 0:
            return bounds.width
        case .height where bounds.height > 0:
            return bounds.height
        default:
            break
        }
        
        if let value = explicitConstraintConstant(for: attribute, in: constraints) {
            return value
        }
        if let superview, let value = explicitConstraintConstant(for: attribute, in: superview.constraints) {
            return value
        }
        return nil
    }
    
    private func explicitConstraintConstant(
        for attribute: NSLayoutConstraint.Attribute,
        in constraints: [NSLayoutConstraint]
    ) -> CGFloat? {
        for constraint in constraints where constraint.isActive && constraint.relation == .equal {
            if constraint.firstItem as AnyObject === self,
               constraint.firstAttribute == attribute,
               constraint.secondItem == nil {
                return constraint.constant
            }
            if constraint.secondItem as AnyObject === self,
               constraint.secondAttribute == attribute,
               constraint.firstItem == nil {
                return constraint.constant
            }
        }
        return nil
    }
    
    private func resolvedMaxLayoutWidth() -> CGFloat {
        if preferredMaxLayoutWidth > 0 { return preferredMaxLayoutWidth }
        if let width = resolvedLayoutDimension(.width) { return width }
        guard isMultiline else { return 0 }
        
        var ancestor: UIView? = superview
        while let view = ancestor {
            if view.bounds.width > 0 {
                return view.bounds.width
            }
            ancestor = view.superview
        }
        return 0
    }
    
    private func fittingContentSize() -> CGSize {
        let maxWidth = resolvedMaxLayoutWidth()
        let fittingWidth = maxWidth > 0 ? maxWidth : CGFloat.greatestFiniteMagnitude
        let size = label.sizeThatFits(
            CGSize(width: fittingWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
    
    private func syncPreferredMaxLayoutWidthIfNeeded() {
        guard isMultiline else { return }
        // 父视图已通过 preferredMaxLayoutWidth 指定宽度时，不要用可能被压缩后的 bounds.width 覆盖
        guard preferredMaxLayoutWidth <= 0 else { return }
        let maxWidth = bounds.width
        guard maxWidth > 0, (label.preferredMaxLayoutWidth != maxWidth || lastBoundsWidth != maxWidth) else { return }
        label.preferredMaxLayoutWidth = maxWidth
        invalidateIntrinsicContentSize()
    }
    
    static func contentSize(for text: ASText) -> CGSize {
        let label = UILabel()
        apply(text: text, to: label)
        let size = label.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
    
    static func maxContentWidth(in texts: [ASText]) -> CGFloat {
        texts.map { contentSize(for: $0).width }.max() ?? 0
    }
    
    func updateViews() {
        if let _ = didTapLabelView {
            Self.apply(text: text, to: label, onTapHighlight: { [weak self] highlight in
                self?.didTapLabelView?(.highlight(highlight))
            }, onTapIcon: { [weak self] icon in
                self?.didTapLabelView?(.icon(icon))
            }, onTapLabel: { [weak self] in
                self?.didTapLabelView?(.label)
            })
        } else {
            Self.apply(text: text, to: label)
        }
        if preferredMaxLayoutWidth > 0 {
            label.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        } else if isMultiline {
            label.preferredMaxLayoutWidth = resolvedMaxLayoutWidth()
        }
        invalidateIntrinsicContentSize()
    }
    
    static func apply(text: ASText?,
                      to label: UILabel,
                      onTapHighlight: ((ASText.Highlight) -> Void)? = nil,
                      onTapIcon: ((ASText.Icon) -> Void)? = nil,
                      onTapLabel: (() -> Void)? = nil) {
        guard let text else {
            label.attributed.text = nil
            return
        }
        
        if let attributes = text.attributes {
            
            var asAttributes: [ASAttributedString.Attribute] = [.foreground(attributes.color),
                                                                .font(attributes.font),
                                                                .paragraph(.alignment(attributes.alignment),
                                                                           .lineBreakMode(text.attributes?.lineBreakMode ?? .byTruncatingTail),
                                                                           .lineSpacing(R.Size.LabelLineSpacing))]
            if let onTapLabel {
                // AttributedString 会在 touchesEnded 中恢复 touchesBegan 时缓存的旧文本；
                // 若在此同步更新文案，会被随后的 touchesEnded 覆盖（点击 navigation title 即如此）。
                asAttributes.append(.action(.empty) {
                    DispatchQueue.main.async {
                        onTapLabel()
                    }
                })
            }
            let textIcons = text.textIcons.filter({
                $0.position == 0 || $0.position <= attributes.text.count
            }).sorted(by: {
                $0.position <= $1.position
            })
            let isTextEmpty = attributes.text.isEmpty
            
            var attributedString = ASAttributedString(string: "")
            
            if textIcons.count > 0 {
                for (iconIndex, textIcon) in textIcons.enumerated() {
                    if textIcon.position > 0, !isTextEmpty {
                        let lastIconPosition = iconIndex > 0 ? textIcons[iconIndex-1].position : 0
                        if lastIconPosition != textIcon.position {
                            let subText = attributes.text[Int(lastIconPosition)...Int(textIcon.position-1)]
                            attributedString += ASAttributedString(string: String(subText), with: asAttributes)
                        }
                    }
                    
                    let iconImage = textIcon.icon.image(size: (textIcon.iconSize ?? attributes.font.pointSize) * R.Size.LabelIconSizeToFontSizeRatio)
                    
                    //Add a space before each icon.
                    if iconIndex != 0 {
                        attributedString += ASAttributedString(string: " ", with: asAttributes)
                    }
                    
                    
                    if let onTapIcon {
                        attributedString += ASAttributedString(.image(iconImage, .original(.offset(.offset(y: -iconImage.size.height * R.Size.IconOffsetRatioInLabel)))), action: { _ in
                            onTapIcon(textIcon)
                        })
                    } else {
                        attributedString += ASAttributedString(.image(iconImage, .original(.offset(.offset(y: -iconImage.size.height * R.Size.IconOffsetRatioInLabel)))))
                    }
                    
                    if iconIndex == textIcons.count - 1, !isTextEmpty {
                        //Add some spacing before the text and images as well.
                        attributedString += ASAttributedString(string: " ", with: asAttributes)
                        let subText = attributes.text[Int(textIcon.position)...]
                        attributedString += ASAttributedString(string: String(subText), with: asAttributes)
                    }
                }
            } else {
                attributedString += ASAttributedString(string: String(attributes.text), with: asAttributes)
            }
            
            let highlights = text.highlights
            if highlights.count > 0, !isTextEmpty {
                for highlight in highlights {
                    guard let range = attributes.text.nsRange(from: highlight.range) else { continue }
                    
                    var tempAttributes: [ASAttributedString.Attribute] = [.foreground(highlight.color),
                                                                          .font(highlight.font ?? attributes.font)]
                    if let onTapHighlight {
                        tempAttributes.append(.action({ _ in
                            onTapHighlight(highlight)
                        }))
                    }
                    attributedString = attributedString.add(tempAttributes, range: range)
                }
            }

            label.numberOfLines = attributes.numberOfLines
            label.lineBreakMode = attributes.lineBreakMode
            label.attributed.text = attributedString
        } else {
            //No text — just the icons
            let textIcons = text.textIcons.sorted(by: {
                $0.position <= $1.position
            })
            
            var attributedString = ASAttributedString(string: "")
            
            if textIcons.count > 0 {
                for textIcon in textIcons {
                    
                    let iconImage = textIcon.icon.image(size: (textIcon.iconSize ?? R.Size.SymbolSize) * R.Size.LabelIconSizeToFontSizeRatio)
                    
                    if let onTapIcon {
                        attributedString += ASAttributedString(.image(iconImage, .original(.offset(.offset(y: -iconImage.size.height * R.Size.IconOffsetRatioInLabel)))), action: { _ in
                            onTapIcon(textIcon)
                        })
                    } else {
                        attributedString += ASAttributedString(.image(iconImage, .original(.offset(.offset(y: -iconImage.size.height * R.Size.IconOffsetRatioInLabel)))))
                    }
                }
            }
            label.attributed.text = attributedString
        }
        
        if let shadow = text.shadow {
            label.layer.shadowColor = shadow.shadowColor.cgColor
            label.layer.shadowOpacity = shadow.shadowOpacity
            label.layer.shadowOffset = shadow.shadowOffset
            label.layer.shadowRadius = shadow.shadowRadius
        } else {
            label.layer.shadowColor = nil
        }
    }
}
