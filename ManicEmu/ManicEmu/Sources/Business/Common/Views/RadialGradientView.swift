//
//  RadialGradientView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import BlurUIKit

class RadialGradientView: BaseView {
    private var lastSize: CGSize? = nil
    private let imageView = UIImageView()
    private var gradientColorChangeNotification: Any? = nil
    private var appearanceChangeNotification: Any? = nil
    
    deinit {
        if let gradientColorChangeNotification {
            NotificationCenter.default.removeObserver(gradientColorChangeNotification)
        }
        if let appearanceChangeNotification {
            NotificationCenter.default.removeObserver(appearanceChangeNotification)
        }
    }
    
    init() {
        super.init(frame: .zero)
        addSubview(imageView)
        imageView.alpha = 0.3
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let view = BlurUIKit.VariableBlurView()
        view.maximumBlurRadius = 20
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.25, darkModeAlpha: 0.3)
        view.dimmingTintColor = R.Color.BackgroundSecondary
        addSubview(view)
        view.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(2)
        }
        
        gradientColorChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.GradientColorChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.updateImage()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let lastSize, lastSize == size { return }
        guard lastSize != .zero else { return }
        updateImage()
        lastSize = size
    }
    
    private func updateImage() {
        let size = CGSize(width: size.width*2/3, height: size.height)
        guard size != .zero else { return }
        let colors = R.Color.Gradient
        let startCenter = CGPoint(x: 0.5, y: 1)
        let startRadius = size.height/3
        let endRadius = size.height
        UIImage.radialGradientImage(size: size,
                                    colors: colors + [R.Color.BackgroundSecondary.forceStyle(.dark)],
                                    startCenter: startCenter,
                                    startRadius: startRadius,
                                    endRadius: endRadius) { [weak self] darkImage in
            UIImage.radialGradientImage(size: size,
                                        colors: colors + [R.Color.BackgroundSecondary.forceStyle(.light)],
                                        startCenter: startCenter,
                                        startRadius: startRadius,
                                        endRadius: endRadius) { [weak self] lightImage in
                if let darkImage, let lightImage {
                    self?.imageView.image = UIImage(.dm, light: lightImage, dark: darkImage)
                }
            }
        }
    }
}
