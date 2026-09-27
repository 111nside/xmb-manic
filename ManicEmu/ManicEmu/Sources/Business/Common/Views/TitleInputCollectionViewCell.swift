//
//  TitleInputCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/19.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class TitleInputCollectionViewCell: UICollectionViewCell {
    static let CellHeight = 88.0
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.font = R.Font.Subheadline(emphasis: true)
        view.textColor = R.Color.LabelSecondary
        return view
    }()
    
    var shouldGoNext: (()->Void)? = nil
    lazy var editTextField: ASListInputView = {
        var input = ASInput.large()
        input.autocapitalizationType = .none
        input.autocorrectionType = .no
        let view = ASListInputView(input)
        view.didTapReturn = { [weak self] _ in
            guard let self = self else { return }
            if self.editTextField.input.returnKeyType == .done {
                self.editTextField.resignFirstResponder()
            } else if self.editTextField.input.returnKeyType == .next {
                self.shouldGoNext?()
            }
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
            make.top.equalToSuperview()
        }
        
        addSubview(editTextField)
        editTextField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(title: String,
                 text: String? = nil,
                 placeholder: String? = nil,
                 keyboardType: UIKeyboardType = .default,
                 returnKeyType: UIReturnKeyType = .done) {
        titleLabel.text = title
        var input = editTextField.input
        
        input.textAttributes = .title(text: text ?? "")
        
        if let placeholder, !placeholder.isEmpty {
            input.placeholderAttributes = ASText.Attributes(text: placeholder,
                                                            color: R.Color.LabelTertiary,
                                                            font: R.Font.Body())
        } else {
            input.placeholderAttributes = nil
        }
        
        input.keyboardType = keyboardType
        input.returnKeyType = returnKeyType
        editTextField.input = input
    }
    
}
