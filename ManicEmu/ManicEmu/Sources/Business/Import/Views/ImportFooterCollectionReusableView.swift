//
//  ImportFooterCollectionReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/23.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class ImportFooterCollectionReusableView: UICollectionReusableView {
    var channelButton: UIView = {
        let view = UIView()
        if #available(iOS 26.0, tvOS 26.0, *) {
            view.makeGlass()
            view.isFocusable = true
        } else {
            view.enablePressEffect = true
            view.backgroundColor = R.Color.BackgroundSecondary
        }
        view.layerCornerRadius = 15
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = RoundAndBorderView(roundCorner: .allCorners,
                                               radius: R.Size.CornerRadiusMedium,
                                               dashPattern: [8, 4])
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightLarge)
            make.leading.trailing.equalToSuperview()
        }
        
        var button = ASButton.iconOnly(icon: .symbol(.handDrawFill, colors: [R.Color.Yellow]),
                                       iconSize: CGSize(R.Size.ButtonExtraExtraSmall),
                                       background: R.Color.Yellow.withAlphaComponent(0.1),
                                       insets: .init(inset: R.Size.ContentSpaceMicro))
        var attributes = button.allAttributes[.normal]
        attributes?.border = ASBorderStyle()
        button = button.setAttributes(attributes, state: .normal)
        button.cornerStyle = .radius(R.Size.CornerRadiusMicro)
        let tipsIcon = ASButtonView(button)
        containerView.addSubview(tipsIcon)
        tipsIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceSmall)
            make.centerY.equalToSuperview()
        }
        
        let descLabel = UILabel()
        descLabel.numberOfLines = 0
        var matt = NSMutableAttributedString(string: "Drag & Drop", attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
        matt.append(NSAttributedString(string: "\n" + R.string.localizable.importDragAndDropTips(), attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
        let style = NSMutableParagraphStyle()
        style.lineSpacing = R.Size.ContentSpaceTiny/2
        matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        descLabel.attributedText = matt
        
        containerView.addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.centerY.equalTo(tipsIcon)
            make.leading.equalTo(tipsIcon.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceSmall)
        }
        
        let seperator = SparkleSeperatorView()
        addSubview(seperator)
        seperator.snp.makeConstraints { make in
            make.leading.trailing.equalTo(containerView).inset(R.Size.ContentSpaceLarge)
            make.height.equalTo(16)
            make.top.equalTo(containerView.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        addSubview(channelButton)
        channelButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightMicro)
            make.bottom.equalToSuperview()
        }
        let channelLinkLabel = UILabel()
        channelLinkLabel.textAlignment = .center
        channelLinkLabel.adjustsFontSizeToFitWidth = true
        channelButton.addSubview(channelLinkLabel)
        channelLinkLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.centerY.equalToSuperview()
        }
        let channelName = Locale.prefersCN ? R.string.localizable.qqChannelName() : "Discord"
        let matt2 = NSMutableAttributedString(string: R.string.localizable.importChannelTips(" \(channelName) "), attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelPrimary])
        channelLinkLabel.attributedText = matt2.applying(attributes: [.foregroundColor: R.Color.Purple], toOccurrencesOf: channelName)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
}
