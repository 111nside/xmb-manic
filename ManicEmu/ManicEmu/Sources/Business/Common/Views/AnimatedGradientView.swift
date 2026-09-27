//
//  AnimatedGradientView.swift
//  ManicEmu
//
//  Created by Max on 2025/1/1.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ColorfulX

class AnimatedGradientView: AnimatedMulticolorGradientView {
    private var gradientColorChangeNotification: Any? = nil
    private var startGameNotification: Any? = nil
    private var stopGameNotification: Any? = nil
    
    deinit {
        if let gradientColorChangeNotification = gradientColorChangeNotification {
            NotificationCenter.default.removeObserver(gradientColorChangeNotification)
        }
        if let startGameNotification = startGameNotification {
            NotificationCenter.default.removeObserver(startGameNotification)
        }
        if let stopGameNotification = stopGameNotification {
            NotificationCenter.default.removeObserver(stopGameNotification)
        }
    }
    
    init(colors: [UIColor] = R.Color.Gradient, notifiedUpadate: Bool = false, alphaComponent: CGFloat = 1) {
        super.init(animationDirector: SpeckleAnimationRandomDirector())
        if alphaComponent > 0 && alphaComponent < 1 {
            self.setColors(colors.map({ $0.withAlphaComponent(alphaComponent) }), animated: false)
        } else {
            self.setColors(colors, animated: false)
        }
        self.speed = 1
        self.transitionSpeed = 10
        self.bias = 0.0025
        self.renderScale = 2
        self.frameLimit = 5
        
        if notifiedUpadate {
            gradientColorChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.GradientColorChange, object: nil, queue: .main) { [weak self] notification in
                guard let self = self else { return }
                if alphaComponent > 0 && alphaComponent < 1 {
                    self.setColors(R.Color.Gradient.map({ $0.withAlphaComponent(alphaComponent) }), animated: false)
                } else {
                    self.setColors(R.Color.Gradient, animated: false)
                }
            }
        }
        
        startGameNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.StartPlayGame, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.speed = 0
        }
        
        stopGameNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.StopPlayGame, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.speed = 1
        }
    }
}
