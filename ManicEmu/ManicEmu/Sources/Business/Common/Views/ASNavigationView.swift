//
//  ASNavigationView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/15.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASNavigationView: BaseView {
    
    private let containerView = UIStackView()
    private let flexSpacer = UIView()
    
    //normal state
    private let titleIconView = ASIconView()
    private let titleLabelView = ASLabelView()
    private let detailLabelView = ASLabelView()
    let toolButtonView = ASSymbolsButtonView()
    private let closeButtonView = ASButtonView(.smallCloseButton())
    
    //edit state
    private let cancelButton = ASButtonView(.small(title: R.string.localizable.cancelTitle(),
                                                   titleColor: R.Color.LabelSecondary,
                                                   sizeStyle: .fixHeight(R.Size.ButtonSmall,
                                                                         insets: .init(horizontal: R.Size.ContentSpaceSmall * 2,
                                                                                       vertical: R.Size.ContentSpaceExtraSmall * 2))))
    private let editButton = ASButtonView(.small(title: "",
                                                 titleColor: R.Color.Red,
                                                 sizeStyle: .fixHeight(R.Size.ButtonSmall,
                                                                       insets: .init(horizontal: R.Size.ContentSpaceSmall * 2,
                                                                                     vertical: R.Size.ContentSpaceExtraSmall * 2))))
    
    var didTapClose: (() -> Void)? = nil
    var didTapTools: ((_ index: Int) -> Void)? = nil
    var didTapTitle: (() -> Void)? = nil {
        didSet {
            titleLabelView.enablePressEffect = didTapTitle != nil
            titleIconView.enablePressEffect = didTapTitle != nil
            let confirm: (() -> Bool)? = didTapTitle == nil ? nil : { [weak self] in
                guard let didTapTitle = self?.didTapTitle else { return false }
                UIDevice.generateHaptic()
                didTapTitle()
                return true
            }
            titleLabelView.onFocusConfirm = confirm
            titleIconView.onFocusConfirm = confirm
        }
    }
    var didTapCancel: (() -> Void)? = nil
    var didTapEdit: (() -> Void)? = nil
    
    var navigation: ASListPage.Navigation? = nil {
        didSet {
            updateViews()
        }
    }
    var titleIcon: ASIcon? {
        get { navigation?.titleIcon }
        set { navigation?.titleIcon = newValue }
    }
    var titleText: ASText? {
        get { navigation?.title }
        set { navigation?.title = newValue }
    }
    var detailText: ASText? {
        get { navigation?.detail }
        set { navigation?.detail = newValue }
    }
    var toolButtons: [ASIcon] {
        get { navigation?.tools ?? [] }
        set { navigation?.tools = newValue }
    }
    var editTitle: String? {
        get { navigation?.edit }
        set { navigation?.edit = newValue }
    }
    
    var state: ASListPage.Navigation.State {
        get { navigation?.state ?? .normal }
        set { navigation?.state = newValue }
    }
    
    init(_ navigation: ASListPage.Navigation? = nil) {
        self.navigation = navigation
        super.init(frame: .zero)
        
        backgroundColor = navigation?.backgroundColor
        
        containerView.axis = .horizontal
        containerView.alignment = .center
        containerView.distribution = .fill
        containerView.spacing = 0
        
        flexSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        flexSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        titleLabelView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabelView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        [titleIconView, toolButtonView, closeButtonView, cancelButton, editButton].forEach {
            $0.setContentHuggingPriority(.required, for: .horizontal)
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        
        closeButtonView.didTapButton = { [weak self] in
            if let didTapClose = self?.didTapClose {
                UIDevice.generateHaptic()
                didTapClose()
            }
        }
        
        toolButtonView.didTapButton = { [weak self] index in
            self?.didTapTools?(index)
        }
        
        cancelButton.didTapButton = { [weak self] in
            if let didTapCancel = self?.didTapCancel {
                UIDevice.generateHaptic()
                didTapCancel()
            }
        }
        
        editButton.didTapButton = { [weak self] in
            if let didTapEdit = self?.didTapEdit {
                UIDevice.generateHaptic()
                didTapEdit()
            }
        }
        
        titleIconView.addTapGesture { [weak self] _ in
            if let didTapTitle = self?.didTapTitle {
                UIDevice.generateHaptic()
                didTapTitle()
            }
        }
        
        titleLabelView.didTapLabelView = { [weak self] _ in
            if let didTapTitle = self?.didTapTitle {
                UIDevice.generateHaptic()
                didTapTitle()
            }
        }
        
        updateViews()
        
        titleIconView.snp.makeConstraints { make in
            make.size.equalTo(CGSize(R.Size.ButtonExtraExtraSmall))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateViews() {
        containerView.removeAllArrangedSubviews()
        detailLabelView.removeFromSuperview()
        toolButtonView.snp.removeConstraints()
        
        backgroundColor = navigation?.backgroundColor
        
        if state == .normal {
            var titleOnly = true
            if let titleIcon {
                titleOnly = false
                titleIconView.icon = titleIcon
                containerView.addArrangedSubview(titleIconView)
            }
            
            if let titleText {
                titleLabelView.text = titleText
                containerView.addArrangedSubview(titleLabelView)
            }
            
            containerView.addArrangedSubview(flexSpacer)
            
            if toolButtons.count > 0 {
                titleOnly = false
                toolButtonView.icons = toolButtons
                if #available(iOS 26.0, tvOS 26.0, *) {
                    
                } else if let color = navigation?.toolsBackground {
                    toolButtonView.backgroundColor = color
                }
                containerView.addArrangedSubview(toolButtonView)
                toolButtonView.snp.makeConstraints { make in
                    make.height.equalTo(R.Size.ButtonSmall)
                }
            }
            
            if navigation?.enableClose ?? false {
                titleOnly = false
                containerView.addArrangedSubview(closeButtonView)
                if let color = navigation?.closeBackground {
                    closeButtonView.setBackgroundColor(color)
                }
            }
            
            if titleIcon != nil, titleText != nil {
                containerView.setCustomSpacing(R.Size.ContentSpaceExtraSmall, after: titleIconView)
            }
            if toolButtons.count > 0 {
                containerView.setCustomSpacing(R.Size.ContentSpaceSmall, after: toolButtonView)
            }
            
            if let detailText {
                titleOnly = false
                detailLabelView.text = detailText
                insertSubview(detailLabelView, belowSubview: containerView)
                detailLabelView.snp.remakeConstraints { make in
                    make.leading.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                    if let _ = toolButtonView.superview {
                        make.trailing.equalTo(toolButtonView.snp.leading).offset(-R.Size.ContentSpaceMedium)
                    } else if let _ = closeButtonView.superview {
                        make.trailing.equalTo(closeButtonView.snp.leading).offset(-R.Size.ContentSpaceMedium)
                    } else {
                        make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                    }
                    make.bottom.equalToSuperview()
                }
            }
            
            if titleOnly {
                containerView.removeArrangedSubview(flexSpacer)
            }
        } else {
            containerView.addArrangedSubview(cancelButton)
            containerView.addArrangedSubview(flexSpacer)
            
            if let editTitle {
                editButton.setTitleString(editTitle)
                containerView.addArrangedSubview(editButton)
            }
        }
    }
}
