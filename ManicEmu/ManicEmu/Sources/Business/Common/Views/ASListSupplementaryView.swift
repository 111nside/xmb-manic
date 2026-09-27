//
//  ASListSupplementaryView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/16.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASListSupplementaryReusableView: UICollectionReusableView {
    private let itemView = ASListSupplementaryView()
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        addSubview(itemView)
        itemView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(supplementary: ASListPage.Supplementary? = nil) {
        itemView.supplementary = supplementary
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        guard let attributes = layoutAttributes.copy() as? UICollectionViewLayoutAttributes else {
            return layoutAttributes
        }
        
        let contentWidth = attributes.size.width - R.Size.ContentSpaceExtraSmall * 2
        itemView.prepareLabelLayout(for: contentWidth)
        
        if let supplementary = itemView.supplementary, case .texts = supplementary, contentWidth > 0 {
            let height = ASListSupplementaryView.calculateHeight(
                width: contentWidth,
                supplementary: supplementary
            )
            var frame = attributes.frame
            frame.size.height = height
            attributes.frame = frame
        }
        
        return attributes
    }
    
}

class ASListSupplementaryView: BaseView {
    
    private let containerView = UIStackView()
    private let leadingButtonStack = UIStackView()
    private let flexSpacer = UIView()
    private var labelViews = [ASLabelView]()
    private var buttonViews = [ASButtonView]()
    private var customContentView: UIView?
    private var lastLayoutWidth: CGFloat = 0
    private let spacing = R.Size.ContentSpaceSmall
    private let contentInset = UIEdgeInsets(horizontal: 0, vertical: R.Size.ContentSpaceSmall)
    
    var supplementary: ASListPage.Supplementary? {
        didSet {
            updateViews()
        }
    }
    
    /// CollectionView self-sizing 时由 reusable view 传入可用文本宽度。
    func prepareLabelLayout(for contentWidth: CGFloat) {
        guard contentWidth > 0 else { return }
        applyLabelLayoutWidth(contentWidth)
    }
    
    var didTapButton: ((_ index: Int) -> Void)? = nil
    
    init(supplementary: ASListPage.Supplementary? = nil) {
        self.supplementary = supplementary
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        computeIntrinsicContentSize()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let supplementary, case .texts = supplementary {
            updateLabelLayoutWidthsIfNeeded()
        }
    }
    
    static func calculateHeight(width: CGFloat, supplementary: ASListPage.Supplementary) -> CGFloat {
        switch supplementary {
        case .texts:
            let height = measureTextContentSize(for: width, supplementary: supplementary).height
            return max(height, R.Size.SupplementaryItemHeight)
        case .buttons:
            return R.Size.SupplementaryItemHeight
        case .custom(_, _, let height):
            return height
        }
    }
    
    private func setupViews() {
        flexSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        flexSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        addSubview(containerView)
        applyContainerViewConstraints()
        
        updateViews()
    }
    
