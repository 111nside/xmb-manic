//
//  ASCardView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/17.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASCardView: BaseView {
    class ASCardIconView: RoundAndBorderView {
        var icon: ASIcon? {
            get {
                iconView.icon
            }
            set {
                iconView.icon = newValue
            }
        }
        
        var iconInsets: UIEdgeInsets = .zero {
            didSet {
                iconView.snp.remakeConstraints { make in
                    make.leading.equalToSuperview().inset(iconInsets.left)
                    make.trailing.equalToSuperview().inset(iconInsets.right)
                    make.top.equalToSuperview().inset(iconInsets.top)
                    make.bottom.equalToSuperview().inset(iconInsets.bottom)
                }
            }
        }
        
        private var iconView: ASIconView = {
            let view = ASIconView()
            return view
        }()
        
        override init(roundCorner: UIRectCorner = [],
                      radius: CGFloat = R.Size.CornerRadiusLarge,
                      borderColor: UIColor = R.Color.Border,
                      borderWidth: CGFloat = 1,
                      dashPattern: [NSNumber]? = nil) {
            super.init(roundCorner: roundCorner,
                       radius: radius,
                       borderColor: borderColor,
                       borderWidth: borderWidth)
            addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private var iconView: ASCardIconView = {
        let view = ASCardIconView(roundCorner: .allCorners)
        return view
    }()
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }()
    
    var switchButton: ASSwitchView = {
        let view = ASSwitchView(.init(state: .off))
        view.alpha = 0
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = R.Color.BackgroundSecondary
        layerCornerRadius = R.Size.CornerRadiusLarge

        addSubviews([iconView, titleLabel, switchButton])
        
        iconView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.size.equalTo(R.Size.ButtonMedium)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(R.Size.ContentSpaceExtraSmall)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        
        switchButton.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            if #available(iOS 26.0, tvOS 26.0, *) {
                make.size.equalTo(CGSize(width: 63, height: 28))
            } else {
                make.size.equalTo(CGSize(width: 51, height: 31))
            }
        }
        if #available(iOS 26.0, tvOS 26.0, *) {} else {
            switchButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(icon: ASIcon,
                 iconBackgroundColor: UIColor = .clear,
                 iconBorderColor: UIColor = R.Color.Border,
                 iconCornerRadius: CGFloat = R.Size.CornerRadiusSmall,
                 iconInsets: UIEdgeInsets = .zero,
                 title: String,
                 detail: String? = nil,
                 enableSwitch: Bool = false,
                 switchState: ASSwitch.State = .off,
                 didSwitchChange: ((Bool)->Void)? = nil,
                 didSwitchDisableTap: (() -> Void)? = nil) {
        iconView.icon = icon
        iconView.backgroundColor = iconBackgroundColor
        iconView.borderColor = iconBorderColor
        iconView.radius = iconCornerRadius
        iconView.iconInsets = iconInsets
        
        var matt = NSMutableAttributedString(string: title, attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
        if let detail {
            matt.append(NSAttributedString(string: "\n" + detail, attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = R.Size.ContentSpaceTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        style.lineSpacing = R.Size.ContentSpaceTiny
        matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        titleLabel.attributedText = matt
        
        switchButton.alpha = enableSwitch ? 1 : 0
        
        if enableSwitch {
            switch switchState {
            case .on:
                switchButton.on = true
                switchButton.isEnabled = true
            case .off:
                switchButton.on = false
                switchButton.isEnabled = true
            case .disabled:
                switchButton.on = false
                switchButton.isEnabled = false
            }
            switchButton.alpha = 1
            switchButton.didValueChange = didSwitchChange
            switchButton.disabledTapAction = didSwitchDisableTap
        } else {
            switchButton.alpha = 0
            switchButton.didValueChange = nil
            switchButton.disabledTapAction = nil
        }
    }
}
