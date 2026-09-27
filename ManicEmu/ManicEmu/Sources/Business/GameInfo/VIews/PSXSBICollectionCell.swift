//
//  PSXSBICollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/4.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class PSXSBICollectionCell: UICollectionViewCell {
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        return view
    }()
    
    let addFileButton = SymbolButton(image: nil,
                                     title: R.string.localizable.multiDiscAddFile(".sbi"),
                                     titleFont: R.Font.Body(),
                                     titleColor: R.Color.LabelPrimary,
                                     titleAlignment: .right,
                                     horizontalContian: true)
    
    private var itemViews: [BIOSCollectionViewCell.ItemView] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layerCornerRadius = R.Size.CornerRadiusLarge
        backgroundColor = R.Color.BackgroundSecondary
        
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
        }
        
        addSubview(addFileButton)
        addFileButton.backgroundColor = R.Color.BackgroundTertiary
        addFileButton.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(filePath: String) {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()

        let style = NSMutableParagraphStyle()
        style.lineSpacing = R.Size.ContentSpaceTiny
        style.lineBreakMode = .byTruncatingMiddle
        let matt = NSMutableAttributedString(string: filePath.lastPathComponent, attributes: [.foregroundColor: R.Color.LabelPrimary, .font: R.Font.Headline(emphasis: true), .paragraphStyle: style])
        titleLabel.attributedText = matt
        
       
        let itemView = BIOSCollectionViewCell.ItemView(enableButton: false)
        itemView.titleLabel.text = filePath.deletingPathExtension.lastPathComponent + ".sbi"
        itemView.titleLabel.lineBreakMode = .byTruncatingMiddle
        itemView.optionButton.setTitle("(\(R.string.localizable.sbiUnImport()))", for: .normal)
        itemView.optionButton.setTitleColor(R.Color.Red, for: .normal)
        itemView.optionButton.setTitle("(\(R.string.localizable.biosImported()))", for: .selected)
        itemView.optionButton.setTitleColor(R.Color.Green, for: .selected)
        itemView.optionButton.isSelected = FileManager.default.fileExists(atPath: filePath.deletingPathExtension + ".sbi")
        itemView.button.isHidden = true
        itemViews.append(itemView)
        addSubview(itemView)
        itemView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
            make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceMedium)
        }
        
    }
    
    static func CellHeight() -> Double {
        let deleteButtonHeight = R.Size.ItemHeightLarge + R.Size.ContentSpaceMedium
        let titleLabelHeight = 21.0
        return R.Size.ContentSpaceMedium + titleLabelHeight + R.Size.ItemHeightLarge + (2 * R.Size.ContentSpaceMedium) + deleteButtonHeight
    }
}
