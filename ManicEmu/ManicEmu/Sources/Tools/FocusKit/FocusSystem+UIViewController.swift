//
//  FocusSystem+UIViewController.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

/// UIViewController 便捷接入（可选使用）。
///
/// 典型用法：
/// ```swift
/// override func viewDidAppear(_ animated: Bool) {
///     super.viewDidAppear(animated)
///     pushFocusContext { context in
///         context.addCommand(FocusCommand(key: .l2, title: "侧边栏") { ... })
///     }
/// }
///
/// override func viewWillDisappear(_ animated: Bool) {
///     super.viewWillDisappear(animated)
///     popFocusContext()
/// }
/// ```
private var FocusContextAssociationKey: UInt8 = 0

extension UIViewController {
    /// 与该控制器绑定的 FocusContext（首次访问时创建，rootView 为 self.view，owner 为 self）
    var focusContext: FocusContext {
        if let context = objc_getAssociatedObject(self, &FocusContextAssociationKey) as? FocusContext {
            return context
        }
        let context = FocusContext(rootView: view, owner: self, name: String(describing: type(of: self)))
        objc_setAssociatedObject(self, &FocusContextAssociationKey, context, .OBJC_ASSOCIATION_RETAIN)
        return context
    }

    /// 是否已创建过 focusContext（避免只为查询而意外创建）
    var hasFocusContext: Bool {
        objc_getAssociatedObject(self, &FocusContextAssociationKey) != nil
    }

    /// 将该控制器的 context 推入焦点栈（建议在 viewDidAppear 调用）。
    /// - Parameter configure: 首次创建时的配置回调（注册页面命令、preferredFocusView 等）
    func pushFocusContext(configure: ((FocusContext) -> Void)? = nil) {
        let isFirstAccess = !hasFocusContext
        let context = focusContext
        if isFirstAccess {
            configure?(context)
        }
        FocusSystem.shared.push(context)
    }

    /// 将此控制器设为栈底焦点根（Home Tab 等同级切换）。覆盖层仍留在其上方。
    func activateFocusRoot(configure: ((FocusContext) -> Void)? = nil) {
        let isFirstAccess = !hasFocusContext
        let context = focusContext
        if isFirstAccess {
            configure?(context)
        }
        FocusSystem.shared.replaceRoot(with: context)
    }

    /// Present / ProHUD 覆盖层：推入 context。
    /// 仅在已接入手柄/外接键盘时自动落焦；未接入时与首页一样，等第一次方向键再建立焦点。
    func pushOverlayFocusContext(configure: ((FocusContext) -> Void)? = nil) {
        pushFocusContext { context in
            context.autoFocusOnActivate = true
            configure?(context)
        }
    }

    /// 将该控制器的 context 移出焦点栈（建议在 viewWillDisappear 调用）
    func popFocusContext() {
        guard hasFocusContext else { return }
        FocusSystem.shared.pop(focusContext)
    }
}
