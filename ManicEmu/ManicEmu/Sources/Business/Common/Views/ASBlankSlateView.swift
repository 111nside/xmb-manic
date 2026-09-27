//
//  ASBlankSlateView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASBlankSlateView: BaseView {
    private let containerView = UIStackView()
    private let iconView = ASIconView()
    private let titleView = ASLabelView()
    private var detailView: ASLabelView? = nil
    private var buttonView: ASButtonView? = nil
    private var lastLabelLayoutWidth: CGFloat = 0
    
    var blankSlate: ASListPage.BlankSlate {
        didSet {
            updateViews()
        }
    }
    
    var didTapButton: (() -> Void)? = nil
    
    init(_ blankSlate: ASListPage.BlankSlate = .init()) {
        self.blankSlate = blankSlate
        super.init(frame: .zero)
        
        addSubview(containerView)
        containerView.axis = .vertical
        containerView.spacing = R.Size.ContentSpaceLarge
        containerView.alignment = .center
        containerView.distribution = .fill
        containerView.setContentHuggingPriority(.required, for: .horizontal)
        containerView.setContentHuggingPriority(.required, for: .vertical)
        containerView.setContentCompressionResistancePriority(.required, for: .horizontal)
        containerView.setContentCompressionResistancePriority(.required, for: .vertical)
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().inset(R.Size.ContentSpaceHuge)
            make.trailing.lessThanOrEqualToSuperview().inset(R.Size.ContentSpaceHuge)
            make.width.lessThanOrEqualToSuperview().inset(R.Size.ContentSpaceHuge)
            make.width.equalToSuperview().inset(R.Size.ContentSpaceHuge).priority(.high)
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentHuggingPriority(.required, for: .vertical)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        containerView.addArrangedSubview(iconView)
        containerView.addArrangedSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
        titleView.setContentHuggingPriority(.required, for: .horizontal)
        titleView.setContentHuggingPriority(.required, for: .vertical)
        titleView.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleView.setContentCompressionResistancePriority(.required, for: .vertical)
        containerView.setCustomSpacing(R.Size.ContentSpaceExtraSmall,
                                       after: titleView)
        
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLabelLayoutWidthsIfNeeded()
    }
    
    private func updateLabelLayoutWidthsIfNeeded() {
        let labelWidth = bounds.width - R.Size.ContentSpaceHuge * 2
        guard labelWidth > 0, labelWidth != lastLabelLayoutWidth else { return }
        lastLabelLayoutWidth = labelWidth
        titleView.preferredMaxLayoutWidth = labelWidth
        detailView?.preferredMaxLayoutWidth = labelWidth
    }
    
    private func updateViews() {
        lastLabelLayoutWidth = 0
        
        if let detailView {
            containerView.removeArrangedSubview(detailView)
            detailView.removeFromSuperview()
        }
        
        if let buttonView {
            containerView.removeArrangedSubview(buttonView)
            buttonView.removeFromSuperview()
        }
        
        
        if case .autoLayout = blankSlate.iconLayout { } else {
            iconView.snp.remakeConstraints { make in
                switch blankSlate.iconLayout {
                case .fixedHeight(let height):
                    make.width.equalTo(height)
                case .fixedWidth(let width):
                    make.width.equalTo(width)
                case .fixedSize(let size):
                    make.size.equalTo(size)
                case .autoLayout:
                    break
                }
            }
        }
        
        iconView.icon = blankSlate.icon
        
        var text = ASText.extraLargeText(blankSlate.title,
                                         numberOfLines: 0)
        text.attributes?.alignment = .center
        titleView.text = text
        
        if let detail = blankSlate.detail {
            var text = ASText.mediumText(detail,
                                         color: R.Color.LabelSecondary,
                                         numberOfLines: 0)
            text.attributes?.alignment = .center
            let view = ASLabelView(text: text)
            containerView.addArrangedSubview(view)
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentHuggingPriority(.required, for: .vertical)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .vertical)
            detailView = view
        }
        
        if var button = blankSlate.button {
            button.sizeStyle = .fixHeight(R.Size.ButtonLarge,
                                          insets: UIEdgeInsets(horizontal: R.Size.ContentSpaceMedium*2,
                                                               vertical: R.Size.ContentSpaceExtraSmall*2))
            let view = ASButtonView(button)
            view.setContentHuggingPriority(.required, for: .horizontal)
            view.setContentHuggingPriority(.required, for: .vertical)
            view.setContentCompressionResistancePriority(.required, for: .horizontal)
            view.setContentCompressionResistancePriority(.required, for: .vertical)
            containerView.addArrangedSubview(view)
            view.didTapButton = { [weak self] in
                self?.didTapButton?()
            }
            buttonView = view
        }
    }
}
