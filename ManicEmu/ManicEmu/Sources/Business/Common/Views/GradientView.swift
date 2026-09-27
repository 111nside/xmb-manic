//
//  GradientView.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/5/11.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class GradientView: BaseView {
    private let gradientLayer = CAGradientLayer()
    private var colors: [UIColor] = []

    func setupGradient(colors: [UIColor], locations: [CGFloat] = [0.0, 1.0], direction: GradientDirection) {
        self.colors = colors
        gradientLayer.frame = bounds
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.locations = locations.map { NSNumber(value: $0) }
        gradientLayer.startPoint = direction.startPoint
        gradientLayer.endPoint = direction.endPoint
        if let _ = gradientLayer.superlayer { } else {
            layer.addSublayer(gradientLayer)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            gradientLayer.colors = colors.map(\.cgColor)
        }
    }
}
