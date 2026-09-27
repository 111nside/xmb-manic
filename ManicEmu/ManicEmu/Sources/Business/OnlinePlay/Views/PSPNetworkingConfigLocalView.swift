//
//  PSPNetworkingConfigLocalView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PSPNetworkingConfigLocalView: BaseView {
    private var asHost: Bool = false
    
    private let setAsHostSelectImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.layerCornerRadius = R.Size.IconSizeMedium.height/2
        view.layer.shadowColor = R.Color.Shadow.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowRadius = 2
        view.image = UIImage(symbol: .circle,
                             size: R.Size.IconSizeMedium.height,
                             weight: .regular,
                             color: R.Color.LabelSecondary)
        return view
    }()
    
    private let setAsHostTitleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString(string: R.string.localizable.setAsHost(),
                                                       attributes: [
                                                        .foregroundColor: R.Color.LabelPrimary,
                                                        .font: R.Font.Body(emphasis: true)
                                                       ])
        titleLabel.numberOfLines = 2
        return titleLabel
    }()
    
    private lazy var setAsHostView: UIView = {
        let view = UIView()
        view.layerCornerRadius = R.Size.CornerRadiusMedium
        view.backgroundColor = R.Color.BackgroundTertiary
        
        let iconView = UIImageView()
        iconView.contentMode = .center
        iconView.layerCornerRadius = 6
        iconView.image = UIImage(symbol: .person2Wave2Fill, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
        iconView.backgroundColor = R.Color.Red
        view.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.size.equalTo(R.Size.IconSizeLarge)
            make.centerY.equalToSuperview()
        }
        
        view.addSubview(setAsHostTitleLabel)
        setAsHostTitleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
        }
        
        view.addSubview(setAsHostSelectImageView)
        setAsHostSelectImageView.snp.makeConstraints { make in
            make.leading.equalTo(setAsHostTitleLabel.snp.trailing).offset(R.Size.ContentSpaceSmall)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
            make.size.equalTo(R.Size.IconSizeMedium)
        }
        
        let button = UIButton(type: .custom)
        button.isFocusable = true
        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        button.onTap { [weak self] in
            guard let self else { return }
            //点击设置为主机
            self.asHost = !self.asHost
            self.didAsHostChange?(self.asHost)
        }
        
        return view
    }()
    
    private lazy var ipAddressTitleTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = R.Color.LabelSecondary
        textField.font = R.Font.Footnote()
        textField.attributedPlaceholder = NSAttributedString(string: "192.168.1.1",
                                                             attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelTertiary])
        textField.clearButtonMode = .never
        textField.returnKeyType = .done
        textField.textAlignment = .right
        textField.onReturnKeyPress { [weak self, weak textField] in
            guard let self = self else { return }
            textField?.resignFirstResponder()
        }
        textField.onChange { [weak textField] text in
            
        }
        textField.didEndEditing { [weak self] in
            guard let self else { return }
            self.didConnectedIPChange?(self.ipAddressTitleTextField.text)
        }
        textField.isFocusable = true
        textField.onFocusConfirm = { [weak textField] in
            textField?.becomeFirstResponder() ?? false
        }
        return textField
    }()
    
    private lazy var ipAddressInputView: UIView = {
        let view = UIView()
        view.layerCornerRadius = R.Size.CornerRadiusMedium
        view.backgroundColor = R.Color.BackgroundTertiary
        
        let iconView = UIImageView()
        iconView.contentMode = .center
        iconView.layerCornerRadius = 6
        iconView.image = UIImage(symbol: .globe, font: R.Font.Footnote(emphasis: true), color: R.Color.LabelPrimary.forceStyle(.dark))
        iconView.backgroundColor = R.Color.Red
        view.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
            make.size.equalTo(R.Size.IconSizeLarge)
            make.centerY.equalToSuperview()
        }
        
        let titleLabel = UILabel()
        titleLabel.text = R.string.localizable.ipAddress()
        titleLabel.textColor = R.Color.LabelPrimary
        titleLabel.font = R.Font.Body(emphasis: true)
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
        }
        
        view.addSubview(ipAddressTitleTextField)
        ipAddressTitleTextField.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(R.Size.ContentSpaceSmall)
            make.centerY.equalToSuperview()
        }
        
        var chevronIconView: UIImageView = {
            let view = UIImageView()
            view.image = UIImage(symbol: .chevronRight,
                                 font: R.Font.Caption(emphasis: true),
                                 color: R.Color.LabelTertiary)
            if Locale.isRTLLanguage {
                view.transform = CGAffineTransform(scaleX: -1, y: 1)
            }
            return view
        }()
        
        view.addSubview(chevronIconView)
        chevronIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(ipAddressTitleTextField.snp.trailing).offset(R.Size.ContentSpaceTiny)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
            make.size.equalTo(CGSize(width: 10, height: 14))
        }
        
        return view
    }()
    
    private lazy var portOffsetView: AddTriggerButtonStyleView.SliderView = {
        let view = AddTriggerButtonStyleView.SliderView(title: R.string.localizable.portOffset(), valueSufix: nil, minimumValue: 1000, maximumValue: 65000, numberOfDecimalPlaces: -1)
        view.didChangeEnd = { [weak self ] port in
            guard let self else { return }
            self.didPortChange?(Int32(port))
        }
        return view
    }()
    
    private let hostIPLabel: UILabel = {
        let label = UILabel()
        label.font = R.Font.Footnote()
        label.textColor = R.Color.LabelSecondary
        label.text = R.string.localizable.hostAddress()
        return label
    }()
    
    private let serviceFoundLabel: UILabel = {
        let label = UILabel()
        label.font = R.Font.Footnote()
        label.textColor = R.Color.LabelSecondary
        label.text = R.string.localizable.serviceFound()
        return label
    }()
    
    private let loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.color = R.Color.LabelSecondary
        view.startAnimating()
        return view
    }()
    
    private var serviceListView: UIView = {
        let view = UIView()
        return view
    }()
    
    var didAsHostChange: ((Bool)->Void)? = nil
    var didPortChange: ((Int32)->Void)? = nil
    var didConnectedIPChange: ((String?)->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(setAsHostView)
        setAsHostView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalToSuperview()
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        portOffsetView.isHidden = true
        addSubview(portOffsetView)
        portOffsetView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(setAsHostView.snp.bottom).offset(-R.Size.ItemHeightLarge)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        addSubview(hostIPLabel)
        hostIPLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceHuge)
            make.top.equalTo(portOffsetView.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        addSubview(ipAddressInputView)
        ipAddressInputView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(hostIPLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        addSubview(serviceFoundLabel)
        serviceFoundLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceHuge)
            make.top.equalTo(ipAddressInputView.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        
        addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.size.equalTo(R.Size.IconSizeMedium)
            make.leading.equalTo(serviceFoundLabel.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.centerY.equalTo(serviceFoundLabel)
        }
        
        addSubview(serviceListView)
        serviceListView.snp.makeConstraints { make in
            make.top.equalTo(serviceFoundLabel.snp.bottom).offset(R.Size.ContentSpaceSmall)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class ServiceItemView: BaseView {
        var titleLabel: UILabel = {
            let title = UILabel()
            title.textColor = R.Color.LabelPrimary
            title.font = R.Font.Body()
            return title
        }()
        
        var button: UIButton = {
            let button = UIButton(type: .custom)
            button.titleLabel?.font = R.Font.Body2(emphasis: true)
            button.setTitle( R.string.localizable.connect(), for: .normal)
            button.setTitle( R.string.localizable.connected(), for: .selected)
            button.setTitleColor(R.Color.Red, for: .normal)
            button.setTitleColor(R.Color.Green, for: .selected)
            button.isFocusable = true
            return button
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            layerCornerRadius = R.Size.CornerRadiusMedium
            backgroundColor = R.Color.BackgroundTertiary
            
            addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(R.Size.ContentSpaceMedium)
                make.centerY.equalToSuperview()
            }
            
            addSubview(button)
            button.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceMedium)
                make.centerY.equalToSuperview()
            }
        }
        
        @MainActor required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private func updateSelectImageView() {
        if asHost {
            setAsHostSelectImageView.image = UIImage(symbol: .checkmarkCircleFill,
                                                     size: R.Size.IconSizeMedium.height,
                                                     weight: .bold,
                                                     colors: [R.Color.LabelPrimary.forceStyle(.dark), R.Color.Main])
        } else {
            setAsHostSelectImageView.image = UIImage(symbol: .circle,
                                                     size: R.Size.IconSizeMedium.height,
                                                     weight: .regular,
                                                     color: R.Color.LabelSecondary)
        }
        
    }
    
    func setData(config: PSPNetworkingConfig) {
        guard config.type == .local else { return }
        asHost = config.asHost
        
        updateSelectImageView()
        
        if asHost {
            let matt = NSMutableAttributedString(string: R.string.localizable.setAsHost(), attributes: [.font: R.Font.Body(), .foregroundColor: R.Color.LabelPrimary])
            if let ipAddress = BonjourKit.shared.currentIPAddress {
                matt.append(NSAttributedString(string: "\n\(ipAddress)", attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelSecondary]))
                let style = NSMutableParagraphStyle()
                style.lineSpacing = R.Size.ContentSpaceTiny/2
                style.alignment = .left
                setAsHostTitleLabel.attributedText = matt.applying(attributes: [.paragraphStyle: style])
            } else {
                setAsHostTitleLabel.attributedText = matt
            }
            
            portOffsetView.value = Float(config.asHostPort)
            portOffsetView.isHidden = false
            portOffsetView.snp.updateConstraints { make in
                make.top.equalTo(setAsHostView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            }
            
            hostIPLabel.isHidden = true
            ipAddressInputView.isHidden = true
            
            serviceFoundLabel.isHidden = true
            loadingView.isHidden = true
            serviceListView.isHidden = true
            
        } else {
            setAsHostTitleLabel.attributedText = NSMutableAttributedString(string: R.string.localizable.setAsHost(), attributes: [.font: R.Font.Body(), .foregroundColor: R.Color.LabelPrimary])
            
            portOffsetView.isHidden = true
            portOffsetView.snp.updateConstraints { make in
                make.top.equalTo(setAsHostView.snp.bottom).offset(-R.Size.ItemHeightLarge)
            }
            
            hostIPLabel.isHidden = false
            ipAddressInputView.isHidden = false
            ipAddressTitleTextField.text = config.connectedLocalIP
            
            serviceFoundLabel.isHidden = false
            loadingView.isHidden = false
            loadingView.startAnimating()
            serviceListView.isHidden = false
            
            serviceListView.subviews.forEach({ $0.removeFromSuperview() })
            for (index, service) in config.hostList.enumerated() {
                let itemView = ServiceItemView()
                itemView.titleLabel.text = service
                let isConnected = config.connectedLocalIP == service
                itemView.button.isSelected = isConnected
                itemView.button.onTap { [weak self, weak itemView] in
                    guard let self, !isConnected else { return }
                    self.serviceListView.subviews.forEach {
                        ($0 as? ServiceItemView)?.button.isSelected = false
                    }
                    self.ipAddressTitleTextField.text = service
                    itemView?.button.isSelected = true
                    self.didConnectedIPChange?(service)
                }
                serviceListView.addSubview(itemView)
                itemView.snp.makeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    if index == 0 {
                        make.top.equalToSuperview()
                    } else {
                        make.top.equalTo(serviceListView.subviews[index-1].snp.bottom).offset(R.Size.ContentSpaceLarge)
                    }
                    make.height.equalTo(R.Size.ItemHeightLarge)
                    if index == config.hostList.count - 1 {
                        make.bottom.equalToSuperview()
                    }
                }
            }
        }
    }
}
