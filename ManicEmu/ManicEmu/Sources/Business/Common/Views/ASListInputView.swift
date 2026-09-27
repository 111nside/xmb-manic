//
//  ASListInputView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/16.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASListInputCollectionCell: UICollectionViewCell {
    private let itemView = ASListInputView()
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        addSubview(itemView)
        itemView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFirstResponder: Bool {
        itemView.isFirstResponder
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        itemView.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        itemView.resignFirstResponder()
    }
    
    func setData(input: ASInput) {
        itemView.input = input
    }
    
    func setActionCallback(_ callback: ((ASInput.Action) -> Void)? = nil) {
        if let callback {
            itemView.didInputChange = { text in
                callback(.textChange(text))
            }
            itemView.didTapClear = {
                callback(.tapClear)
            }
            itemView.didTapReturn = { text in
                callback(.tapReturn(text))
            }
        } else {
            itemView.didInputChange = nil
            itemView.didTapClear = nil
            itemView.didTapReturn = nil
        }
    }
    
}

class ASListInputView: BaseView {
    private var leftIconButton: ASButtonView? = nil
    private let textFiled = UITextField()
    private let clearIconButton: ASButtonView
    
    
    var input: ASInput {
        didSet {
            updateViews()
        }
    }
    
    var text: String? {
        textFiled.text
    }
    
    var didInputChange: ((String?) -> Void)? = nil
    var didTapClear: (() -> Void)? = nil
    var didTapReturn: ((String?) -> Void)? = nil
    
    init(_ input: ASInput = .init()) {
        clearIconButton = ASButtonView(.iconOnly(icon: .symbolImage(R.image.close_iconSymbols()),
                                                 iconSize: CGSize(input.textAttributes.font.pointSize),
                                                 background: R.Color.BackgroundSecondary,
                                                 insets: UIEdgeInsets(inset: R.Size.ContentSpaceTiny)))
        self.input = input
        super.init(frame: .zero)
        isFocusable = true
        onFocusConfirm = { [weak self] in
            self?.becomeFirstResponder()
            return true
        }
        
        backgroundColor = R.Color.InputBox
        
        masksToBounds = true
        layerBorderWidth = R.Size.Border
        
        addSubview(textFiled)
        textFiled.onChange { [weak self] text in
            guard let self else { return }
            self.didInputChange?(text)
        }
        
        textFiled.onEditingBegan { [weak self] in
            self?.updateClearButtonVisible()
        }
        
        textFiled.onEditingEnded { [weak self] in
            self?.updateClearButtonVisible()
        }
        
        textFiled.onReturnKeyPress { [weak self] in
            self?.updateClearButtonVisible()
            self?.didTapReturn?(self?.textFiled.text)
        }
        
        clearIconButton.didTapButton = { [weak self] in
            self?.textFiled.text = nil
            self?.didTapClear?()
        }
        
        if input.clearButtonMode != .never {
            addSubview(clearIconButton)
        }
        updateClearButtonVisible()
        
        updateViews()
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if case .circle = input.cornerStyle {
            layerCornerRadius = height/2
        } else if case .radius(let radius) = input.cornerStyle {
            layerCornerRadius = radius
        }
        layerBorderColor = R.Color.Border
    }
    
    override var isFirstResponder: Bool {
        textFiled.isFirstResponder
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        textFiled.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        textFiled.resignFirstResponder()
    }
    
    private func updateClearButtonVisible() {
        switch input.clearButtonMode {
        case .never:
            clearIconButton.isHidden = true
        case .whileEditing:
            clearIconButton.isHidden = !textFiled.isEditing
        case .unlessEditing:
            clearIconButton.isHidden = textFiled.isEditing
        case .always:
            clearIconButton.isHidden = false
        default:
            break
        }
    }
    
    private func updateViews() {
        leftIconButton?.removeFromSuperview()
        
        if let icon = input.icon {
            leftIconButton = ASButtonView(.iconOnly(icon: icon,
                                                    iconSize: CGSize(input.textAttributes.font.pointSize)))
            addSubview(leftIconButton!)
            leftIconButton!.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().offset(input.insets.left)
            }
            
        }
        
        textFiled.text = input.textAttributes.text
        textFiled.textColor = input.textAttributes.color
        textFiled.font = input.textAttributes.font
        textFiled.textAlignment = input.textAttributes.alignment
        textFiled.snp.remakeConstraints { make in
            if let _ = input.icon {
                make.leading.equalTo(leftIconButton!.snp.trailing).offset(input.spacing)
            } else {
                make.leading.equalToSuperview().inset(input.insets.left)
            }
            make.top.equalToSuperview().inset(input.insets.top)
            make.bottom.equalToSuperview().inset(input.insets.top)
            if input.clearButtonMode == .never {
                make.trailing.equalToSuperview().inset(input.insets.right)
            }
        }
        
        switch input.clearButtonMode {
        case .never:
            clearIconButton.removeFromSuperview()
        default:
            if clearIconButton.superview == nil {
                addSubview(clearIconButton)
            }
            clearIconButton.snp.remakeConstraints { make in
                make.leading.equalTo(textFiled.snp.trailing)
                make.centerY.equalToSuperview()
                make.trailing.equalToSuperview().inset(input.insets.right)
            }
        }
        updateClearButtonVisible()
        
        if let placeholderAttributes = input.placeholderAttributes {
            let style = NSMutableParagraphStyle()
            style.alignment = placeholderAttributes.alignment
            
            textFiled.attributedPlaceholder = NSAttributedString(string: placeholderAttributes.text,
                                                                 attributes: [
                                                                    .foregroundColor: placeholderAttributes.color,
                                                                    .font: placeholderAttributes.font,
                                                                    .paragraphStyle: style
                                                                 ])
        }
        
        textFiled.keyboardType = input.keyboardType
        textFiled.returnKeyType = input.returnKeyType
        textFiled.clearButtonMode = .never
        textFiled.tintColor = R.Color.Main
        textFiled.autocapitalizationType = input.autocapitalizationType
        textFiled.autocorrectionType = input.autocorrectionType
        textFiled.isSecureTextEntry = input.isSecureTextEntry
        
        setNeedsLayout()
    }
    
}
