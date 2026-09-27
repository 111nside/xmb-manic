//
//  ASTextView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/20.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import AttributedString

class ASTextView: BaseView {
    private static let defaultTextContainerInset = UIEdgeInsets.zero
    
    private let textView = UITextView()
    private var lastKnownLayoutWidth: CGFloat = 0
    
    /// 避免编辑过程中回写 text 再次触发 updateViews 打断选区/菜单
    private var suppressUpdateViews = false
    
    var text: ASText? {
        didSet {
            guard !suppressUpdateViews else { return }
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
    
    var isEditable: Bool {
        get { textView.isEditable }
        set {
            guard textView.isEditable != newValue else { return }
            textView.isEditable = newValue
            // 可编辑时改走纯文本路径，避免 AttributedString 手势/菜单冲突
            updateViews()
        }
    }
    
    var didTapLabelView: ((ASText.TapType) -> Void)? = nil
    
    /// 可编辑时文本变化回调
    var didTextChange: ((String) -> Void)? = nil
    
    var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet {
            guard preferredMaxLayoutWidth != oldValue else { return }
            invalidateIntrinsicContentSize()
        }
    }
    
    /// When `true`, content keeps its natural layout size and can scroll horizontally and vertically
    /// if the container is smaller than the content. When `false` (default), content wraps to the
    /// container width (no horizontal scrolling); vertical scrolling only occurs when the container
    /// height is explicitly constrained and smaller than the wrapped content height.
    var enableOriginalLayout: Bool = false {
        didSet {
            guard enableOriginalLayout != oldValue else { return }
            lastKnownLayoutWidth = 0
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }
    
    init(text: ASText? = nil) {
        self.text = text
        super.init(frame: .zero)
        
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        
        textView.backgroundColor = .clear
        textView.textContainerInset = Self.defaultTextContainerInset
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.delaysContentTouches = true
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.delegate = self
        
        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeFirstResponder: Bool {
        return isEditable
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        if isEditable {
            return textView.becomeFirstResponder()
        }
        return false
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        return textView.resignFirstResponder()
    }
    
    @objc private func handleTextDidChange() {
        let value = textView.text ?? ""
        // 同步模型但不刷新视图，防止重置 attributedText 打断选区与编辑菜单
        if var current = text, var attributes = current.attributes {
            attributes.text = value
            current.attributes = attributes
            suppressUpdateViews = true
            text = current
            suppressUpdateViews = false
        }
        didTextChange?(value)
    }
    
    // 注意：不要把 isFirstResponder / become/resign 转发给内部 textView。
    // 父视图谎称自己是 first responder 时，系统编辑菜单会找不到可执行 copy/selectAll 的响应者。
    
    override var intrinsicContentSize: CGSize {
        return fittingContentSize()
    }
    
    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        let layoutWidth = resolvedMaxLayoutWidth()
        if layoutWidth > 0 {
            return fittingContentSize(layoutWidth: layoutWidth)
        }
        if targetSize.width > 0, targetSize.width != UIView.noIntrinsicMetric {
            return fittingContentSize(layoutWidth: targetSize.width)
        }
        return fittingContentSize()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let layoutWidth: CGFloat
        if size.width > 0 {
            layoutWidth = size.width
        } else if preferredMaxLayoutWidth > 0 {
            layoutWidth = preferredMaxLayoutWidth
        } else {
            layoutWidth = resolvedMaxLayoutWidth()
        }
        return fittingContentSize(layoutWidth: layoutWidth)
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        syncIntrinsicSizeIfNeeded()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 算高走静态测量（intrinsicContentSize），不要在 layout 时改 live textContainer：
        // 否则选中/长按系统菜单会被打断（可编辑与只读可选中均如此）。
        syncIntrinsicSizeIfNeeded()
        if !textView.isFirstResponder {
            updateScrollState()
        }
    }
    
    private static func lineBreakMode(for attributes: ASText.Attributes) -> NSLineBreakMode {
        attributes.numberOfLines == 0 ? .byWordWrapping : attributes.lineBreakMode
    }
    
    static func contentHeight(for text: ASText, width: CGFloat) -> CGFloat {
        contentSize(for: text, width: width).height
    }
    
    static func contentSize(for text: ASText?, width: CGFloat) -> CGSize {
        guard let text else { return .zero }
        let textView = makeMeasuringTextView()
        apply(text: text, to: textView)
        return measuredContentSize(of: textView, width: width)
    }
    
    private static func measuredContentSize(of textView: UITextView, width: CGFloat) -> CGSize {
        textView.textContainer.widthTracksTextView = false
        let horizontalInset = horizontalTextInset(in: textView)
        let verticalInset = verticalTextInset(in: textView)
        let containerWidth: CGFloat
        if width > 0 {
            containerWidth = max(width - horizontalInset, 1)
        } else {
            containerWidth = 10_000
        }
        textView.textContainer.size = CGSize(
            width: containerWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.layoutManager.ensureLayout(for: textView.textContainer)
        
        guard textView.textStorage.length > 0 else {
            if width > 0 {
                return CGSize(width: width, height: verticalInset)
            }
            return .zero
        }
        
        let constraintWidth = width > 0 ? containerWidth : CGFloat.greatestFiniteMagnitude
        let textRect = textView.textStorage.boundingRect(
            with: CGSize(width: constraintWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        var height = ceil(textRect.height + verticalInset)
        if textView.textContainer.maximumNumberOfLines > 0 {
            let lineHeight = textView.font?.lineHeight ?? UIFont.systemFont(ofSize: 17).lineHeight
            let maxHeight = ceil(lineHeight * CGFloat(textView.textContainer.maximumNumberOfLines) + verticalInset)
            height = min(height, maxHeight)
        }
        
        let contentWidth = width > 0 ? width : ceil(textRect.width + horizontalInset)
        return CGSize(width: contentWidth, height: height)
    }
    
    /// 是否需要 AttributedString 能力（图文混排 / 可点高亮）
    private var needsAttributedStringActions: Bool {
        guard let text else { return false }
        if !text.textIcons.isEmpty { return true }
        if !text.highlights.isEmpty { return true }
        return false
    }
    
    func updateViews() {
        lastKnownLayoutWidth = 0
        if textView.isEditable || !needsAttributedStringActions {
            applySystemTextContent()
        } else {
            // 仅在需要图标/高亮交互时走 AttributedString
            Self.apply(text: text,
                       to: textView,
                       onTapHighlight: didTapLabelView == nil ? nil : { [weak self] highlight in
                           self?.didTapLabelView?(.highlight(highlight))
                       },
                       onTapIcon: didTapLabelView == nil ? nil : { [weak self] icon in
                           self?.didTapLabelView?(.icon(icon))
                       })
            // attributed.text setter 会把 delaysContentTouches 设为 false，恢复以免拖垮选区菜单
            textView.delaysContentTouches = true
            if !enableOriginalLayout {
                textView.textContainer.widthTracksTextView = true
            }
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
    
    /// 可编辑 / 只读可选中：使用系统 UITextView 排版，保证选区菜单可用；算高仍由 intrinsic 静态测量负责
    private func applySystemTextContent() {
        // 清掉 AttributedString 可能挂上的 click/press 手势，避免抢长按系统菜单
        stripAttributedStringGesturesIfNeeded()
        
        textView.isSelectable = true
        textView.delaysContentTouches = true
        textView.dataDetectorTypes = []
        textView.textContainer.widthTracksTextView = !enableOriginalLayout
        textView.showsVerticalScrollIndicator = textView.isEditable
        textView.showsHorizontalScrollIndicator = enableOriginalLayout
        
        if textView.isEditable {
            textView.isScrollEnabled = true
            textView.textContainer.maximumNumberOfLines = 0
        } else {
            // 只读可选中也保持可滚动，避免 isScrollEnabled=false 时部分系统版本不出菜单；
            // 高度仍由 ASTextView intrinsic 静态算高约束，视觉上仍随内容撑开。
            textView.isScrollEnabled = true
            textView.textContainer.maximumNumberOfLines = text?.attributes?.numberOfLines ?? 0
        }
        
        guard let attributes = text?.attributes else {
            textView.attributedText = nil
            textView.text = nil
            return
        }
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = attributes.alignment
        paragraph.lineBreakMode = Self.lineBreakMode(for: attributes)
        paragraph.lineSpacing = R.Size.LabelLineSpacing
        
        let typing: [NSAttributedString.Key: Any] = [
            .foregroundColor: attributes.color,
            .font: attributes.font,
            .paragraphStyle: paragraph
        ]
        textView.typingAttributes = typing
        // 使用系统 attributedText，切勿走 attributed.text（会 delaysContentTouches=false 并装手势）
        textView.attributedText = NSAttributedString(string: attributes.text, attributes: typing)
    }
    
    /// AttributedString 的 `attributed.text` setter 会挂精确类型的 UITap/UILongPress；
    /// 系统内建手势多为私有子类，按 exact class 移除即可。
    private func stripAttributedStringGesturesIfNeeded() {
        for gesture in textView.gestureRecognizers ?? [] {
            let cls = type(of: gesture)
            if cls == UITapGestureRecognizer.self || cls == UILongPressGestureRecognizer.self {
                textView.removeGestureRecognizer(gesture)
            }
        }
    }
    
    private static func makeMeasuringTextView() -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.textContainerInset = defaultTextContainerInset
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }
    
    private static func horizontalTextInset(in textView: UITextView) -> CGFloat {
        textView.textContainerInset.left
        + textView.textContainerInset.right
        + textView.textContainer.lineFragmentPadding * 2
    }
    
    private static func verticalTextInset(in textView: UITextView) -> CGFloat {
        textView.textContainerInset.top + textView.textContainerInset.bottom
    }
    
    private func hasExplicitHeightConstraint() -> Bool {
        if explicitConstraintConstant(for: .height, in: constraints) != nil {
            return true
        }
        if let superview, explicitConstraintConstant(for: .height, in: superview.constraints) != nil {
            return true
        }
        return hasExplicitVerticalConstraint()
    }
    
    private func hasExplicitVerticalConstraint() -> Bool {
        let relatedConstraints = constraints + (superview?.constraints ?? [])
        var hasTop = false
        var hasBottom = false
        for constraint in relatedConstraints where constraint.isActive {
            guard constraint.firstItem as AnyObject === self || constraint.secondItem as AnyObject === self else {
                continue
            }
            let attribute = constraint.firstItem as AnyObject === self ? constraint.firstAttribute : constraint.secondAttribute
            switch attribute {
            case .top:
                hasTop = true
            case .bottom:
                hasBottom = true
            default:
                break
            }
        }
        return hasTop && hasBottom
    }
    
    private func hasExplicitWidthConstraint() -> Bool {
        if explicitConstraintConstant(for: .width, in: constraints) != nil {
            return true
        }
        if let superview, explicitConstraintConstant(for: .width, in: superview.constraints) != nil {
            return true
        }
        return hasExplicitHorizontalConstraint()
    }
    
    private func hasExplicitHorizontalConstraint() -> Bool {
        if explicitConstraintConstant(for: .width, in: constraints) != nil {
            return true
        }
        let relatedConstraints = constraints + (superview?.constraints ?? [])
        var hasLeading = false
        var hasTrailing = false
        for constraint in relatedConstraints where constraint.isActive {
            guard constraint.firstItem as AnyObject === self || constraint.secondItem as AnyObject === self else {
                continue
            }
            let attribute = constraint.firstItem as AnyObject === self ? constraint.firstAttribute : constraint.secondAttribute
            switch attribute {
            case .leading, .left:
                hasLeading = true
            case .trailing, .right:
                hasTrailing = true
            default:
                break
            }
        }
        return hasLeading && hasTrailing
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
        if let width = explicitConstraintConstant(for: .width, in: constraints) {
            return width
        }
        if let superview, let width = explicitConstraintConstant(for: .width, in: superview.constraints) {
            return width
        }
        if let horizontalWidth = resolvedHorizontalConstraintWidth() {
            return horizontalWidth
        }
        if hasExplicitHorizontalConstraint(),
           bounds.width > 0,
           let superview,
           bounds.width < superview.bounds.width - 0.5 {
            return bounds.width
        }
        return 0
    }
    
    private func resolvedHorizontalConstraintWidth() -> CGFloat? {
        guard hasExplicitHorizontalConstraint() else { return nil }
        
        let relatedConstraints = constraints + (superview?.constraints ?? [])
        var leadingInfo: (ref: UIView, inset: CGFloat)?
        var trailingInfo: (ref: UIView, inset: CGFloat)?
        
        for constraint in relatedConstraints {
            if let info = horizontalInset(from: constraint, edge: .leading) {
                leadingInfo = info
            }
            if let info = horizontalInset(from: constraint, edge: .trailing) {
                trailingInfo = info
            }
        }
        
        guard let leadingInfo,
              let trailingInfo,
              leadingInfo.ref === trailingInfo.ref,
              leadingInfo.ref.bounds.width > 0 else {
            return nil
        }
        
        let width = leadingInfo.ref.bounds.width - leadingInfo.inset - trailingInfo.inset
        return width > 0 ? width : nil
    }
    
    private enum HorizontalEdge {
        case leading
        case trailing
    }
    
    private func horizontalInset(from constraint: NSLayoutConstraint, edge: HorizontalEdge) -> (ref: UIView, inset: CGFloat)? {
        guard constraint.isActive, constraint.relation == .equal, abs(constraint.multiplier - 1) < 0.001 else {
            return nil
        }
        
        let selfAttributes: [NSLayoutConstraint.Attribute]
        let refAttributes: [NSLayoutConstraint.Attribute]
        switch edge {
        case .leading:
            selfAttributes = [.leading, .left]
            refAttributes = [.leading, .left]
        case .trailing:
            selfAttributes = [.trailing, .right]
            refAttributes = [.trailing, .right]
        }
        
        if constraint.firstItem as AnyObject === self,
           selfAttributes.contains(constraint.firstAttribute),
           let ref = constraint.secondItem as? UIView,
           refAttributes.contains(constraint.secondAttribute) {
            let inset = edge == .leading ? constraint.constant : -constraint.constant
            return (ref, inset)
        }
        
        if constraint.secondItem as AnyObject === self,
           selfAttributes.contains(constraint.secondAttribute),
           let ref = constraint.firstItem as? UIView,
           refAttributes.contains(constraint.firstAttribute) {
            let inset = edge == .leading ? -constraint.constant : constraint.constant
            return (ref, inset)
        }
        
        return nil
    }
    
    private func fittingContentSize(layoutWidth: CGFloat? = nil) -> CGSize {
        let resolvedWidth = layoutWidth ?? resolvedMaxLayoutWidth()
        
        if enableOriginalLayout {
            let naturalSize = Self.contentSize(for: text, width: 0)
            let width = resolvedWidth > 0 ? resolvedWidth : naturalSize.width
            return CGSize(width: width, height: naturalSize.height)
        }
        
        if resolvedWidth == 0, hasExplicitHorizontalConstraint() {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        
        let measureWidth = resolvedWidth > 0 ? resolvedWidth : 0
        return Self.contentSize(for: text, width: measureWidth)
    }
    
    private func syncIntrinsicSizeIfNeeded() {
        let layoutWidth = resolvedMaxLayoutWidth()
        guard layoutWidth > 0, layoutWidth != lastKnownLayoutWidth else { return }
        lastKnownLayoutWidth = layoutWidth
        invalidateIntrinsicContentSize()
    }
    
    private func updateScrollState() {
        // 可编辑 / 可选中：保持 isScrollEnabled=true，避免系统选区菜单异常；
        // 高度仍由 intrinsic 算高决定，不会无故出现滚动条区域。
        if textView.isEditable || textView.isSelectable {
            if !textView.isScrollEnabled {
                textView.isScrollEnabled = true
            }
            return
        }
        
        guard bounds.width > 0, bounds.height > 0, text != nil else {
            if textView.isScrollEnabled {
                textView.isScrollEnabled = false
            }
            return
        }
        
        let wrappedContentSize = Self.contentSize(for: text, width: bounds.width)
        let naturalContentSize = Self.contentSize(for: text, width: 0)
        
        let needsHorizontalScroll: Bool
        let contentHeight: CGFloat
        if enableOriginalLayout {
            needsHorizontalScroll = naturalContentSize.width > bounds.width + 0.5
            contentHeight = naturalContentSize.height
        } else {
            needsHorizontalScroll = false
            contentHeight = wrappedContentSize.height
        }
        
        let needsVerticalScroll = hasExplicitHeightConstraint()
            && contentHeight > bounds.height + 0.5
        let shouldScroll = needsHorizontalScroll || needsVerticalScroll
        
        if textView.isScrollEnabled != shouldScroll {
            textView.isScrollEnabled = shouldScroll
        }
    }
    
    static func apply(text: ASText?,
                      to textView: UITextView,
                      onTapHighlight: ((ASText.Highlight) -> Void)? = nil,
                      onTapIcon: ((ASText.Icon) -> Void)? = nil) {
        guard let text else {
            textView.textContainer.maximumNumberOfLines = 0
            textView.attributed.text = ASAttributedString(string: "")
            return
        }
        
        if let attributes = text.attributes {
            let lineBreakMode = Self.lineBreakMode(for: attributes)
            textView.textContainer.maximumNumberOfLines = attributes.numberOfLines
            
            let asAttributes: [ASAttributedString.Attribute] = [.foreground(attributes.color),
                                                                .font(attributes.font),
                                                                .paragraph(.alignment(attributes.alignment),
                                                                           .lineBreakMode(lineBreakMode),
                                                                           .lineSpacing(R.Size.LabelLineSpacing))]
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
            
            textView.attributed.text = attributedString
        } else {
            //No text — just the icons
            textView.textContainer.maximumNumberOfLines = 0
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
            textView.attributed.text = attributedString
        }
    }
}

extension ASTextView: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        handleTextDidChange()
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        if !textView.isEditable && textView.isSelectable {
            if let textEffectsWindow = ApplicationSceneDelegate.applicationScene?.windows.last(where: { w in
                if String(describing: type(of: w)) == "UITextEffectsWindow" {
                    return true
                }
               return false
            }), let window = self.window,
                textEffectsWindow.windowLevel.rawValue <= window.windowLevel.rawValue {
                textEffectsWindow.windowLevel = UIWindow.Level(rawValue: window.windowLevel.rawValue + 1)
            }
        }
    }
    
}
