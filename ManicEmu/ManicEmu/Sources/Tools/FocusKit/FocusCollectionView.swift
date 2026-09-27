//
//  FocusCollectionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

/// UICollectionView 的焦点容器适配。
///
/// 无需子类替换：任意集合视图设置 `collectionView.isFocusable = true` 即作为容器参与导航。
/// 焦点进入容器时不高亮容器本身，而是寻找合适的 cell / header / footer 进行聚焦。
///
/// 设计要点：
/// - 焦点锚点：`FocusedElement`（cell 或 supplementary），视觉通过 `focusEffect` 呈现。
/// - cell / header / footer 均可聚焦整体或其内部 `isFocusable` 子视图。
/// - Item-to-item search uses layout frames + IndexPath. A cell is focused first;
///   down/right then enters inner controls, which keep four-way navigation until
///   that heading is empty and focus leaves the cell.
/// - Vertical collections center the focused item; horizontal / orthogonal
///   scrollers use a minimum reveal so a strip does not jump.

// MARK: - 配置属性

private var FocusCollectionCoordinatorKey: UInt8 = 0
private var FocusOrthogonalProviderKey: UInt8 = 0
private var FocusCellFilterKey: UInt8 = 0
private var FocusOrthogonalWrapsKey: UInt8 = 0

/// 集合视图内的焦点锚点：普通 cell 或 section header/footer
private enum FocusedElement: Hashable {
    case cell(IndexPath)
    case supplementary(kind: String, section: Int)

    var section: Int {
        switch self {
        case .cell(let indexPath): return indexPath.section
        case .supplementary(_, let section): return section
        }
    }
}

