//
//  TransparentHoleView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class TransparentHoleView: BaseView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(.dm, light: .white, dark: .black)
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = UIColor(.dm, light: .white, dark: .black)
        isUserInteractionEnabled = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        applyMask()
    }
    
    private func applyMask() {
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: bounds) // 背景填充全屏

        // 计算透明区域的矩形
        let transparentRect = self.bounds
        let transparentPath = UIBezierPath(roundedRect: transparentRect, cornerRadius: R.Size.CornerRadiusLarge*2)
        path.append(transparentPath)
        path.usesEvenOddFillRule = true
        
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        
        layer.mask = maskLayer
    }
}
