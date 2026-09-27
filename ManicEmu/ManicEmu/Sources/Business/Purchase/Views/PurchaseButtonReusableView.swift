//
//  PurchaseButtonReusableView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/15.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class PurchaseButtonReusableView: UICollectionReusableView {
    var descriptionLabel: UILabel = {
        let view = UILabel()
        view.textColor = R.Color.LabelSecondary
        view.font = R.Font.Caption(emphasis: true)
        return view
    }()
    
    var buttonContainer: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.enablePressEffect = false
        view.layerCornerRadius = R.Size.ItemHeightMedium/2
        return view
    }()
    
    private var buttonLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.font = R.Font.Body(emphasis: true)
        return view
    }()
    
    private var termsOfServiceLabel: UILabel = {
        let view = UILabel()
        view.text = R.string.localizable.termOfServiceTitle()
        view.textColor = R.Color.LabelSecondary
        view.font = R.Font.Caption()
        view.isUserInteractionEnabled = true
        view.adjustsFontSizeToFitWidth = true
        view.addTapGesture { gesture in
            ASWebView.show(url: R.URLs.PaymentTerms)
        }
        return view
    }()
    
    private var privacyLabel: UILabel = {
        let view = UILabel()
        view.text = R.string.localizable.privacyPolicyTitle()
        view.textColor = R.Color.LabelSecondary
        view.font = R.Font.Caption()
        view.isUserInteractionEnabled = true
        view.adjustsFontSizeToFitWidth = true
        view.addTapGesture { gesture in
            ASWebView.show(url: R.URLs.PrivacyPolicy)
        }
        return view
    }()
    
    private var userProtocolLabel: UILabel = {
        let view = UILabel()
        view.text = R.string.localizable.userAgreementTitle()
        view.textColor = R.Color.LabelSecondary
        view.font = R.Font.Caption()
        view.isUserInteractionEnabled = true
        view.adjustsFontSizeToFitWidth = true
        view.addTapGesture { gesture in
            ASWebView.show(url: R.URLs.TermsOfUse)
        }
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(R.Size.ContentSpaceHuge)
        }
        
        addSubview(buttonContainer)
        buttonContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceHuge)
            make.top.equalTo(descriptionLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.height.equalTo(R.Size.ItemHeightMedium)
        }
        
        buttonContainer.addSubview(buttonLabel)
        buttonLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(privacyLabel)
        privacyLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(buttonContainer.snp.bottom).offset(R.Size.ContentSpaceSmall)
        }
        
        let leftLine = UIView()
        leftLine.backgroundColor = R.Color.LabelSecondary
        addSubview(leftLine)
        leftLine.snp.makeConstraints { make in
            make.trailing.equalTo(privacyLabel.snp.leading).offset(-R.Size.ContentSpaceTiny)
            make.centerY.equalTo(privacyLabel)
            make.height.equalTo(privacyLabel).inset(2)
            make.width.equalTo(1)
        }
        
        let rightLine = UIView()
        rightLine.backgroundColor = R.Color.LabelSecondary
        addSubview(rightLine)
        rightLine.snp.makeConstraints { make in
            make.leading.equalTo(privacyLabel.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalTo(privacyLabel)
            make.height.equalTo(privacyLabel).inset(2)
            make.width.equalTo(1)
        }
        
        //左边 服务条款
        addSubview(termsOfServiceLabel)
        termsOfServiceLabel.snp.makeConstraints { make in
            make.trailing.equalTo(leftLine.snp.leading).offset(-R.Size.ContentSpaceTiny)
            make.centerY.equalTo(leftLine)
            make.leading.greaterThanOrEqualTo(R.Size.ContentSpaceHuge)
        }
        
        //右边 用户协议
        addSubview(userProtocolLabel)
        userProtocolLabel.snp.makeConstraints { make in
            make.leading.equalTo(rightLine.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.centerY.equalTo(rightLine)
            make.trailing.lessThanOrEqualToSuperview().offset(-R.Size.ContentSpaceHuge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(title: String, descripton: String, enable: Bool) {
        descriptionLabel.text = descripton
        buttonContainer.backgroundColor = enable ? R.Color.Main : R.Color.Main.darken(by: UIDevice.isDarkMode ? 0.7 : 0.35)
        buttonContainer.isUserInteractionEnabled = enable
        buttonContainer.enablePressEffect = false
        buttonLabel.text = title
        buttonLabel.textColor = enable ? R.Color.LabelPrimary.forceStyle(.dark) : R.Color.LabelPrimary.forceStyle(.dark).darken(by: UIDevice.isDarkMode ? 0.7 : 0.35)
    }
    
    
}
