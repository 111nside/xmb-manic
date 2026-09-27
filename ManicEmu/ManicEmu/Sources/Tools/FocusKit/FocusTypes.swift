//
//  FocusTypes.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

// MARK: - FocusKey

/// FocusKit 的输入按键抽象。
///
/// 内置六个默认键（上/下/左/右/确定/取消），它们自带默认行为；
/// 使用者可以自由扩展任意数量的自定义键，自定义键没有默认行为，只由 `FocusCommand` 驱动：
///
/// ```swift
/// extension FocusKey {
///     static let l2 = FocusKey("l2")
/// }
/// ```
struct FocusKey: Hashable, RawRepresentable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { self.rawValue = value }

    /// Direction: move focus
    static let up = FocusKey("up")
    static let down = FocusKey("down")
    static let left = FocusKey("left")
    static let right = FocusKey("right")
    /// Confirm: default is a click on the focused view
    static let a = FocusKey("a")
    /// Cancel: default dismisses the current page (sheet / ProHUD / navigation pop)
    static let b = FocusKey("b")
    /// Keyboard modifier; long-press shows the shortcut cheatsheet
    static let command = FocusKey("command")
    /// Keyboard modifier; long-press shows the shortcut cheatsheet
    static let control = FocusKey("control")
    /// Controller Select / View / − ; long-press shows the shortcut cheatsheet
    static let select = FocusKey("select")

    /// 若是方向键则返回对应方向
    var direction: FocusDirection? {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        default: return nil
        }
    }

    var description: String { rawValue }
}

// MARK: - FocusDirection

enum FocusDirection: CaseIterable {
    case up, down, left, right

    var opposite: FocusDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    var isHorizontal: Bool {
        self == .left || self == .right
    }
}

// MARK: - FocusPressType

/// 按压类型。
///
/// - `tap`：短按。在按键抬起（keyUp）时触发；若该键的长按已被消费则不触发。
/// - `longPress`：长按。按住超过 `FocusSystem.longPressDelay` 时触发。
///   方向键不支持长按命令（方向键按住的语义是加速连发导航）。
enum FocusPressType: Hashable {
    case tap
    case longPress
}

// MARK: - FocusCommand

/// 绑定在按键上的命令。可绑定默认键（拦截/干预默认行为）或自定义键。
///
/// `handler` 返回 `true` 表示消费该按键（默认行为不再执行）；
/// 返回 `false` 表示放行，事件继续沿命令链向下传递，最终执行默认行为。
///
/// 同一个键可以同时绑定 `.tap` 和 `.longPress` 两条命令；
/// 长按命令被消费后，本次按压抬起时不会再触发短按。
struct FocusCommand {
    let key: FocusKey
    /// 按压类型：短按（默认）或长按
    let pressType: FocusPressType
    /// 操作说明，如"打开侧边栏"，用于渲染当前页面的操作提示
    let title: String
    let handler: () -> Bool

    init(key: FocusKey, pressType: FocusPressType = .tap, title: String, handler: @escaping () -> Bool) {
        self.key = key
        self.pressType = pressType
        self.title = title
        self.handler = handler
    }

    /// 便捷构造：必定消费按键的命令
    init(key: FocusKey, pressType: FocusPressType = .tap, title: String, action: @escaping () -> Void) {
        self.init(key: key, pressType: pressType, title: title) {
            action()
            return true
        }
    }
}

// MARK: - FocusHint

/// 当前上下文可用操作的描述（供操作说明 HUD 渲染），
/// 例如 `keys: [.up, .down, .left, .right], title: "移动"`。
struct FocusHint: Hashable {
    let keys: [FocusKey]
    let title: String
    /// 短按或长按（HUD 可据此渲染"长按 X"样式）
    let pressType: FocusPressType

    init(keys: [FocusKey], title: String, pressType: FocusPressType = .tap) {
        self.keys = keys
        self.title = title
        self.pressType = pressType
    }
}
