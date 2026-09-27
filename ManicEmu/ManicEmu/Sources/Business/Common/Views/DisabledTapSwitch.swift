//
//  DisabledTapSwitch.swift
//  ManicEmu
//
//  Created by Aoshuang on 2025/10/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit

class DisabledTapSwitch: UISwitch {
    var disabledTapAction: (() -> Void)?
    
    // 透明覆盖视图，用于在禁用状态下捕获点击
    private lazy var overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap))
        view.addGestureRecognizer(tapGesture)
        return view
    }()
    
    override var isEnabled: Bool {
        didSet {
            updateOverlayView()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlayView()
        isFocusable = true
        onFocusConfirm = { [weak self] in
            guard let self else { return false }
            if self.isEnabled {
                self.setOn(!self.isOn, animated: true)
                self.sendActions(for: .valueChanged)
            } else {
                self.disabledTapAction?()
            }
            return true
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlayView()
        isFocusable = true
        onFocusConfirm = { [weak self] in
            guard let self else { return false }
            if self.isEnabled {
                self.setOn(!self.isOn, animated: true)
                self.sendActions(for: .valueChanged)
            } else {
                self.disabledTapAction?()
            }
            return true
        }
    }
    
    private func setupOverlayView() {
        // 将覆盖视图添加到父视图，而不是 switch 本身
        // 在 layoutSubviews 中设置正确的位置和大小
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if let superview = superview {
            // 将覆盖视图添加到父视图
            superview.addSubview(overlayView)
            updateOverlayView()
        } else {
            overlayView.removeFromSuperview()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 更新覆盖视图的位置和大小以匹配 switch
        if overlayView.superview != nil {
            overlayView.frame = frame
        }
    }
    
    private func updateOverlayView() {
        // 只在禁用状态下显示覆盖视图
        overlayView.isHidden = isEnabled
    }
    
    @objc private func handleOverlayTap() {
        disabledTapAction?()
    }
    
    func onDisableTap(handler: (() -> Void)? = nil) {
        self.disabledTapAction = handler
    }
    
    deinit {
        overlayView.removeFromSuperview()
    }
}