    private func applyContainerViewConstraints() {
        containerView.isHidden = false
        containerView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(contentInset.top)
            make.bottom.equalToSuperview().inset(contentInset.bottom)
        }
    }
    
    private func collapseContainerViewLayout() {
        containerView.isHidden = true
        containerView.snp.remakeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(0)
        }
    }
    
    private func removeCustomContentViewIfNeeded() {
        customContentView?.removeFromSuperview()
        customContentView = nil
    }
    
    private func updateViews() {
        removeCustomContentViewIfNeeded()
        applyContainerViewConstraints()
        containerView.removeAllArrangedSubviews()
        leadingButtonStack.removeAllArrangedSubviews()
        labelViews.removeAll()
        buttonViews.removeAll()
        lastLayoutWidth = 0
        
        guard let supplementary else { return }
        switch supplementary {
        case .texts:
            updateTextViews()
        case .buttons:
            updateButtonViews()
        case .custom:
            updateCustomViews()
        }
        
        invalidateIntrinsicContentSize()
    }
    
    private func updateTextViews() {
        guard let supplementary, case .texts(let texts, _) = supplementary else { return }
        
        containerView.axis = .vertical
        containerView.alignment = .fill
        containerView.distribution = .fill
        containerView.spacing = 0
        
        for text in texts {
            let labelView = ASLabelView(text: text)
            labelViews.append(labelView)
            containerView.addArrangedSubview(labelView)
        }
        
        if let contentWidth = resolvedContentLayoutWidth() {
            applyLabelLayoutWidth(contentWidth)
        }
    }
    
    private func updateButtonViews() {
        guard let supplementary, case .buttons(let buttons, _) = supplementary else { return }
        
        containerView.axis = .horizontal
        containerView.alignment = .center
        containerView.distribution = .fill
        containerView.spacing = 0
        
        leadingButtonStack.axis = .horizontal
        leadingButtonStack.alignment = .center
        leadingButtonStack.distribution = .fill
        leadingButtonStack.spacing = spacing
        
        guard !buttons.isEmpty else { return }
        
        if buttons.count == 1 {
            let buttonView = makeButtonView(buttons[0], index: 0)
            containerView.addArrangedSubview(buttonView)
            containerView.addArrangedSubview(flexSpacer)
            return
        }
        
        for index in 0..<(buttons.count - 1) {
            leadingButtonStack.addArrangedSubview(makeButtonView(buttons[index], index: index))
        }
        
        let trailingButtonView = makeButtonView(buttons[buttons.count - 1], index: buttons.count - 1)
        containerView.addArrangedSubview(leadingButtonStack)
        containerView.addArrangedSubview(flexSpacer)
        containerView.addArrangedSubview(trailingButtonView)
    }
    
    private func updateCustomViews() {
        guard let supplementary, case .custom(let view, _, _) = supplementary else { return }
        
        collapseContainerViewLayout()
        
        view.removeFromSuperview()
        addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        customContentView = view
    }
    
    private func makeButtonView(_ button: ASButton, index: Int) -> ASButtonView {
        let buttonView = ASButtonView(button)
        buttonView.setContentHuggingPriority(.required, for: .horizontal)
        buttonView.setContentHuggingPriority(.required, for: .vertical)
        buttonView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        buttonView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        let buttonIndex = index
        buttonView.didTapButton = { [weak self] in
            self?.didTapButton?(buttonIndex)
        }
        
        buttonViews.append(buttonView)
        return buttonView
    }
    
    private func updateLabelLayoutWidthsIfNeeded() {
        guard let contentWidth = resolvedContentLayoutWidth() else { return }
        applyLabelLayoutWidth(contentWidth)
    }
    
    private func applyLabelLayoutWidth(_ width: CGFloat) {
        guard width > 0, width != lastLayoutWidth else { return }
        lastLayoutWidth = width
        labelViews.forEach { $0.preferredMaxLayoutWidth = width }
        invalidateIntrinsicContentSize()
    }
    
    private func resolvedContentLayoutWidth() -> CGFloat? {
        if bounds.width > 0 { return bounds.width }
        if let width = resolvedExplicitDimension(.width) { return width }
        
        var ancestor: UIView? = superview
        while let view = ancestor {
            if view.bounds.width > 0 {
                if view is ASListSupplementaryReusableView {
                    return view.bounds.width - R.Size.ContentSpaceExtraSmall * 2
                }
                return view.bounds.width
            }
            ancestor = view.superview
        }
        return nil
    }
    
    private func computeIntrinsicContentSize() -> CGSize {
        guard let supplementary else { return .zero }
        switch supplementary {
        case .texts:
            return computeTextIntrinsicContentSize()
        case .buttons:
            return computeButtonIntrinsicContentSize()
        case .custom(_, _, let height):
            return CGSize(width: UIView.noIntrinsicMetric, height: height)
        }
    }
    
    private func computeTextIntrinsicContentSize() -> CGSize {
        guard let supplementary, case .texts(let texts, _) = supplementary else { return .zero }
        
        guard !texts.isEmpty else {
            return CGSize(width: 0, height: 0)
        }
        
        let explicitWidth = resolvedExplicitDimension(.width)
        let explicitHeight = resolvedExplicitDimension(.height)
        let layoutWidth = resolvedContentLayoutWidth() ?? explicitWidth
        
        let hasFixedWidth = (layoutWidth ?? 0) > 0
        let hasFixedHeight = (explicitHeight ?? 0) > 0
        
        if hasFixedWidth && hasFixedHeight {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        
        if hasFixedWidth {
            let height = Self.measureTextContentSize(for: layoutWidth!, supplementary: supplementary).height
            return CGSize(width: UIView.noIntrinsicMetric, height: height)
        }
        
        if hasFixedHeight {
            let size = Self.measureTextContentSize(for: nil, supplementary: supplementary)
            return CGSize(width: size.width, height: UIView.noIntrinsicMetric)
        }
        
        return Self.measureTextContentSize(for: nil, supplementary: supplementary)
    }
    
    private func computeButtonIntrinsicContentSize() -> CGSize {
        guard let supplementary, case .buttons(let buttons, _) = supplementary else { return .zero }
        
        guard !buttons.isEmpty else {
            return CGSize(width: 0, height: 0)
        }
        
        let explicitWidth = resolvedExplicitDimension(.width)
        let explicitHeight = resolvedExplicitDimension(.height)
        let layoutWidth = resolvedContentLayoutWidth() ?? explicitWidth
        
        let hasFixedWidth = (layoutWidth ?? 0) > 0
        let hasFixedHeight = (explicitHeight ?? 0) > 0
        
        if hasFixedWidth && hasFixedHeight {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        
        if hasFixedWidth {
            let height = measureButtonContentSize(for: layoutWidth!).height
            return CGSize(width: UIView.noIntrinsicMetric, height: height)
        }
        
        if hasFixedHeight {
            let size = measureButtonContentSize(for: nil)
            return CGSize(width: size.width, height: UIView.noIntrinsicMetric)
        }
        
        return measureButtonContentSize(for: nil)
    }
    
    private static func measureTextContentSize(for width: CGFloat?, supplementary: ASListPage.Supplementary?) -> CGSize {
        guard let supplementary, case .texts(let texts, _) = supplementary else { return .zero }
        
        guard !texts.isEmpty else {
            return CGSize(width: 0, height: 0)
        }
        
        let fittingWidth = width ?? CGFloat.greatestFiniteMagnitude
        var totalHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for (index, text) in texts.enumerated() {
            if text.attributes?.numberOfLines ?? 1 == 1 {
                //If single-line mode is enabled (single-line is the default), only the height of one line will be returned.
                totalHeight += labelContentSize(for: text, width: CGFloat.greatestFiniteMagnitude).height
            } else {
                let size = labelContentSize(for: text, width: fittingWidth)
                maxWidth = max(maxWidth, size.width)
                totalHeight += size.height
            }
            
            if index > 0 {
                totalHeight += R.Size.ContentSpaceSmall
            }
        }
        
        //add contentInsets vertical
        totalHeight += R.Size.ContentSpaceSmall
        
        if let width {
            return CGSize(width: width, height: totalHeight)
        }
        return CGSize(width: maxWidth, height: totalHeight)
    }
    
    private func measureButtonContentSize(for width: CGFloat?) -> CGSize {
        guard let supplementary, case .buttons(let buttons, _) = supplementary else { return .zero }
        
        guard !buttons.isEmpty else {
            return CGSize(width: 0, height: 0)
        }
        
        let sizes = buttonSizes()
        var rowHeight = sizes.map(\.height).max() ?? 0
        let naturalWidth = buttonRowNaturalWidth(sizes: sizes)
        
        //add contentInsets vertical
        rowHeight += R.Size.ContentSpaceSmall
        
        if let width {
            return CGSize(width: width, height: rowHeight)
        }
        return CGSize(width: naturalWidth, height: rowHeight)
    }
    
    private func buttonSizes() -> [CGSize] {
        guard let supplementary, case .buttons(let buttons, _) = supplementary else { return [] }
        
        if buttonViews.count == buttons.count {
            return buttonViews.map { $0.intrinsicContentSize }
        }
        return buttons.map { ASButtonView($0).intrinsicContentSize }
    }
    
    private func buttonRowNaturalWidth(sizes: [CGSize]) -> CGFloat {
        guard !sizes.isEmpty else { return 0 }
        if sizes.count == 1 {
            return sizes[0].width
        }
        
        let leadingWidth = sizes.dropLast().map(\.width).reduce(0, +)
        let leadingSpacing = CGFloat(max(sizes.count - 2, 0)) * spacing
        return leadingWidth + leadingSpacing + sizes.last!.width
    }
    
    private static func labelContentSize(for text: ASText, width: CGFloat) -> CGSize {
        let label = UILabel()
        ASLabelView.apply(text: text, to: label)
        if width != CGFloat.greatestFiniteMagnitude {
            label.preferredMaxLayoutWidth = width
        }
        let size = label.sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
    
    private func resolvedExplicitDimension(_ attribute: NSLayoutConstraint.Attribute) -> CGFloat? {
        if attribute == .width, bounds.width > 0 {
            return bounds.width
        }
        if attribute == .height, bounds.height > 0 {
            return bounds.height
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
}
