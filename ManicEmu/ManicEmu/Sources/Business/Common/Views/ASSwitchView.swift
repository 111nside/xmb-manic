//
//  ASSwitchView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASSwitchView: BaseView {
    private let switchButton = DisabledTapSwitch()
    
    private var didSetup = false
    
    var on: Bool {
        didSet {
            switchButton.setOn(on, animated: false)
        }
    }
    
    var onColor: UIColor {
        didSet {
            switchButton.onTintColor = onColor
        }
    }
    
    var offColor: UIColor {
        didSet {
            switchButton.tintColor = offColor
        }
    }
    
    var isEnabled: Bool {
        didSet {
            switchButton.isEnabled = isEnabled
        }
    }
    
    var disabledTapAction: (()->Void)? {
        didSet {
            switchButton.disabledTapAction = disabledTapAction
        }
    }
    
    var didValueChange: ((Bool)->Void)? = nil
    
    init(_ aSwitch: ASSwitch) {
        self.on = aSwitch.state == .on
        self.isEnabled = aSwitch.state != .disabled
        self.onColor = aSwitch.onColor
        self.offColor = aSwitch.offColor
        super.init(frame: .zero)
        isFocusable = true
        onFocusConfirm = { [weak self] in
            guard let self else { return false }
            if !self.isEnabled {
                self.disabledTapAction?()
                return true
            }
            let newValue = !self.on
            self.on = newValue
            self.didValueChange?(newValue)
            return true
        }
        setupViewsIfNeeded()
        updateContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private static var switchSize: CGSize {
        if #available(iOS 26.0, tvOS 26.0, *) {
            return CGSize(width: 63, height: 28)
        } else {
            return CGSize(width: 51, height: 31)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        Self.switchSize
    }
    
    private func setupViewsIfNeeded() {
        guard !didSetup else { return }
        didSetup = true
        
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        
        switchButton.setContentHuggingPriority(.required, for: .horizontal)
        switchButton.setContentHuggingPriority(.required, for: .vertical)
        switchButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        switchButton.setContentCompressionResistancePriority(.required, for: .vertical)
        
        addSubview(switchButton)
        switchButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.size.equalTo(Self.switchSize)
        }
        
        if #available(iOS 26.0, tvOS 26.0, *) {} else {
            switchButton.transform = CGAffineTransformMakeScale(0.9, 0.9)
        }
        
        switchButton.onChange { [weak self] value in
            self?.didValueChange?(value)
        }
    }
    
    private func updateContent() {
        switchButton.onTintColor = onColor
        switchButton.tintColor = offColor
        switchButton.isEnabled = isEnabled
        switchButton.disabledTapAction = disabledTapAction
        switchButton.setOn(on, animated: false)
    }
}
