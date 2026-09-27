//
//  ASSymbolsButtonView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/15.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASSymbolsButtonView: UIVisualEffectView {
    
    private struct LayoutMetrics {
        let insets: UIEdgeInsets
        let itemSide: CGFloat
    }
    
    private let containerView = UIStackView()
    private var iconViews = [ASIconView]()
    private let defaultHeight = R.Size.ButtonSmall
    var containerInsets = UIEdgeInsets(
        top: R.Size.ContentSpaceTiny + 1,
        left: R.Size.ContentSpaceExtraSmall,
        bottom: R.Size.ContentSpaceTiny + 1,
        right: R.Size.ContentSpaceExtraSmall
    ) {
        didSet {
            updateViews()
        }
    }
    private var lastLayoutToken = 0
    
    var icons: [ASIcon] {
        didSet {
            updateViews()
        }
    }
    
    var didTapButton: ((_ index: Int) -> Void)? = nil
    
    init(icons: [ASIcon], backgroundColor: UIColor = R.Color.BackgroundSecondary) {
        self.icons = icons
        super.init(effect: nil)
        
        masksToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        
        containerView.axis = .horizontal
        containerView.alignment = .center
        containerView.distribution = .fill
        containerView.spacing = R.Size.ContentSpaceMedium
        
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(containerInsets)
        }
        
        if #available(iOS 26.0, tvOS 26.0, *) {
            if effect == nil {
                let glassEffect = UIGlassEffect(style: .clear)
                glassEffect.isInteractive = true
                effect = glassEffect
            }
            (effect as? UIGlassEffect)?.tintColor = backgroundColor.withAlphaComponent(0.2)
        } else {
            self.backgroundColor = backgroundColor
        }
        
        updateViews()
    }
    
    convenience init(_ icons: ASIcon...) {
        self.init(icons: icons)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        guard !icons.isEmpty else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        
        let metrics = layoutMetrics()
        guard metrics.itemSide > 0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        
        let width = containerWidth(for: metrics)
        let height = containerHeight(for: metrics)
        return CGSize(width: width, height: height)
    }
    
    override func updateConstraints() {
        applyLayoutIfNeeded()
        super.updateConstraints()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyLayoutIfNeeded()
        layerCornerRadius = bounds.height / 2
    }
    
    private func updateViews() {
        containerView.removeAllArrangedSubviews()
        
        for (index, icon) in icons.enumerated() {
            let iconView = ensureIconView(at: index)
            iconView.icon = icon.updateCornerStyle(.circle)
            rebindTapGesture(for: iconView, at: index)
            containerView.addArrangedSubview(iconView)
        }
        
        lastLayoutToken = 0
        invalidateIntrinsicContentSize()
        setNeedsUpdateConstraints()
        setNeedsLayout()
        superview?.setNeedsLayout()
    }
    
    private func ensureIconView(at index: Int) -> ASIconView {
        if index < iconViews.count {
            return iconViews[index]
        }
        
        let iconView = ASIconView()
        iconView.enablePressEffect = true
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentHuggingPriority(.required, for: .vertical)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .vertical)
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(0)
        }
        iconViews.append(iconView)
        return iconView
    }
    
    private func rebindTapGesture(for iconView: ASIconView, at index: Int) {
        iconView.gestureRecognizers?
            .filter { $0 is UITapGestureRecognizer }
            .forEach { $0.removeFromView() }
        
        let itemIndex = index
        iconView.addTapGesture { [weak self] _ in
            UIDevice.generateHaptic()
            self?.didTapButton?(itemIndex)
        }
        iconView.isFocusable = true
        iconView.onFocusConfirm = { [weak self] in
            UIDevice.generateHaptic()
            self?.didTapButton?(itemIndex)
            return true
        }
    }
    
    private func applyLayoutIfNeeded() {
        guard !icons.isEmpty else { return }
        
        let token = layoutToken()
        guard token != lastLayoutToken else { return }
        lastLayoutToken = token
        
        let metrics = layoutMetrics()
        let activeIconViews = iconViews.prefix(icons.count)
        
        containerView.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(metrics.insets)
        }
        
        let itemSide = metrics.itemSide
        for iconView in activeIconViews {
            iconView.snp.updateConstraints { make in
                make.width.height.equalTo(itemSide)
            }
        }
    }
    
    /// 默认由 icon 尺寸 + 边距推导容器大小；仅当存在外部宽高约束时才反过来压缩 icon。
    private func layoutMetrics() -> LayoutMetrics {
        let baseInsets = effectiveContainerInsets
        let count = icons.count
        guard count > 0 else {
            return LayoutMetrics(insets: baseInsets, itemSide: 0)
        }
        
        let externalHeight = resolvedExternalHeight()
        let externalWidth = externalConstraintValue(for: .width)
        let containerHeight = max(externalHeight ?? defaultHeight, 0)
        
        guard containerHeight > 0 else {
            return LayoutMetrics(insets: baseInsets, itemSide: 0)
        }
        
        if count == 1 {
            let containerSide: CGFloat
            if shouldForceSquareContainer {
                containerSide = containerHeight
            } else if hasExternalHeightConstraint {
                containerSide = containerHeight
            } else if externalWidth != nil {
                containerSide = externalWidth!
            } else {
                containerSide = defaultHeight
            }
            
            let inset = baseInsets.top
            let itemSide = max(0, containerSide - inset * 2)
            return LayoutMetrics(insets: baseInsets, itemSide: itemSide)
        }
        
        let minInsetX = baseInsets.left
        let minInsetY = baseInsets.top
        let spacing = containerView.spacing
        let itemSideFromHeight = max(0, containerHeight - 2 * minInsetY)
        
        guard let externalWidth, externalWidth > 0 else {
            return LayoutMetrics(insets: baseInsets, itemSide: itemSideFromHeight)
        }
        
        let itemCount = CGFloat(count)
        let itemSideFromWidth = (externalWidth - 2 * minInsetX - (itemCount - 1) * spacing) / itemCount
        let itemSide = max(0, min(itemSideFromHeight, itemSideFromWidth))
        let contentWidth = contentWidth(itemSide: itemSide, count: count)
        let insetX = max(minInsetX, (externalWidth - contentWidth) / 2)
        let insetY = max(minInsetY, (containerHeight - itemSide) / 2)
        
        return LayoutMetrics(
            insets: UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX),
            itemSide: itemSide
        )
    }
    
    private func containerWidth(for metrics: LayoutMetrics) -> CGFloat {
        if icons.count == 1 {
            if shouldForceSquareContainer {
                return metrics.itemSide + metrics.insets.left + metrics.insets.right
            }
            if externalConstraintValue(for: .width) != nil {
                return externalConstraintValue(for: .width)!
            }
            return metrics.itemSide + metrics.insets.left + metrics.insets.right
        }
        
        if let externalWidth = externalConstraintValue(for: .width), externalWidth > 0 {
            return externalWidth
        }
        
        return contentWidth(itemSide: metrics.itemSide, count: icons.count)
            + metrics.insets.left
            + metrics.insets.right
    }
    
    private func containerHeight(for metrics: LayoutMetrics) -> CGFloat {
        if hasExternalHeightConstraint {
            return UIView.noIntrinsicMetric
        }
        
        return metrics.itemSide + metrics.insets.top + metrics.insets.bottom
    }
    
    private func contentWidth(itemSide: CGFloat, count: Int) -> CGFloat {
        let spacing = containerView.spacing
        return CGFloat(count) * itemSide + CGFloat(max(count - 1, 0)) * spacing
    }
    
    private func layoutToken() -> Int {
        var hasher = Hasher()
        hasher.combine(icons.count)
        hasher.combine(containerInsets.top)
        hasher.combine(containerInsets.left)
        hasher.combine(containerInsets.bottom)
        hasher.combine(containerInsets.right)
        hasher.combine(resolvedExternalHeight() ?? -1)
        hasher.combine(externalConstraintValue(for: .width) ?? -1)
        hasher.combine(hasVerticalFillConstraint)
        hasher.combine(defaultHeight)
        return hasher.finalize()
    }
    
    /// Single icon + external height only: keep the container square (width == height).
    private var shouldForceSquareContainer: Bool {
        icons.count == 1 && hasExternalHeightConstraint && !hasExternalWidthConstraint
    }
    
    private var hasExternalHeightConstraint: Bool {
        externalConstraintValue(for: .height) != nil || hasVerticalFillConstraint
    }
    
    private var hasExternalWidthConstraint: Bool {
        externalConstraintValue(for: .width) != nil || hasHorizontalFillConstraint
    }
    
    /// 父视图通过 top + bottom 撑满高度（如 ASListToolView）。
    private var hasVerticalFillConstraint: Bool {
        guard let superview else { return false }
        return hasPinnedEdge(.top, to: superview, in: superview.constraints)
            && hasPinnedEdge(.bottom, to: superview, in: superview.constraints)
    }
    
    /// 父视图通过 leading + trailing 撑满宽度。
    private var hasHorizontalFillConstraint: Bool {
        guard let superview else { return false }
        return hasPinnedEdge(.leading, to: superview, in: superview.constraints)
            && hasPinnedEdge(.trailing, to: superview, in: superview.constraints)
    }
    
    private func resolvedExternalHeight() -> CGFloat? {
        if let height = externalConstraintValue(for: .height) {
            return height
        }
        guard hasVerticalFillConstraint else { return nil }
        if bounds.height > 0 { return bounds.height }
        if let superview, superview.bounds.height > 0 { return superview.bounds.height }
        return nil
    }
    
    private func hasPinnedEdge(
        _ edge: NSLayoutConstraint.Attribute,
        to target: UIView,
        in constraints: [NSLayoutConstraint]
    ) -> Bool {
        let pairedEdge = edge
        for constraint in constraints where constraint.isActive && constraint.relation == .equal {
            guard !constraint.isSystemLayoutConstraint else { continue }
            
            if constraint.firstItem as AnyObject === self,
               constraint.firstAttribute == pairedEdge,
               constraint.secondItem as AnyObject === target {
                return true
            }
            if constraint.secondItem as AnyObject === self,
               constraint.secondAttribute == pairedEdge,
               constraint.firstItem as AnyObject === target {
                return true
            }
        }
        return false
    }
    
    /// Single icon uses the smallest configured inset on all four edges so the container can stay square.
    private var effectiveContainerInsets: UIEdgeInsets {
        guard icons.count == 1 else {
            let minInsetX = min(containerInsets.left, containerInsets.right)
            let minInsetY = min(containerInsets.top, containerInsets.bottom)
            return UIEdgeInsets(top: minInsetY, left: minInsetX, bottom: minInsetY, right: minInsetX)
        }
        
        let inset = min(containerInsets.top,
                        containerInsets.left,
                        containerInsets.bottom,
                        containerInsets.right)
        return UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
    }
    
    /// 只读取父视图上用户设置的 equal 约束；忽略 self 上的 Encapsulated Layout 等系统约束。
    private func externalConstraintValue(for attribute: NSLayoutConstraint.Attribute) -> CGFloat? {
        guard let superview else { return nil }
        return explicitUserConstraintConstant(for: attribute, in: superview.constraints)
    }
    
    private func explicitUserConstraintConstant(
        for attribute: NSLayoutConstraint.Attribute,
        in constraints: [NSLayoutConstraint]
    ) -> CGFloat? {
        for constraint in constraints where constraint.isActive && constraint.relation == .equal {
            guard !constraint.isSystemLayoutConstraint else { continue }
            
            if constraint.firstItem as AnyObject === self,
               constraint.firstAttribute == attribute,
               constraint.secondItem == nil {
                return constraint.constant
            }
        }
        return nil
    }
    
    private func explicitConstraintConstant(
        for attribute: NSLayoutConstraint.Attribute,
        in constraints: [NSLayoutConstraint]
    ) -> CGFloat? {
        explicitUserConstraintConstant(for: attribute, in: constraints)
    }
}

private extension NSLayoutConstraint {
    var isSystemLayoutConstraint: Bool {
        let identifier = identifier ?? ""
        if identifier.contains("Encapsulated") { return true }
        if identifier.contains("Temporary") { return true }
        if identifier.hasPrefix("UISV-") { return true }
        return false
    }
}
