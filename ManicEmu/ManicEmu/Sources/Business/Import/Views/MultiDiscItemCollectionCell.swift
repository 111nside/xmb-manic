//
//  MultiDiscItemCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class MultiDiscItemCollectionCell: UICollectionViewCell {
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        view.lineBreakMode = .byTruncatingMiddle
        return view
    }()
    
    let deleteIcon = SymbolButton(image: nil,
                                  title: R.string.localizable.removeTitle(),
                                  titleFont: R.Font.Body(),
                                  titleColor: R.Color.Main,
                                  titleAlignment: .right,
                                  horizontalContian: true)
    
    private let sortIcon = SymbolButton(image: .init(symbol: .line3Horizontal,
                                                     font: R.Font.Headline(emphasis: true),
                                                     color: R.Color.BackgroundTertiary))
    
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
        
        sortIcon.backgroundColor = .clear
        sortIcon.isFocusable = false
        addSubview(sortIcon)
        sortIcon.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeMedium)
            make.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        
        deleteIcon.isFocusable = false
        addSubview(deleteIcon)
        deleteIcon.backgroundColor = R.Color.BackgroundTertiary
        deleteIcon.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(index: Int, item: MultiDiscBuilderView.M3uItem) {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()
        let matt = NSMutableAttributedString(string: "Disc \(index)", attributes: [.foregroundColor: R.Color.LabelPrimary, .font: R.Font.Headline(emphasis: true)])
        if item.files.count > 0 {
            matt.append(NSAttributedString(string: "\n" + item.url.lastPathComponent, attributes: [.foregroundColor: R.Color.LabelSecondary, .font: R.Font.Body()]))
            item.files.forEach { url in
                let itemView = BIOSCollectionViewCell.ItemView(enableButton: false, enableOptionButton: false)
                itemView.titleLabel.text = url.lastPathComponent
                itemView.titleLabel.lineBreakMode = .byTruncatingMiddle
                itemView.optionButton.isHidden = true
                itemView.button.isHidden = true
                itemViews.append(itemView)
                addSubview(itemView)
            }
            for (index, view) in itemViews.enumerated() {
                view.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                    make.height.equalTo(R.Size.ItemHeightLarge)
                    if index == 0 {
                        make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceMedium)
                    } else {
                        make.top.equalTo(itemViews[index-1].snp.bottom).offset(R.Size.ContentSpaceMedium)
                    }
                }
            }
        } else {
            let itemView = BIOSCollectionViewCell.ItemView(enableButton: false, enableOptionButton: false)
            itemView.titleLabel.text = item.url.lastPathComponent
            itemView.titleLabel.lineBreakMode = .byTruncatingMiddle
            itemView.optionButton.isHidden = true
            itemView.button.isHidden = true
            itemViews.append(itemView)
            addSubview(itemView)
            itemView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
                make.height.equalTo(R.Size.ItemHeightLarge)
                make.top.equalTo(titleLabel.snp.bottom).offset(R.Size.ContentSpaceMedium)
            }
        }
        let style = NSMutableParagraphStyle()
        style.lineSpacing = R.Size.ContentSpaceTiny
        style.lineBreakMode = .byTruncatingMiddle
        titleLabel.attributedText = matt.applying(attributes: [.paragraphStyle: style])
    }
    
    static func CellHeight(itemCount: Int) -> Double {
        let deleteButtonHeight = R.Size.ContentSpaceMedium + R.Size.ItemHeightLarge
        let titleLabelHeight = itemCount == 0 ? 21 : 43.0
        let itemCount = itemCount == 0 ? 1 : itemCount
        return R.Size.ContentSpaceMedium + titleLabelHeight + (Double(itemCount) * R.Size.ItemHeightLarge) + (Double(itemCount + 1) * R.Size.ContentSpaceMedium) + deleteButtonHeight
    }
}
