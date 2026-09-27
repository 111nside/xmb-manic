//
//  PriceItemCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import StoreKit

class PriceItemCollectionCell: UICollectionViewCell {
    
    private var infoLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        return view
    }()
    
    private var product: Product? = nil
    
    private var promptContainer: UIView = {
        let view = UIView()
        view.layerCornerRadius = R.Size.IconSizeMedium.height/2
        return view
    }()
    
    private var promptLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.textColor = R.Color.LabelPrimary.forceStyle(.dark)
        view.font = R.Font.Caption(emphasis: true)
        return view
    }()
    
    private var roundAndBorderView: RoundAndBorderView = {
        let view = RoundAndBorderView(roundCorner: .allCorners, radius: R.Size.CornerRadiusLarge, borderWidth: 2)
        view.enablePressEffect = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isFocusable = true
        addSubview(roundAndBorderView)
        roundAndBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        roundAndBorderView.addSubview(infoLabel)
        infoLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        infoLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        infoLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        
        roundAndBorderView.addSubview(promptContainer)
        promptContainer.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.IconSizeMedium.height)
            make.leading.equalTo(infoLabel.snp.trailing).offset(R.Size.ContentSpaceExtraSmall).priority(.high)
        }
        
        promptContainer.addSubview(promptLabel)
        promptLabel.setContentHuggingPriority(.required, for: .horizontal)
        promptLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        promptLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceExtraSmall)
            make.top.bottom.equalToSuperview()
        }
    }
    
    override var isSelected: Bool {
        willSet {
            setData(product: product, isSelected: newValue)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(product: Product?, isSelected: Bool) {
        if let product = product, let type = PurchaseProductType(rawValue: product.id) {
            self.product = product
            
            //字体颜色
            let labelColor =  isSelected ? R.Color.LabelPrimary : R.Color.LabelSecondary
            //小号字体
            let smallFontAttributes: [NSAttributedString.Key : Any] = [.font: R.Font.Caption(emphasis: true), .foregroundColor: labelColor]
            //大号字体
            let bigFontAttributes: [NSAttributedString.Key : Any] = [.font: R.Font.LargeTitle(emphasis: true), .foregroundColor: labelColor]
            //货币符号
            let currencySymbol = product.priceFormatStyle.locale.currencySymbol ?? product.priceFormatStyle.currencyCode
            //价格AttributedString
            var formatedPrice = "\(product.price)"
            if product.price != Decimal(NSDecimalNumber(decimal: product.price).intValue) {
                //包含了小数
                formatedPrice = String(format: "%.2f", (product.price as NSDecimalNumber).doubleValue)
            }
            let priceString = NSMutableAttributedString(string: "\n" + currencySymbol + "\(formatedPrice)", attributes: bigFontAttributes)
            //描述字符
            var description = ""
            
            switch type {
            case .annual:
                //按年订阅
                description += R.string.localizable.annualDescription()
                if let freeTrialDesc = product.freeTrialDesc {
                    description += ((description.isEmpty ? "" : " · ") + freeTrialDesc)
                }
                priceString.append(NSAttributedString(string: " " + R.string.localizable.purchasePricePerYear() + " (\(currencySymbol)\(String(format: "%.2f", (product.price/12 as NSDecimalNumber).doubleValue))\(R.string.localizable.purchasePricePerMonth()))", attributes: smallFontAttributes))
                promptLabel.text = R.string.localizable.promptLabelForYear()
                promptContainer.backgroundColor = R.Color.Main.lighten()
            case .monthly:
                //按月订阅
                description += R.string.localizable.monthlyDescription()
                if let freeTrialDesc = product.freeTrialDesc {
                    description += ((description.isEmpty ? "" : " · ") + freeTrialDesc)
                }
                priceString.append(NSAttributedString(string: " " + R.string.localizable.purchasePricePerMonth(), attributes: smallFontAttributes))
                promptLabel.text = R.string.localizable.promptLabelForMonth()
                promptContainer.backgroundColor = R.Color.Green
            case .forever:
                //永久会员
                description += R.string.localizable.foreverDescription()
                priceString.append(NSAttributedString(string: " ", attributes: bigFontAttributes))
                var newSmallFontAttributes = smallFontAttributes
                newSmallFontAttributes[.strikethroughStyle] = NSNumber(value: NSUnderlineStyle.single.rawValue as Int)
                priceString.append(NSAttributedString(string:"\(currencySymbol)" + "\(product.price*2)", attributes: newSmallFontAttributes))
                promptLabel.text = R.string.localizable.promptLabelForForever()
                promptContainer.backgroundColor = R.Color.Yellow
            }
            
            //描述AttributedString
            let descriptionString = NSMutableAttributedString(string: description, attributes: smallFontAttributes)
            if Locale.isRTLLanguage {
                infoLabel.attributedText = priceString + " " + descriptionString
            } else {
                infoLabel.attributedText = descriptionString + priceString
            }
            
            
            roundAndBorderView.borderColor = isSelected ? R.Color.Main : R.Color.Border
            roundAndBorderView.backgroundColor = isSelected ? R.Color.Main.withAlphaComponent(0.1) : R.Color.BackgroundSecondary
        }
    }
}
