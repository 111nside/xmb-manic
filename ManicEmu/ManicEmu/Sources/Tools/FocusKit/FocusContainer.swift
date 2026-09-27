//
//  FocusContainer.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

/// 容器内部消化方向键的结果
enum FocusContainerResult {
    /// 容器内部已处理，焦点落到返回的视图上
    /// （若目标 cell 尚未布局完成，容器可先返回自身，待布局后再应用视觉）
    case handled(UIView)
    /// 已到达容器边缘，交还给外层空间寻径引擎
    case exit
}

/// A container that can be entered as a focus level.
///
/// Page-level search flattens focusable descendants; the container view is
/// never a candidate. `UICollectionView` then isolates D-pad to item/IndexPath
/// search; each cell is a mini-page for its inner focusable views. Other
/// containers stay in the page-level pool and only receive enter/leave callbacks.
protocol FocusContainer: UIView {
    /// When true, D-pad stays inside this container until it returns `.exit`.
    /// `UICollectionView` isolates; generic containers stay in the page-level pool.
    var isolatesFocusNavigation: Bool { get }

    /// 容器当前是否可以被进入（例如 UICollectionView 无任何 item 时应返回 false）
    var canEnterFocus: Bool { get }

    /// 焦点从 direction 方向进入容器（nil 表示初始聚焦，无方向）。
    /// `preferred` 为页面级空间寻径命中的内部视图时，容器应优先落到该位置。
    /// 返回 nil 表示拒绝进入。
    func enterFocus(from direction: FocusDirection?, preferred: UIView?) -> UIView?

    /// 容器内部消化方向键
    func navigateFocus(_ direction: FocusDirection, current: UIView?) -> FocusContainerResult

    /// 容器内当前聚焦的后代视图（可能因滚动复用暂时为 nil）
    var currentFocusedDescendant: UIView? { get }

    /// 焦点记忆：焦点离开后再次进入时优先恢复的后代
    var lastFocusedDescendant: UIView? { get }

    /// 焦点离开容器（焦点记忆保留，视觉清除）
    func resignFocus()

    /// 确定键落在容器内部焦点上时的默认行为（如触发 didSelectItemAt），返回是否消费
    func performPrimaryActionOnFocused() -> Bool

    /// 焦点位于容器内部时生效的额外命令
    func containerFocusCommands() -> [FocusCommand]

    /// Window-space rect used when the container itself is the candidate (no
    /// flattened descendant). Prefer the entry slot over the full container
    /// frame so a full-screen list can still lose to a floating toolbar.
    func focusEntryFrame(from direction: FocusDirection) -> CGRect?
}

extension FocusContainer {
    var canEnterFocus: Bool { true }
    var isolatesFocusNavigation: Bool { false }
    func containerFocusCommands() -> [FocusCommand] { [] }
    func focusEntryFrame(from direction: FocusDirection) -> CGRect? { nil }

    func enterFocus(from direction: FocusDirection?) -> UIView? {
        enterFocus(from: direction, preferred: nil)
    }

    func enterFocus(from direction: FocusDirection?, preferred: UIView?) -> UIView? {
        _ = preferred
        return nil
    }
}
