//
//  FocusContext.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ProHUD

/// 一个焦点作用域（"页面"）。
///
/// 不严格等于 UIViewController：present 的控制器、push 的控制器、
/// ProHUD 的 alert/sheet、侧边栏等都可以各自作为一个 context。
/// `FocusSystem` 以栈维护 context，只有栈顶 context 接收输入事件。
final class FocusContext {
    /// 焦点导航的根视图，候选收集默认在此子树内进行
    private(set) weak var rootView: UIView?

    /// Views that participate in page-level search even if they are not
    /// descendants of `rootView` (parent-owned chrome such as a tab bar).
    private var additionalSearchRootRefs: [WeakSearchRoot] = []

    private final class WeakSearchRoot {
        weak var view: UIView?
        let enterHeadings: Set<FocusDirection>
        init(_ view: UIView, enterHeadings: Set<FocusDirection>) {
            self.view = view
            self.enterHeadings = enterHeadings
        }
    }

    /// 页面拥有者（UIViewController / ProHUD 的 SheetTarget、AlertTarget 等），
    /// 用于取消键（b）的默认关闭行为
    private(set) weak var owner: AnyObject?

    /// 调试名称
    let name: String

    /// 页面级命令
    private(set) var commands: [FocusCommand] = []

    /// 取消键（b）的自定义处理，优先于 owner 的默认关闭行为。
    /// 可用于"关闭前弹出确认框"这类干预；返回 true 表示消费。
    var cancelHandler: (() -> Bool)?

    /// 指定初始焦点；返回 nil 时由引擎选择左上角最近的候选
    var preferredFocusView: (() -> UIView?)?

    /// 焦点变化回调（本 context 处于栈顶时触发）。
    /// - `focusedView`：新获得焦点的视图；焦点被移除或导航受阻时为 nil。
    /// - `attemptedDirection`：触发本次变化的导航方向。方向键导航（含成功落焦与屏内无目标）
    ///   时必有值；程序调用 `focus(_:)`、自动建立/恢复初始焦点、清除焦点等场景为 nil。
    var onFocusChange: ((_ focusedView: UIView?, _ attemptedDirection: FocusDirection?) -> Void)?

    /// context 成为栈顶时是否自动建立初始焦点（默认 false）。
    /// 即便为 true，也只有在已接入手柄/外接键盘时才会真正落焦。
    var autoFocusOnActivate = false

    /// 焦点记忆：context 被覆盖后重新回到栈顶时优先恢复
    weak var lastFocusedView: UIView?

    init(rootView: UIView, owner: AnyObject? = nil, name: String = "") {
        self.rootView = rootView
        self.owner = owner
        self.name = name.isEmpty ? String(describing: type(of: rootView)) : name
    }

    // MARK: - 命令管理

    func addCommand(_ command: FocusCommand) {
        commands.append(command)
    }

    func addCommands(_ newCommands: [FocusCommand]) {
        commands.append(contentsOf: newCommands)
    }

    func removeCommands(for key: FocusKey) {
        commands.removeAll { $0.key == key }
    }

    func removeAllCommands() {
        commands.removeAll()
    }

    /// Register chrome that should compete in this page's directional search.
    /// `enterHeadings` limits which D-pad directions may land in that chrome
    /// (bottom tab bar: `.down` only, so left/right/up stay in page content).
    func addAdditionalSearchRoot(_ view: UIView, enterHeadings: Set<FocusDirection> = [.down]) {
        additionalSearchRootRefs.removeAll { $0.view == nil || $0.view === view }
        additionalSearchRootRefs.append(WeakSearchRoot(view, enterHeadings: enterHeadings))
    }

    var additionalSearchRoots: [UIView] {
        additionalSearchRootRefs.compactMap(\.view)
    }

    func additionalSearchRoots(entering direction: FocusDirection) -> [UIView] {
        additionalSearchRootRefs.compactMap { ref in
            guard let view = ref.view, ref.enterHeadings.contains(direction) else { return nil }
            return view
        }
    }

    /// Whether `view` belongs to this page: `rootView` or an additional search root.
    func contains(_ view: UIView) -> Bool {
        if let root = rootView, view === root || view.isDescendant(of: root) {
            return true
        }
        for extra in additionalSearchRoots {
            if view === extra || view.isDescendant(of: extra) {
                return true
            }
        }
        return false
    }

    // MARK: - 取消键默认行为

    /// 取消键（b）处理：cancelHandler 优先，未消费则按 owner 类型执行默认关闭
    @discardableResult
    func performCancel() -> Bool {
        if let cancelHandler, cancelHandler() {
            return true
        }
        return performDefaultClose()
    }

    private func performDefaultClose() -> Bool {
        // ProHUD 的 alert / sheet
        if let sheet = owner as? SheetTarget {
            sheet.pop()
            return true
        }
        if let alert = owner as? AlertTarget {
            alert.pop()
            return true
        }
        // UIViewController：present 的 dismiss，push 的 pop
        if let viewController = owner as? UIViewController {
            if viewController.presentingViewController != nil, viewController.navigationController == nil {
                viewController.dismiss(animated: true)
                return true
            }
            if let navigationController = viewController.navigationController {
                if navigationController.viewControllers.count > 1,
                   navigationController.topViewController === viewController {
                    navigationController.popViewController(animated: true)
                    return true
                }
                // 整个导航栈是被 present 出来的
                if navigationController.presentingViewController != nil {
                    navigationController.dismiss(animated: true)
                    return true
                }
            }
        }
        // 根页面等不该被关闭的场景：不消费
        return false
    }
}
