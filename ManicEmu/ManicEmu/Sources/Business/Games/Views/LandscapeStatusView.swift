//
//  LandscapeStatusView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Network

///横屏模式导航栏右侧的状态胶囊 展示时间/日期/WiFi/电量/手柄连接状态
class LandscapeStatusView: UIVisualEffectView {
    
    private let containerView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = R.Size.ContentSpaceExtraSmall
        return view
    }()
    
    private let timeLabel = ASLabelView(text: .largeText(""))
    private let wifiIconView = ASIconView(.symbol(.wifi, colors: [R.Color.LabelPrimary]))
    private let batteryIconView = ASIconView(.symbol(.battery100, colors: [R.Color.LabelPrimary]))
    private lazy var controllerIconView: ASButtonView = {
        let view = ASButtonView(.small(title: ""))
        view.enableFocusEffects = false
        view.didTapButton = { [weak self] in
            self?.didTapController?()
        }
        return view
    }()
    
    private var timer: Timer? = nil
    private var pathMonitor: NWPathMonitor? = nil
    private var batteryLevelNotification: Any? = nil
    private var batteryStateNotification: Any? = nil
    private var controllerConnectNotification: Any? = nil
    private var controllerDisconnectNotification: Any? = nil
    private var keyboardConnectNotification: Any? = nil
    private var keyboardDisconnectNotification: Any? = nil
    
    var didTapController: (() -> Void)? = nil
    
    init() {
        super.init(effect: nil)
        
        masksToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        
        if #available(iOS 26.0, tvOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .clear)
            glassEffect.tintColor = R.Color.BackgroundSecondary.withAlphaComponent(0.2)
            glassEffect.isInteractive = true
            effect = glassEffect
        } else {
            backgroundColor = R.Color.BackgroundSecondary
        }
        
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(UIEdgeInsets(horizontal: R.Size.ContentSpaceMedium*2, vertical: R.Size.ContentSpaceExtraSmall*2))
        }
        
        containerView.addArrangedSubview(timeLabel)
        containerView.setCustomSpacing(R.Size.ContentSpaceSmall, after: timeLabel)
        containerView.addArrangedSubview(wifiIconView)
        containerView.addArrangedSubview(batteryIconView)
        
        for iconView in [wifiIconView, batteryIconView] {
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(R.Size.SymbolSize)
            }
        }
        
        contentView.addSubview(controllerIconView)
        controllerIconView.snp.makeConstraints { make in
            make.leading.equalTo(containerView.snp.trailing).offset(R.Size.ContentSpaceExtraSmall)
            make.top.trailing.bottom.equalToSuperview()
        }
        
        setupClock()
        setupWiFiMonitor()
        setupBatteryMonitor()
        setupControllerMonitor()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        timer?.invalidate()
        pathMonitor?.cancel()
        if let batteryLevelNotification {
            NotificationCenter.default.removeObserver(batteryLevelNotification)
        }
        if let batteryStateNotification {
            NotificationCenter.default.removeObserver(batteryStateNotification)
        }
        if let controllerConnectNotification {
            NotificationCenter.default.removeObserver(controllerConnectNotification)
        }
        if let controllerDisconnectNotification {
            NotificationCenter.default.removeObserver(controllerDisconnectNotification)
        }
        if let keyboardConnectNotification {
            NotificationCenter.default.removeObserver(keyboardConnectNotification)
        }
        if let keyboardDisconnectNotification {
            NotificationCenter.default.removeObserver(keyboardDisconnectNotification)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layerCornerRadius = bounds.height/2
    }
    
    //MARK: - 时间日期
    
    private func setupClock() {
        updateClock()
        //每隔15秒刷新一次 保证分钟切换误差可接受
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    
    private func updateClock() {
        let now = Date()
        timeLabel.title = now.dateTimeString(ofStyle: .short)
    }
    
    //MARK: - WiFi
    
    private func setupWiFiMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let wifiConnected = path.status == .satisfied && path.usesInterfaceType(.wifi)
            DispatchQueue.main.async {
                self?.wifiIconView.icon = .symbol(wifiConnected ? .wifi : .wifiSlash,
                                                  colors: [wifiConnected ? R.Color.LabelPrimary : R.Color.LabelTertiary])
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        pathMonitor = monitor
    }
    
    //MARK: - 电量
    
    private func setupBatteryMonitor() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBattery()
        batteryLevelNotification = NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateBattery()
        }
        batteryStateNotification = NotificationCenter.default.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateBattery()
        }
    }
    
    private func updateBattery() {
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else {
            //模拟器等无法获取电量的场景
            batteryIconView.isHidden = true
            return
        }
        batteryIconView.isHidden = false
        
        let isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        let symbol: SFSymbol
        if isCharging {
            symbol = .battery100
        } else if level > 0.85 {
            symbol = .battery100
        } else if level > 0.6 {
            symbol = .battery75
        } else if level > 0.35 {
            symbol = .battery50
        } else if level > 0.1 {
            symbol = .battery25
        } else {
            symbol = .battery0
        }
        
        var color = R.Color.LabelPrimary
        if isCharging {
            color = R.Color.Green
        } else if level <= 0.2 {
            color = R.Color.Red
        }
        batteryIconView.icon = .symbol(symbol, colors: [color])
    }
    
    //MARK: - 手柄
    
    private func setupControllerMonitor() {
        updateController()
        controllerConnectNotification = NotificationCenter.default.addObserver(forName: .externalGameControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.updateController()
        }
        controllerDisconnectNotification = NotificationCenter.default.addObserver(forName: .externalGameControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.updateController()
        }
        keyboardConnectNotification = NotificationCenter.default.addObserver(forName: .externalKeyboardDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.updateController()
        }
        keyboardDisconnectNotification = NotificationCenter.default.addObserver(forName: .externalKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.updateController()
        }
    }
    
    private func updateController() {
        let connectedControllers = ExternalGameControllerManager.shared.connectedControllers
        let connected = connectedControllers.count > 0
        let isOnlyKeyboard = connected && connectedControllers.allSatisfy({ $0.inputType == .keyboard })
        let icon: ASIcon = .symbolImage(isOnlyKeyboard ? R.image.keyboard_iconSymbols() : R.image.controller_iconSymbols(),
                                        colors: [connected ? R.Color.LabelPrimary : R.Color.LabelSecondary])
        let backgroundColor: UIColor
        if #available(iOS 26.0, tvOS 26.0, *) {
            backgroundColor = R.Color.BackgroundTertiary.withAlphaComponent(0.15)
        } else {
            backgroundColor = R.Color.BackgroundTertiary
        }
        var button = ASButton.smallIconButton(icon: icon, background: backgroundColor)
        button.allAttributes[.normal]?.border = ASBorderStyle(color: R.Color.Border, width: 1)
        controllerIconView.button = button
    }
}
