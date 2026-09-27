//
//  UIScrollViewExtensions.swift
//  ManicEmu
//
//  Created on 2025-10-12.
//

import UIKit
import ObjectiveC

extension UIScrollView {
    
    // MARK: - Swizzle Methods
    
    /// 确保 swizzle 只执行一次
    private static var hasSwizzled = false
    
    /// 公共方法：调用此方法来激活 swizzle（需要在应用启动时调用）
    @objc public static func disableEdgeEffect() {
        guard !hasSwizzled else { return }
        hasSwizzled = true
        
        swizzleInitMethods()
    }
    
    /// 执行方法交换
    private static func swizzleInitMethods() {
        // Swizzle init(frame:)
        let originalInitSelector = #selector(UIScrollView.init(frame:))
        let swizzledInitSelector = #selector(UIScrollView.swizzled_init(frame:))
        
        guard let originalMethod = class_getInstanceMethod(UIScrollView.self, originalInitSelector),
              let swizzledMethod = class_getInstanceMethod(UIScrollView.self, swizzledInitSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
        
        // Swizzle init(coder:)
        let originalCoderSelector = #selector(UIScrollView.init(coder:))
        let swizzledCoderSelector = #selector(UIScrollView.swizzled_init(coder:))
        
        guard let originalCoderMethod = class_getInstanceMethod(UIScrollView.self, originalCoderSelector),
              let swizzledCoderMethod = class_getInstanceMethod(UIScrollView.self, swizzledCoderSelector) else {
            return
        }
        
        method_exchangeImplementations(originalCoderMethod, swizzledCoderMethod)
    }
    
    // MARK: - Swizzled Initializers
    
    /// Swizzled init(frame:) 方法
    @objc private dynamic func swizzled_init(frame: CGRect) -> UIScrollView {
        // 调用原始方法（由于已经交换，这里实际调用的是原始的 init(frame:)）
        let scrollView = self.swizzled_init(frame: frame)
        scrollView.hideEdgeEffects()
        return scrollView
    }
    
    /// Swizzled init(coder:) 方法
    @objc private dynamic func swizzled_init(coder: NSCoder) -> UIScrollView? {
        // 调用原始方法（由于已经交换，这里实际调用的是原始的 init(coder:)）
        let scrollView = self.swizzled_init(coder: coder)
        scrollView?.hideEdgeEffects()
        return scrollView
    }
    
    // MARK: - Helper Methods
    
    /// 隐藏边缘效果（iOS 26.0+）
    private func hideEdgeEffects() {
        if #available(iOS 26.0, tvOS 26.0, *) {
             self.topEdgeEffect.isHidden = true
             self.leftEdgeEffect.isHidden = true
             self.bottomEdgeEffect.isHidden = true
             self.rightEdgeEffect.isHidden = true
        }
    }
}