extension UICollectionView {
    var focusOrthogonalSectionProvider: ((_ section: Int) -> Bool)? {
        get { objc_getAssociatedObject(self, &FocusOrthogonalProviderKey) as? (Int) -> Bool }
        set { objc_setAssociatedObject(self, &FocusOrthogonalProviderKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    var focusCellFilter: ((_ indexPath: IndexPath) -> Bool)? {
        get { objc_getAssociatedObject(self, &FocusCellFilterKey) as? (IndexPath) -> Bool }
        set { objc_setAssociatedObject(self, &FocusCellFilterKey, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    var focusOrthogonalWraps: Bool {
        get { (objc_getAssociatedObject(self, &FocusOrthogonalWrapsKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &FocusOrthogonalWrapsKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    /// 当前聚焦的 cell indexPath（焦点在 header/footer 上时为 nil）
    var focusedIndexPath: IndexPath? {
        focusCoordinator.focusedIndexPath
    }

    fileprivate var focusCoordinator: FocusCollectionCoordinator {
        if let coordinator = objc_getAssociatedObject(self, &FocusCollectionCoordinatorKey) as? FocusCollectionCoordinator {
            return coordinator
        }
        let coordinator = FocusCollectionCoordinator(collectionView: self)
        objc_setAssociatedObject(self, &FocusCollectionCoordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN)
        return coordinator
    }
}

// MARK: - FocusContainer 实现

extension UICollectionView: FocusContainer {
    var canEnterFocus: Bool {
        guard window != nil, !isHidden, alpha > 0.01 else { return false }
        return focusCoordinator.firstFocusableElement() != nil
    }

    var isolatesFocusNavigation: Bool { true }

    func enterFocus(from direction: FocusDirection?, preferred: UIView?) -> UIView? {
        focusCoordinator.enter(from: direction, preferred: preferred)
    }

    func navigateFocus(_ direction: FocusDirection, current: UIView?) -> FocusContainerResult {
        focusCoordinator.navigate(direction)
    }

    var currentFocusedDescendant: UIView? {
        if let target = focusCoordinator.focusedTarget { return target }
        return focusCoordinator.hostViewForFocusedElement()
    }

    var lastFocusedDescendant: UIView? {
        focusCoordinator.hostViewForLastFocusedElement()
    }

    func resignFocus() {
        focusCoordinator.resign()
    }

    func performPrimaryActionOnFocused() -> Bool {
        focusCoordinator.performPrimaryAction()
    }

    func focusEntryFrame(from direction: FocusDirection) -> CGRect? {
        focusCoordinator.entryFrameInWindow(from: direction)
    }

    func containerFocusCommands() -> [FocusCommand] {
        focusCoordinator.containerFocusCommands()
    }
}

// MARK: - Coordinator

private final class FocusCollectionCoordinator: NSObject {
    private(set) var focusedElement: FocusedElement?
    private(set) var lastFocusedElement: FocusedElement?
    private(set) weak var focusedTarget: UIView?
    private weak var focusedHost: UIView?
    private weak var collectionView: UICollectionView?
    private var contentOffsetObservation: NSKeyValueObservation?

    private var pendingEntryDirection: FocusDirection?
    private var pendingEntryOriginFrame: CGRect?
    private weak var pendingPreferredInner: UIView?
    /// Last inner focus per item. Re-entering that item restores it (cell as container).
    private var lastInnerByElement: [FocusedElement: WeakView] = [:]
    private var pendingProbe: (element: FocusedElement, direction: FocusDirection?, originFrame: CGRect?)?
    private var scrollAnchor: FocusedElement?

    private final class WeakView {
        weak var view: UIView?
        init(_ view: UIView) { self.view = view }
    }

    var focusedIndexPath: IndexPath? {
        if case .cell(let indexPath)? = focusedElement { return indexPath }
        return nil
    }

    var lastFocusedIndexPath: IndexPath? {
        if case .cell(let indexPath)? = lastFocusedElement { return indexPath }
        return nil
    }

    init(collectionView: UICollectionView) {
        self.collectionView = collectionView
        super.init()
        contentOffsetObservation = collectionView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            self?.reconcileFocusVisual()
        }
    }

    deinit {
        contentOffsetObservation?.invalidate()
    }

    // MARK: 进入 / 离开

    func enter(from direction: FocusDirection?, preferred: UIView? = nil) -> UIView? {
        guard let collectionView else { return nil }

        if let preferred, preferred !== collectionView,
           let element = focusedElement(containing: preferred), isFocusableElement(element) {
            switch moveTo(
                element,
                direction: direction,
                originFrame: FocusEngine.frameInWindow(of: preferred),
                shouldFocus: true,
                preferredInner: preferred
            ) {
            case .handled(let view): return view
            case .exit: return collectionView
            }
        }

        var target: FocusedElement?
        if let remembered = lastFocusedElement, isElementVisible(remembered), isFocusableElement(remembered) {
            target = remembered
        } else {
            target = entryElement(from: direction)
        }
        guard let target else { return collectionView }

        switch moveTo(target, direction: direction, originFrame: nil, shouldFocus: true) {
        case .handled(let view): return view
        case .exit: return collectionView
        }
    }

    func resign() {
        cancelInternalFocus()
        pendingProbe = nil
        scrollAnchor = nil
    }

    func hostViewForFocusedElement() -> UIView? {
        guard let element = focusedElement else { return nil }
        return hostView(for: element)
    }

    func hostViewForLastFocusedElement() -> UIView? {
        guard let element = lastFocusedElement else { return nil }
        return hostView(for: element)
    }

    func containerFocusCommands() -> [FocusCommand] {
        guard let host = focusedHost, let target = focusedTarget, target !== host else { return [] }
        return host.focusCommands
    }

    private func cancelInternalFocus() {
        if let focusedTarget {
            focusedTarget.fk_applyFocus(false)
        } else if let element = focusedElement, let host = hostView(for: element) {
            host.fk_applyFocus(false)
        }
        focusedTarget = nil
        focusedHost = nil
        focusedElement = nil
        pendingEntryDirection = nil
        pendingEntryOriginFrame = nil
        pendingPreferredInner = nil
    }

    // MARK: 方向导航

    func navigate(_ direction: FocusDirection) -> FocusContainerResult {
        guard let _ = collectionView else { return .exit }

        let position = focusedElement ?? scrollAnchor

        guard let current = position, isValidElement(current) else {
            cancelInternalFocus()
            scrollAnchor = nil
            pendingProbe = nil
            guard let target = entryElement(from: direction) else { return .exit }
            return moveTo(target, direction: direction, originFrame: nil, shouldFocus: true)
        }

        // Cell is focused first. Down/right may enter inner items; once inside,
        // all four directions stay among inners until that heading is empty.
        if let element = focusedElement,
           let host = hostView(for: element) {
            let current = focusedTarget ?? host
            let insideCell = current !== host && current.isDescendant(of: host)
            if insideCell {
                if let next = FocusEngine.nextCandidate(
                    from: current,
                    direction: direction,
                    insideHost: host
                ) {
                    moveFocusInsideCell(from: current, to: next, host: host, element: element)
                    return .handled(next)
                }
            } else if direction == .down || direction == .right,
                      let next = firstInner(in: host, from: direction) {
                moveFocusInsideCell(from: current, to: next, host: host, element: element)
                return .handled(next)
            }
        }

        guard let resolved = resolveNavigationTarget(from: current, direction: direction) else {
            return .exit
        }
        let originFrame = focusedTarget.map { FocusEngine.frameInWindow(of: $0) }
            ?? cellFrameInWindow(for: current)
        return moveTo(resolved.element, direction: direction, originFrame: originFrame, shouldFocus: resolved.shouldFocus)
    }

    private func cellFrameInWindow(for element: FocusedElement) -> CGRect? {
        guard let collectionView, let window = collectionView.window,
              let attributes = layoutAttributes(for: element) else {
            return focusedTarget.map { FocusEngine.frameInWindow(of: $0) }
        }
        return collectionView.convert(attributes.frame, to: window)
    }

    private func resolveNavigationTarget(from start: FocusedElement, direction: FocusDirection) -> (element: FocusedElement, shouldFocus: Bool)? {
        guard let collectionView else { return nil }

        if case .cell(let startIndexPath) = start,
           collectionView.focusOrthogonalSectionProvider?(startIndexPath.section) == true {
            return resolveOrthogonalNavigation(from: startIndexPath, direction: direction)
        }

        guard let _ = layoutAttributes(for: start) else { return nil }
        guard let next = nextElement(from: start, direction: direction) else { return nil }
        if let _ = hostView(for: next) {
            return (next, isFocusableElement(next))
        }
        return (next, isNavigableElement(next))
    }

    private func resolveOrthogonalNavigation(from start: IndexPath, direction: FocusDirection) -> (element: FocusedElement, shouldFocus: Bool)? {
        switch direction {
        case .left, .right:
            guard let next = adjacentItem(from: start, direction: direction) else { return nil }
            return (FocusedElement.cell(next), isFocusableElement(.cell(next)) || hostView(for: .cell(next)) == nil)
        case .up, .down:
            guard let next = arithmeticNextSection(from: start, direction: direction) else { return nil }
            let element = FocusedElement.cell(next)
            return (element, isFocusableElement(element) || hostView(for: element) == nil)
        }
    }

    private func moveTo(
        _ element: FocusedElement,
        direction: FocusDirection?,
        originFrame: CGRect?,
        shouldFocus: Bool,
        preferredInner: UIView? = nil
    ) -> FocusContainerResult {
        guard let collectionView else { return .exit }

        lastFocusedElement = element
        scrollToReveal(element)

        if shouldFocus, let host = hostView(for: element), isFocusableElement(element) {
            pendingProbe = nil
            scrollAnchor = nil
            focus(
                element,
                direction: direction,
                originFrame: originFrame,
                preferredInner: preferredInner,
                scroll: false
            )
            return .handled(focusedTarget ?? host)
        }

        cancelInternalFocus()
        scrollAnchor = element
        pendingProbe = shouldFocus && hostView(for: element) == nil
            ? (element, direction, originFrame)
            : nil
        return .handled(collectionView)
    }

    private func scrollToReveal(_ element: FocusedElement) {
        scrollToMakeVisible(element, focusedView: nil, animated: true)
    }

    private func scrollToMakeVisible(_ element: FocusedElement, focusedView: UIView?, animated: Bool = true) {
        guard let collectionView else { return }

        if let target = focusedView ?? hostView(for: element) {
            revealInEnclosingScrollers(target, element: element, animated: animated)
            return
        }

        if case .cell(let indexPath) = element {
            if isPrimarilyVertical(collectionView) {
                collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: animated)
            } else {
                collectionView.scrollToItem(at: indexPath, at: [], animated: animated)
            }
            return
        }

        guard let attributes = layoutAttributes(for: element) else { return }
        if isPrimarilyVertical(collectionView) {
            centerVertically(attributes.frame, in: collectionView, animated: animated)
        } else {
            revealRect(attributes.frame.insetBy(dx: -8, dy: -8), in: collectionView, animated: animated)
        }
    }

    /// Nested horizontal scrollers: minimum reveal. This collection, if it
    /// scrolls vertically, centers the item. Stops here so a parent pager
    /// (Home `PageContentView`) is not moved.
    private func revealInEnclosingScrollers(_ view: UIView, element: FocusedElement, animated: Bool) {
        var current: UIView? = view.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView, !scrollView.isPagingEnabled {
                if scrollView === collectionView {
                    revealInCollection(view, element: element, animated: animated)
                } else if isPrimarilyHorizontal(scrollView) || isPrimarilyVertical(scrollView) {
                    let frame = view.convert(view.bounds, to: scrollView).insetBy(dx: -8, dy: -8)
                    revealRect(frame, in: scrollView, animated: animated)
                }
            }
            if candidate === collectionView { break }
            current = candidate.superview
        }
    }

    private func revealInCollection(_ view: UIView, element: FocusedElement, animated: Bool) {
        guard let collectionView else { return }
        if isPrimarilyVertical(collectionView) {
            switch element {
            case .cell(let indexPath):
                collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: animated)
            case .supplementary:
                centerVertically(view.convert(view.bounds, to: collectionView), in: collectionView, animated: animated)
            }
            return
        }
        let frame = view.convert(view.bounds, to: collectionView).insetBy(dx: -8, dy: -8)
        revealRect(frame, in: collectionView, animated: animated)
    }

    /// True when this scroller's extra content is mainly on X (orthogonal strips).
    private func isPrimarilyHorizontal(_ scrollView: UIScrollView) -> Bool {
        let extraX = scrollView.contentSize.width - scrollView.bounds.width
        let extraY = scrollView.contentSize.height - scrollView.bounds.height
        return extraX > 1 && extraX > extraY
    }

    /// True when this scroller's extra content is mainly on Y (game grids, lists).
    private func isPrimarilyVertical(_ scrollView: UIScrollView) -> Bool {
        let extraX = scrollView.contentSize.width - scrollView.bounds.width
        let extraY = scrollView.contentSize.height - scrollView.bounds.height
        return extraY > 1 && extraY >= extraX
    }

    private func centerVertically(_ rect: CGRect, in scrollView: UIScrollView, animated: Bool) {
        let inset = scrollView.adjustedContentInset
        let visibleHeight = scrollView.bounds.height - inset.top - inset.bottom
        guard visibleHeight > 0.5 else { return }
        let minOffset = -inset.top
        let maxOffset = max(minOffset, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
        var offset = scrollView.contentOffset
        offset.y = min(max(rect.midY - visibleHeight / 2 - inset.top, minOffset), maxOffset)
        guard abs(offset.y - scrollView.contentOffset.y) > 0.5 else { return }
        scrollView.setContentOffset(offset, animated: animated)
    }

    private func revealRect(_ rect: CGRect, in scrollView: UIScrollView, animated: Bool) {
        let visible = scrollView.bounds.inset(by: scrollView.adjustedContentInset)
        guard !visible.contains(rect) else { return }
        scrollView.scrollRectToVisible(rect, animated: animated)
    }

    // MARK: 确定键

    func performPrimaryAction() -> Bool {
        guard let collectionView, let element = focusedElement, isValidElement(element) else { return false }
        let host = hostView(for: element)

        if let inner = focusedTarget, let host, inner !== host, inner.isDescendant(of: host) {
            // Nested collection cells are also descendants of this cell. Confirm
            // belongs to that inner collection, not the inner-control chain.
            if confirmNestedCollectionItem(inner, owner: collectionView) {
                return true
            }
            return inner.fk_performPrimaryAction()
        }

        if let host, let onConfirm = host.onFocusConfirm, onConfirm() {
            return true
        }

        if case .cell(let indexPath) = element {
            return notifyDidSelect(in: collectionView, at: indexPath)
        }
        return false
    }

    /// When focus sits on another collection's cell (not a widget inside it),
    /// run that collection's confirm path: cell `onFocusConfirm`, then `didSelect`.
    private func confirmNestedCollectionItem(_ view: UIView, owner: UICollectionView) -> Bool {
        var current: UIView? = view
        while let candidate = current, candidate !== owner {
            if let cell = candidate as? UICollectionViewCell,
               let nested = owningCollectionView(of: cell),
               nested !== owner {
                guard view === cell else { return false }
                if let onConfirm = cell.onFocusConfirm, onConfirm() {
                    return true
                }
                guard let indexPath = nested.indexPath(for: cell) else { return false }
                return notifyDidSelect(in: nested, at: indexPath)
            }
            current = candidate.superview
        }
        return false
    }

    private func owningCollectionView(of cell: UICollectionViewCell) -> UICollectionView? {
        var current: UIView? = cell.superview
        while let view = current {
            if let collectionView = view as? UICollectionView { return collectionView }
            current = view.superview
        }
        return nil
    }

    private func notifyDidSelect(in collectionView: UICollectionView, at indexPath: IndexPath) -> Bool {
        guard let delegate = collectionView.delegate,
              delegate.responds(to: #selector(UICollectionViewDelegate.collectionView(_:didSelectItemAt:))) else {
            return false
        }
        delegate.collectionView?(collectionView, didSelectItemAt: indexPath)
        return true
    }

    // MARK: 聚焦

    private func focus(
        _ element: FocusedElement,
        direction: FocusDirection?,
        originFrame: CGRect?,
        preferredInner: UIView? = nil,
        scroll: Bool = true
    ) {
        if focusedElement != element, let focusedTarget {
            focusedTarget.fk_applyFocus(false)
            self.focusedTarget = nil
            self.focusedHost = nil
        }
        focusedElement = element
        lastFocusedElement = element
        pendingEntryDirection = direction
        pendingEntryOriginFrame = originFrame
        pendingPreferredInner = preferredInner
        if scroll {
            scrollToMakeVisible(element, focusedView: nil)
        }
        reconcileFocusVisual()
    }

    private func reconcileFocusVisual() {
        resolvePendingProbeIfPossible()
        guard let _ = collectionView, let element = focusedElement else { return }

        let currentHost = hostView(for: element)

        if let oldHost = focusedHost, oldHost !== currentHost {
            focusedTarget?.fk_applyFocus(false)
            if let focusedTarget, focusedTarget !== oldHost {
                oldHost.fk_applyFocus(false)
            }
            focusedTarget = nil
            focusedHost = nil
        }

        guard let currentHost else {
            focusedTarget = nil
            focusedHost = nil
            return
        }

        var target = focusedTarget
        if target == nil || (target !== currentHost && !(target!.isDescendant(of: currentHost))) {
            target = resolveFocusTarget(in: currentHost)
        }
        guard let target else {
            focusedTarget?.fk_applyFocus(false)
            focusedTarget = nil
            focusedHost = nil
            scrollAnchor = element
            focusedElement = nil
            pendingPreferredInner = nil
            pendingEntryDirection = nil
            pendingEntryOriginFrame = nil
            return
        }

        if focusedTarget !== target || !target.focusEffect {
            target.fk_applyFocus(true)
        }
        focusedHost = currentHost
        focusedTarget = target
        if let element = focusedElement {
            rememberInner(target, for: element)
        }
        pendingPreferredInner = nil
        pendingEntryDirection = nil
        pendingEntryOriginFrame = nil
    }

    private func resolvePendingProbeIfPossible() {
        guard let collectionView, let probe = pendingProbe else { return }
        guard hostView(for: probe.element) != nil else { return }
        pendingProbe = nil

        guard isFocusableElement(probe.element) else { return }
        scrollAnchor = nil
        focus(probe.element, direction: probe.direction, originFrame: probe.originFrame, scroll: false)
        FocusSystem.shared.containerDidUpdateFocus(collectionView, direction: probe.direction)
    }

    private func resolveFocusTarget(in host: UIView) -> UIView? {
        if host.fk_canFocus {
            return host
        }
        let candidates = focusableTargets(in: host)
        guard !candidates.isEmpty else { return nil }

        if let preferred = pendingPreferredInner, isValidInner(preferred, host: host, candidates: candidates) {
            return preferred
        }
        if let element = focusedElement,
           let remembered = lastInner(for: element),
           isValidInner(remembered, host: host, candidates: candidates) {
            return remembered
        }
        if let direction = pendingEntryDirection, let origin = pendingEntryOriginFrame,
           let best = FocusEngine.bestCandidate(
            from: origin,
            direction: direction,
            candidates: candidates,
            searchBounds: FocusEngine.frameInWindow(of: host),
            expandPolicy: .verticalOnly,
            geometry: .viewFrame
           ) {
            return best
        }
        return FocusEngine.topLeadingCandidate(among: candidates)
    }

    private func focusableTargets(in host: UIView) -> [UIView] {
        var candidates = FocusEngine.collectFocusableDescendants(in: host)
        if host.fk_canFocus {
            candidates.append(host)
        }
        var seen = Set<ObjectIdentifier>()
        var resolved: [UIView] = []
        resolved.reserveCapacity(candidates.count)
        for view in candidates {
            if seen.insert(ObjectIdentifier(view)).inserted {
                resolved.append(view)
            }
        }
        return resolved
    }

    private func lastInner(for element: FocusedElement) -> UIView? {
        lastInnerByElement[element]?.view
    }

    private func rememberInner(_ view: UIView, for element: FocusedElement) {
        lastInnerByElement[element] = WeakView(view)
    }

    private func isValidInner(_ view: UIView, host: UIView, candidates: [UIView]) -> Bool {
        guard view === host || view.isDescendant(of: host) else { return false }
        return candidates.contains { $0 === view }
    }

    /// Enter an inner control from a focused cell. Origin is the cell's top-leading
    /// corner so inners inside the cell frame still count as down/right.
    private func firstInner(in host: UIView, from direction: FocusDirection) -> UIView? {
        let inners = FocusEngine.collectFocusableDescendants(in: host)
        guard !inners.isEmpty else { return nil }
        let hostFrame = FocusEngine.frameInWindow(of: host)
        let origin = CGRect(x: hostFrame.minX, y: hostFrame.minY, width: 1, height: 1)
        return FocusEngine.bestCandidate(
            from: origin,
            direction: direction,
            candidates: inners,
            searchBounds: hostFrame,
            expandPolicy: .all,
            geometry: .viewFrame
        ) ?? FocusEngine.topLeadingCandidate(among: inners)
    }

    private func moveFocusInsideCell(from current: UIView, to next: UIView, host: UIView, element: FocusedElement) {
        if current !== next {
            current.fk_applyFocus(false)
        }
        next.fk_applyFocus(true)
        rememberInner(next, for: element)
        focusedTarget = next
        focusedHost = host
        scrollToMakeVisible(element, focusedView: next)
    }

    // MARK: 可视区 / 滚动

    private func isElementVisible(_ element: FocusedElement) -> Bool {
        guard let collectionView,
              let attributes = layoutAttributes(for: element) else { return false }
        let visible = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
        return attributes.frame.intersects(visible)
    }

    func entryFrameInWindow(from direction: FocusDirection) -> CGRect? {
        guard let collectionView, let window = collectionView.window else { return nil }

        let element: FocusedElement?
        if let remembered = lastFocusedElement, isElementVisible(remembered), isFocusableElement(remembered) {
            element = remembered
        } else {
            element = entryElement(from: direction)
        }
        if let element,
           let attributes = layoutAttributes(for: element) {
            return collectionView.convert(attributes.frame, to: window)
        }
        let frame = FocusEngine.frameInWindow(of: collectionView)
        return CGRect(x: frame.midX, y: frame.midY, width: 1, height: 1)
    }

    // MARK: 寻径

    private func nextElement(from current: FocusedElement, direction: FocusDirection) -> FocusedElement? {
        guard let collectionView else { return nil }

        if case .cell(let indexPath) = current,
           collectionView.focusOrthogonalSectionProvider?(indexPath.section) == true {
            switch direction {
            case .left, .right:
                return adjacentItem(from: indexPath, direction: direction).map { .cell($0) }
            case .up, .down:
                return arithmeticNextSection(from: indexPath, direction: direction).map { .cell($0) }
            }
        }

        return sequentialItem(from: current, direction: direction)
    }

    private func adjacentItem(from current: IndexPath, direction: FocusDirection) -> IndexPath? {
        guard let collectionView else { return nil }
        let itemCount = collectionView.numberOfItems(inSection: current.section)
        let delta = direction == .right ? 1 : -1
        var item = current.item + delta
        if collectionView.focusOrthogonalWraps {
            if item < 0 { item = itemCount - 1 }
            if item >= itemCount { item = 0 }
        }
        guard item >= 0, item < itemCount else { return nil }
        return IndexPath(item: item, section: current.section)
    }

    private func arithmeticNextSection(from current: IndexPath, direction: FocusDirection) -> IndexPath? {
        guard let collectionView else { return nil }
        let sectionCount = collectionView.numberOfSections
        let delta = direction == .down ? 1 : -1
        let section = current.section + delta
        guard section >= 0, section < sectionCount else { return nil }

        let itemCount = collectionView.numberOfItems(inSection: section)
        guard itemCount > 0 else {
            return arithmeticNextSection(from: IndexPath(item: current.item, section: section), direction: direction)
        }

        let item = min(current.item, itemCount - 1)
        return IndexPath(item: item, section: section)
    }

    /// Item-to-item search inside a collection, including section headers.
    /// Up/down pick the nearest row (header vs cells). Left/right stay in the
    /// current row so a full-width header cannot steal a hop between cells.
    private func sequentialItem(from current: FocusedElement, direction: FocusDirection) -> FocusedElement? {
        guard let originFrame = layoutAttributes(for: current)?.frame else { return nil }
        let items = allNavigableLayoutItems().filter { $0.element != current }
        guard !items.isEmpty else { return nil }
        let frames = items.map(\.frame)
        let bounds = frames.reduce(originFrame) { $0.union($1) }
        guard let index = FocusEngine.bestFrameIndex(
            from: originFrame,
            direction: direction,
            frames: frames,
            searchBounds: bounds,
            expandPolicy: .verticalOnly
        ) else {
            return nil
        }
        return items[index].element
    }

    private func allNavigableLayoutItems() -> [(element: FocusedElement, frame: CGRect)] {
        guard let collectionView else { return [] }
        var result: [(FocusedElement, CGRect)] = []
        for section in 0..<collectionView.numberOfSections {
            for kind in [UICollectionView.elementKindSectionHeader, UICollectionView.elementKindSectionFooter] {
                let element = FocusedElement.supplementary(kind: kind, section: section)
                if let frame = layoutFrameIfNavigable(element) {
                    result.append((element, frame))
                }
            }
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                let element = FocusedElement.cell(IndexPath(item: item, section: section))
                if let frame = layoutFrameIfNavigable(element) {
                    result.append((element, frame))
                }
            }
        }
        return result
    }

    private func layoutFrameIfNavigable(_ element: FocusedElement) -> CGRect? {
        guard isNavigableElement(element), let frame = layoutAttributes(for: element)?.frame else { return nil }
        if hostView(for: element) == nil {
            return frame
        }
        return isFocusableElement(element) ? frame : nil
    }

    private func entryElement(from direction: FocusDirection?) -> FocusedElement? {
        guard let collectionView else { return nil }

        let visibleRect = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
        let visibleAttributes = (collectionView.collectionViewLayout.layoutAttributesForElements(in: visibleRect) ?? [])
            .filter { !$0.isHidden && $0.alpha > 0 && isNavigableAttributes($0) }

        guard !visibleAttributes.isEmpty else {
            return direction == nil ? firstFocusableElement() : nil
        }

        let best = visibleAttributes.min { lhs, rhs in
            switch direction {
            case .down, .none:
                if abs(lhs.frame.minY - rhs.frame.minY) > 1 { return lhs.frame.minY < rhs.frame.minY }
                return lhs.frame.minX < rhs.frame.minX
            case .up:
                if abs(lhs.frame.maxY - rhs.frame.maxY) > 1 { return lhs.frame.maxY > rhs.frame.maxY }
                return lhs.frame.minX < rhs.frame.minX
            case .right:
                if abs(lhs.frame.minX - rhs.frame.minX) > 1 { return lhs.frame.minX < rhs.frame.minX }
                return lhs.frame.minY < rhs.frame.minY
            case .left:
                if abs(lhs.frame.maxX - rhs.frame.maxX) > 1 { return lhs.frame.maxX > rhs.frame.maxX }
                return lhs.frame.minY < rhs.frame.minY
            }
        }
        return best.map { attributesElement(from: $0) }
    }

    // MARK: 元素解析

    private func attributesElement(from attributes: UICollectionViewLayoutAttributes) -> FocusedElement {
        switch attributes.representedElementCategory {
        case .cell:
            return .cell(attributes.indexPath)
        case .supplementaryView:
            let kind = attributes.representedElementKind ?? UICollectionView.elementKindSectionHeader
            return .supplementary(kind: kind, section: attributes.indexPath.section)
        default:
            return .cell(attributes.indexPath)
        }
    }

    private func layoutAttributes(for element: FocusedElement) -> UICollectionViewLayoutAttributes? {
        guard let collectionView else { return nil }
        switch element {
        case .cell(let indexPath):
            return collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)
        case .supplementary(let kind, let section):
            return collectionView.layoutAttributesForSupplementaryElement(
                ofKind: kind,
                at: IndexPath(item: 0, section: section)
            )
        }
    }

    private func hostView(for element: FocusedElement) -> UIView? {
        guard let collectionView else { return nil }
        switch element {
        case .cell(let indexPath):
            return collectionView.cellForItem(at: indexPath)
        case .supplementary(let kind, let section):
            return collectionView.supplementaryView(forElementKind: kind, at: IndexPath(item: 0, section: section))
        }
    }

    private func focusedElement(containing view: UIView) -> FocusedElement? {
        guard let collectionView else { return nil }
        var current: UIView? = view
        while let candidate = current {
            if let cell = candidate as? UICollectionViewCell, let indexPath = collectionView.indexPath(for: cell) {
                return .cell(indexPath)
            }
            if let reusable = candidate as? UICollectionReusableView,
               let match = supplementaryElement(for: reusable) {
                return match
            }
            if candidate === collectionView { break }
            current = candidate.superview
        }
        return nil
    }

    private func supplementaryElement(for reusableView: UICollectionReusableView) -> FocusedElement? {
        guard let collectionView else { return nil }
        for section in 0..<collectionView.numberOfSections {
            for kind in [UICollectionView.elementKindSectionHeader, UICollectionView.elementKindSectionFooter] {
                let indexPath = IndexPath(item: 0, section: section)
                if collectionView.supplementaryView(forElementKind: kind, at: indexPath) === reusableView {
                    return .supplementary(kind: kind, section: section)
                }
            }
        }
        return nil
    }

    func firstFocusableElement() -> FocusedElement? {
        guard let collectionView else { return nil }
        for section in 0..<collectionView.numberOfSections {
            for kind in [UICollectionView.elementKindSectionHeader, UICollectionView.elementKindSectionFooter] {
                let element = FocusedElement.supplementary(kind: kind, section: section)
                if isNavigableElement(element), isFocusableElement(element) {
                    return element
                }
            }
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                let element = FocusedElement.cell(IndexPath(item: item, section: section))
                if isFocusableElement(element) {
                    return element
                }
            }
        }
        return nil
    }

    func firstFocusableIndexPath() -> IndexPath? {
        guard let collectionView else { return nil }
        for section in 0..<collectionView.numberOfSections {
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                let indexPath = IndexPath(item: item, section: section)
                if isFocusableElement(.cell(indexPath)) {
                    return indexPath
                }
            }
        }
        return nil
    }

    private func isNavigableAttributes(_ attributes: UICollectionViewLayoutAttributes) -> Bool {
        switch attributes.representedElementCategory {
        case .cell:
            return isNavigableItem(attributes.indexPath)
        case .supplementaryView:
            return layoutAttributes(for: attributesElement(from: attributes)) != nil
        default:
            return false
        }
    }

    private func isNavigableElement(_ element: FocusedElement) -> Bool {
        switch element {
        case .cell(let indexPath):
            return isNavigableItem(indexPath)
        case .supplementary:
            return layoutAttributes(for: element) != nil
        }
    }

    private func isValidElement(_ element: FocusedElement) -> Bool {
        switch element {
        case .cell(let indexPath):
            return isValid(indexPath)
        case .supplementary(_, let section):
            guard let collectionView else { return false }
            return section >= 0 && section < collectionView.numberOfSections
        }
    }

    private func isNavigableItem(_ indexPath: IndexPath) -> Bool {
        guard isValid(indexPath) else { return false }
        if let filter = collectionView?.focusCellFilter, !filter(indexPath) {
            return false
        }
        return true
    }

    private func isFocusableElement(_ element: FocusedElement) -> Bool {
        guard isNavigableElement(element) else { return false }
        guard let host = hostView(for: element) else { return false }
        return hasFocusableContent(in: host)
    }

    private func hasFocusableContent(in view: UIView) -> Bool {
        if view.fk_canFocus { return true }
        return !FocusEngine.collectCandidates(in: view).isEmpty
    }

    private func isValid(_ indexPath: IndexPath) -> Bool {
        guard let collectionView else { return false }
        return indexPath.section >= 0
            && indexPath.section < collectionView.numberOfSections
            && indexPath.item >= 0
            && indexPath.item < collectionView.numberOfItems(inSection: indexPath.section)
    }
}
