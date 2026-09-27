//
//  ASViewEffects.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/17.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

fileprivate var UIViewEnablePressEffectAssociationKey: UInt8 = 0
fileprivate var UIViewFocusEffectAssociationKey: UInt8 = 0
fileprivate var UIViewPressEffectOverlayConfigurationAssociationKey: UInt8 = 0
fileprivate var UIViewPressEffectOverlayAssociationKey: UInt8 = 0
fileprivate var UIViewPressEffectControllerAssociationKey: UInt8 = 0

private enum UIViewPressEffectFocusCoordinator {
    private(set) static weak var focusedView: UIView?
    
    static func register(_ view: UIView) {
        if focusedView === view { return }
        focusedView?.internalSetFocusEffect(false, releaseAnimation: true)
        focusedView = view
    }
    
    static func handleManualPressBegan(on view: UIView) {
        guard let focused = focusedView else { return }
        let releaseAnimation = focused !== view
        focused.internalSetFocusEffect(false, releaseAnimation: releaseAnimation)
        focusedView = nil
    }
    
    static func resignIfFocused(_ view: UIView) {
        if focusedView === view {
            focusedView = nil
        }
    }
}

struct PressEffectOverlayConfiguration {
    var backgroundColor: UIColor
    var cornerStyle: ASCornerStyle
    /// When `false`, press shows overlay only — no scale / translate transform.
    var enableLiftEffect: Bool
}

// MARK: - Compatibility mode (auto-inferred from view hierarchy)

/// Controls which gesture-compat layers are active. Inferred once per hierarchy change and cached.
private enum PressEffectCompatibilityMode {
    /// Standalone view — immediate press/release, no scroll or context-menu recovery.
    case `default`
    /// Inside a plain UIScrollView — yield to scrolling, no touch-end monitoring.
    case scrollAware
    /// Inside UICollectionView / UITableView — scroll yield + context-menu touch recovery.
    case contextMenuAware
    
    var supportsScrollCancellation: Bool {
        switch self {
        case .default: return false
        case .scrollAware, .contextMenuAware: return true
        }
    }
    
    var supportsTouchEndMonitoring: Bool {
        switch self {
        case .default, .scrollAware: return false
        case .contextMenuAware: return true
        }
    }
    
    /// - No scroll ancestor → `.default`
    /// - UICollectionView / UITableView ancestor → `.contextMenuAware` (delegate may affect all cells)
    /// - Other UIScrollView → `.scrollAware`
    static func infer(from scrollView: UIScrollView?) -> PressEffectCompatibilityMode {
        guard let scrollView else { return .default }
        if scrollView is UICollectionView || scrollView is UITableView {
            return .contextMenuAware
        }
        return .scrollAware
    }
}

// MARK: - Touch gesture recognizer

/// Tracks UITouch directly. When `ignoresSpuriousCancellation` is enabled, swallows
/// context-menu / collection-view cancellations while the finger is still on screen.
private final class PressEffectTouchGestureRecognizer: UIGestureRecognizer {
    private(set) weak var primaryTouch: UITouch?
    private weak var lastEvent: UIEvent?
    /// When false, spurious `touchesCancelled` ends the gesture normally (.scrollAware / .default).
    var ignoresSpuriousCancellation = false
    var onSpuriousCancellation: (() -> Void)?
    
    func resolvedActiveTouch() -> UITouch? {
        if let touch = primaryTouch, Self.isTouchPhaseActive(touch.phase) {
            return touch
        }
        guard let touches = lastEvent?.allTouches else { return primaryTouch }
        return touches.first { Self.isTouchPhaseActive($0.phase) } ?? primaryTouch
    }
    
    private static func isTouchPhaseActive(_ phase: UITouch.Phase) -> Bool {
        switch phase {
        case .began, .moved, .stationary:
            return true
        default:
            return false
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state == .possible, let touch = touches.first else { return }
        lastEvent = event
        primaryTouch = touch
        state = .began
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard primaryTouch != nil else { return }
        lastEvent = event
        if state == .began || state == .changed {
            state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let primary = primaryTouch, touches.contains(primary) else { return }
        lastEvent = event
        state = .ended
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        lastEvent = event
        guard let primary = primaryTouch else {
            if state != .possible { state = .cancelled }
            return
        }
        if touches.contains(primary), ignoresSpuriousCancellation, Self.isTouchPhaseActive(primary.phase) {
            onSpuriousCancellation?()
            return
        }
        state = .cancelled
    }
    
    override func reset() {
        if state == .ended || state == .cancelled || state == .failed {
            primaryTouch = nil
            lastEvent = nil
        }
        super.reset()
    }
}

private final class PressEffectOverlayView: UIView {
    var cornerStyle: ASCornerStyle = .circle {
        didSet { setNeedsLayout() }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        switch cornerStyle {
        case .circle:
            layer.cornerRadius = min(bounds.width, bounds.height) / 2
        case .radius(let radius):
            layer.cornerRadius = radius
        }
    }
}

private final class UIViewPressEffectController: NSObject, UIGestureRecognizerDelegate {
    private struct PressEffectSizing {
        let liftScale: CGFloat
        let liftTranslationY: CGFloat
        let minUndershootScaleDelta: CGFloat
        let maxUndershootScaleDelta: CGFloat
        let minUndershootTranslationY: CGFloat
        let maxUndershootTranslationY: CGFloat
        
        static func make(for view: UIView) -> PressEffectSizing {
            let minDimension = min(view.bounds.size.minDimension, PressEffectMetrics.referenceMaxHeight)
            return PressEffectMetrics.sizing(forHeight: minDimension)
        }
    }
    
    private enum PressEffectMetrics {
        /// Baseline view height — animation deltas are tuned for this size.
        static let referenceHeight: CGFloat = 35
        static let referenceMaxHeight: CGFloat = 50
        
        /// Full hold reference — intensity ramps from 0 → 1 over this duration.
        static let referencePressDuration: CFTimeInterval = 0.32
        /// Below this, skip the undershoot phase and settle directly.
        static let quickTapDuration: CFTimeInterval = 0.11
        
        /// Deltas at `referenceHeight` — scaled down proportionally on taller views.
        static let referenceLiftScaleDelta: CGFloat = 0.065
        static let referenceLiftTranslationY: CGFloat = -3
        static let referenceMinUndershootScaleDelta: CGFloat = 0.002
        static let referenceMaxUndershootScaleDelta: CGFloat = 0.013
        static let referenceMinUndershootTranslationY: CGFloat = 0.3
        static let referenceMaxUndershootTranslationY: CGFloat = 0.85
        
        static func smoothstep(_ value: CGFloat) -> CGFloat {
            let t = min(max(value, 0), 1)
            return t * t * (3 - 2 * t)
        }
        
        static func lerp(_ from: CGFloat, _ to: CGFloat, _ amount: CGFloat) -> CGFloat {
            from + (to - from) * amount
        }
        
        /// 0 = quick tap, 1 = full hold — drives drop depth and bounce character.
        static func intensity(for pressDuration: CFTimeInterval) -> CGFloat {
            smoothstep(CGFloat(pressDuration / referencePressDuration))
        }
        
        /// Views taller than the reference use smaller deltas; shorter views keep the baseline feel.
        static func sizing(forHeight height: CGFloat) -> PressEffectSizing {
            let clampedHeight = max(height, 1)
            let sizeRatio = min(1, referenceHeight / clampedHeight)
            
            return PressEffectSizing(
                liftScale: 1 + referenceLiftScaleDelta * sizeRatio,
                liftTranslationY: referenceLiftTranslationY * sizeRatio,
                minUndershootScaleDelta: referenceMinUndershootScaleDelta * sizeRatio,
                maxUndershootScaleDelta: referenceMaxUndershootScaleDelta * sizeRatio,
                minUndershootTranslationY: referenceMinUndershootTranslationY * sizeRatio,
                maxUndershootTranslationY: referenceMaxUndershootTranslationY * sizeRatio
            )
        }
    }
    
    private weak var view: UIView?
    private var pressGesture: PressEffectTouchGestureRecognizer?
    private var animationGeneration = 0
    private var overlayLayoutGeneration = 0
    /// Cached on hierarchy refresh; avoids repeated superview walks during touch handling.
    private weak var cachedEnclosingScrollView: UIScrollView?
    private var cachedCompatibilityMode: PressEffectCompatibilityMode = .default
    private var isLifted = false {
        didSet {
            pressEffectListener?(isLifted ? .lift : .release)
        }
    }
    private var isFocusHeld = false
    private var didCancelWhilePressed = false
    private var pressBeganTime: CFTimeInterval = 0
    private var initialTouchLocationInWindow: CGPoint?
    private weak var trackingTouch: UITouch?
    private var touchEndMonitorTimer: Timer?
    private var suppressTouchEndMonitoring = false
    private var isPressSequenceActive = false
    private var nilTrackingTouchStreak = 0
    private let scrollMovementThreshold: CGFloat = 10
    /// Context-menu steals the recognizer within ~50 ms while the finger is still down.
    private let spuriousEndThreshold: CFTimeInterval = 0.05
    private static let touchMonitorInterval: TimeInterval = 1.0 / 30.0
    /// ~100 ms at 30 fps — abort when reload / present drops the touch reference.
    private static let nilTrackingTouchAbortFrameCount = 3
    var pressEffectListener: ((UIView.PressEffectState) -> Void)? = nil
    
    init(view: UIView) {
        self.view = view
        super.init()
        UIViewPressEffectHierarchyTracking.installIfNeeded()
        attachPressGesture()
        refreshScrollEnvironmentIfNeeded()
        updateGestureCompatibilityBehavior()
    }
    
    deinit {
        tearDown(resetTransform: false)
    }
    
    func tearDown(resetTransform: Bool) {
        if let view, let pressGesture {
            view.removeGestureRecognizer(pressGesture)
        }
        pressGesture = nil
        stopTouchEndMonitoring()
        stopAnimations()
        isLifted = false
        isFocusHeld = false
        didCancelWhilePressed = false
        initialTouchLocationInWindow = nil
        trackingTouch = nil
        suppressTouchEndMonitoring = false
        isPressSequenceActive = false
        nilTrackingTouchStreak = 0
        cachedEnclosingScrollView = nil
        cachedCompatibilityMode = .default
        if resetTransform {
            view?.transform = .identity
            view?.pressEffectOverlayView?.isHidden = true
        }
    }
    
    func applyFocusLift() {
        guard let _ = view else { return }
        isFocusHeld = true
        isLifted = true
        animateLift()
    }
    
    func applyFocusRelease() {
        guard let _ = view else { return }
        isFocusHeld = false
        isLifted = false
        animateRelease(pressDuration: PressEffectMetrics.referencePressDuration)
    }
    
    func applyFocusResetForManualInteraction() {
        isFocusHeld = false
        isLifted = false
        animateCancel()
    }
    
    private func attachPressGesture() {
        guard let view else { return }
        let gesture = PressEffectTouchGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesBegan = false
        gesture.delaysTouchesEnded = false
        gesture.delegate = self
        view.addGestureRecognizer(gesture)
        pressGesture = gesture
    }
    
    // MARK: - Scroll environment cache
    
    /// Recomputes scroll ancestor + compatibility mode when the cache is stale (e.g. cell reuse).
    private func refreshScrollEnvironmentIfNeeded() {
        guard let view else {
            cachedEnclosingScrollView = nil
            cachedCompatibilityMode = .default
            return
        }
        if let cached = cachedEnclosingScrollView, Self.isAncestor(cached, of: view) {
            return
        }
        let scrollView = Self.findEnclosingScrollView(for: view)
        cachedEnclosingScrollView = scrollView
        cachedCompatibilityMode = PressEffectCompatibilityMode.infer(from: scrollView)
        updateGestureCompatibilityBehavior()
    }
    
    private func updateGestureCompatibilityBehavior() {
        let monitorTouchEnd = cachedCompatibilityMode.supportsTouchEndMonitoring
        pressGesture?.ignoresSpuriousCancellation = monitorTouchEnd
        pressGesture?.onSpuriousCancellation = monitorTouchEnd ? { [weak self] in
            self?.handleSpuriousTouchCancellation()
        } : nil
    }
    
    private static func isAncestor(_ ancestor: UIView, of view: UIView) -> Bool {
        var current: UIView? = view
        while let candidate = current {
            if candidate === ancestor { return true }
            current = candidate.superview
        }
        return false
    }
    
    private static func findEnclosingScrollView(for view: UIView?) -> UIScrollView? {
        var current = view?.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
    }
    
    private func isScrollViewDragging() -> Bool {
        cachedEnclosingScrollView?.isDragging ?? false
    }
    
    private func isScrollViewPanActive() -> Bool {
        guard let scrollView = cachedEnclosingScrollView else { return false }
        switch scrollView.panGestureRecognizer.state {
        case .began, .changed:
            return true
        default:
            return false
        }
    }
    
    private func isScrollViewActivelyScrolling() -> Bool {
        guard let scrollView = cachedEnclosingScrollView else { return false }
        return scrollView.isDragging || scrollView.isDecelerating
    }
    
    private func captureTrackingTouchFromGesture() {
        if trackingTouch == nil {
            trackingTouch = pressGesture?.resolvedActiveTouch()
        }
    }
    
    /// Called when the host view leaves the window (cell reuse, reload, present transition).
    func handleViewDetachedFromWindow() {
        guard isPressSequenceActive || isLifted else { return }
        recoverFromInterruptedPressSessionIfNeeded()
    }
    
    /// Clears a session that never received a proper ended/cancelled (e.g. after reload).
    private func recoverFromInterruptedPressSessionIfNeeded() {
        guard isPressSequenceActive || isLifted else { return }
        stopTouchEndMonitoring()
        trackingTouch = nil
        let wasLifted = isLifted
        isPressSequenceActive = false
        isLifted = false
        didCancelWhilePressed = false
        initialTouchLocationInWindow = nil
        guard wasLifted, !isFocusHeld else { return }
        stopAnimations()
        view?.transform = .identity
        view?.pressEffectOverlayView?.isHidden = true
    }
    
    private func handleSpuriousTouchCancellation() {
        guard isPressSequenceActive, cachedCompatibilityMode.supportsTouchEndMonitoring else { return }
        captureTrackingTouchFromGesture()
        if !isLifted, !didCancelWhilePressed {
            beginLift()
        }
        startTouchEndMonitoringIfNeeded()
    }
    
    @objc private func handlePress(_ gesture: PressEffectTouchGestureRecognizer) {
        guard let view, view.enablePressEffect else { return }
        
        switch gesture.state {
        case .began:
            recoverFromInterruptedPressSessionIfNeeded()
            refreshScrollEnvironmentIfNeeded()
            isPressSequenceActive = true
            suppressTouchEndMonitoring = false
            trackingTouch = gesture.primaryTouch
            UIViewPressEffectFocusCoordinator.handleManualPressBegan(on: view)
            didCancelWhilePressed = false
            initialTouchLocationInWindow = gesture.location(in: view.window)
            pressBeganTime = CACurrentMediaTime()
            beginLift()
        case .changed:
            if cachedCompatibilityMode.supportsScrollCancellation, shouldCancelForScrollInteraction(gesture) {
                cancelPressInteraction(handOffToScrollView: true)
                return
            }
            let isInside = view.bounds.contains(gesture.location(in: view))
            if isInside, !isLifted, !didCancelWhilePressed {
                beginLift()
            } else if !isInside, isLifted {
                isLifted = false
                didCancelWhilePressed = true
                animateCancel()
            }
        case .ended:
            handlePressGestureEnded(cancelled: false)
        case .cancelled, .failed:
            handlePressGestureEnded(cancelled: true)
        default:
            break
        }
    }
    
    /// Context-menu / collection-view may end the recognizer while the finger is still down.
    /// `.contextMenuAware` defers finish until real touch-up (via 30 fps timer polling).
    private func handlePressGestureEnded(cancelled: Bool) {
        guard isPressSequenceActive else { return }
        let elapsed = CACurrentMediaTime() - pressBeganTime
        
        if suppressTouchEndMonitoring {
            suppressTouchEndMonitoring = false
            stopTouchEndMonitoring()
            trackingTouch = nil
            isPressSequenceActive = false
            finishPress(cancelled: cancelled)
            return
        }
        
        if cachedCompatibilityMode.supportsTouchEndMonitoring {
            captureTrackingTouchFromGesture()
            if elapsed < spuriousEndThreshold || isTouchStillActive() {
                startTouchEndMonitoringIfNeeded()
                return
            }
        }
        
        stopTouchEndMonitoring()
        trackingTouch = nil
        isPressSequenceActive = false
        finishPress(cancelled: cancelled)
    }
    
    private func isTouchStillActive() -> Bool {
        captureTrackingTouchFromGesture()
        guard let touch = trackingTouch else { return false }
        switch touch.phase {
        case .began, .moved, .stationary:
            return true
        default:
            return false
        }
    }
    
    private func startTouchEndMonitoringIfNeeded() {
        guard cachedCompatibilityMode.supportsTouchEndMonitoring else { return }
        guard touchEndMonitorTimer == nil else { return }
        let timer = Timer(timeInterval: Self.touchMonitorInterval, repeats: true) { [weak self] _ in
            self?.monitorTouchEnd()
        }
        touchEndMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func stopTouchEndMonitoring() {
        touchEndMonitorTimer?.invalidate()
        touchEndMonitorTimer = nil
        nilTrackingTouchStreak = 0
    }
    
    private func completeMonitoredPress(cancelled: Bool) {
        stopTouchEndMonitoring()
        trackingTouch = nil
        isPressSequenceActive = false
        finishPress(cancelled: cancelled)
    }
    
    private func monitorTouchEnd() {
        guard isPressSequenceActive else {
            stopTouchEndMonitoring()
            return
        }
        
        guard let view else {
            completeMonitoredPress(cancelled: true)
            return
        }
        
        // Cell reload / present removed the view from the hierarchy — don't wait for a lost touch.
        if view.window == nil {
            completeMonitoredPress(cancelled: true)
            return
        }
        
        if cachedCompatibilityMode.supportsScrollCancellation,
           shouldCancelForScrollInteractionDuringTouchTracking() {
            completeMonitoredPress(cancelled: true)
            return
        }
        
        captureTrackingTouchFromGesture()
        guard let touch = trackingTouch else {
            nilTrackingTouchStreak += 1
            if nilTrackingTouchStreak >= Self.nilTrackingTouchAbortFrameCount {
                completeMonitoredPress(cancelled: true)
            }
            return
        }
        nilTrackingTouchStreak = 0
        
        switch touch.phase {
        case .ended:
            completeMonitoredPress(cancelled: false)
        case .cancelled:
            completeMonitoredPress(cancelled: true)
        default:
            // Finger still down — wait for real touch-up (supports context-menu long press).
            break
        }
    }
    
    private func shouldCancelForScrollInteractionDuringTouchTracking() -> Bool {
        guard cachedCompatibilityMode.supportsScrollCancellation else { return false }
        if isScrollViewDragging() || isScrollViewPanActive() {
            return true
        }
        guard let initial = initialTouchLocationInWindow,
              let touch = trackingTouch,
              let window = view?.window else { return false }
        let current = touch.location(in: window)
        let dx = current.x - initial.x
        let dy = current.y - initial.y
        return hypot(dx, dy) > scrollMovementThreshold
    }
    
    private func beginLift() {
        isLifted = true
        animateLift()
    }
    
    private func cancelPressInteraction(handOffToScrollView: Bool = false) {
        if handOffToScrollView {
            suppressTouchEndMonitoring = true
        }
        if isLifted {
            isLifted = false
            didCancelWhilePressed = true
            animateCancel()
        } else {
            didCancelWhilePressed = true
        }
        if handOffToScrollView {
            failPressGestureForScrollHandoff()
        }
    }
    
    /// Resets the recognizer so UIScrollView pan can take over after scroll is detected.
    private func failPressGestureForScrollHandoff() {
        guard let pressGesture else { return }
        pressGesture.isEnabled = false
        pressGesture.isEnabled = true
    }
    
    private func shouldCancelForScrollInteraction(_ gesture: UIGestureRecognizer) -> Bool {
        guard cachedCompatibilityMode.supportsScrollCancellation else { return false }
        if isScrollViewDragging() {
            return true
        }
        if isScrollViewPanActive() {
            return true
        }
        return didScrollBeyondThreshold(gesture)
    }
    
    private func finishPress(cancelled: Bool) {
        let pressDuration = CACurrentMediaTime() - pressBeganTime
        let wasLifted = isLifted
        isLifted = false
        initialTouchLocationInWindow = nil
        if isFocusHeld {
            return
        }
        if cancelled || didCancelWhilePressed || !wasLifted {
            didCancelWhilePressed = false
            if wasLifted {
                animateCancel()
            }
            return
        }
        animateRelease(pressDuration: pressDuration)
    }
    
    private func didScrollBeyondThreshold(_ gesture: UIGestureRecognizer) -> Bool {
        guard let initial = initialTouchLocationInWindow,
              let window = view?.window else { return false }
        let current = gesture.location(in: window)
        let dx = current.x - initial.x
        let dy = current.y - initial.y
        return hypot(dx, dy) > scrollMovementThreshold
    }
    
    // MARK: - Animations
    
    private func isLiftEffectEnabled(for view: UIView) -> Bool {
        view.isPressEffectLiftEnabled
    }
    
    private func animateLift() {
        guard let view else { return }
        stopAnimations()
        setOverlayVisible(true)
        guard isLiftEffectEnabled(for: view) else { return }
        let sizing = PressEffectSizing.make(for: view)
        
        UIView.animate(
            withDuration: 0.34,
            delay: 0,
            usingSpringWithDamping: 0.68,
            initialSpringVelocity: 0.4,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            view.transform = Self.makeTransform(
                scale: sizing.liftScale,
                translationY: sizing.liftTranslationY
            )
        }
    }
    
    /// Finger still down but moved outside — settle back without undershoot.
    private func animateCancel() {
        guard let view else { return }
        stopAnimations()
        setOverlayVisible(false)
        guard isLiftEffectEnabled(for: view) else { return }
        
        UIView.animate(
            withDuration: 0.26,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0.18,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            view.transform = .identity
        }
    }
    
    /// Release — depth and bounce scale with how long the finger was held.
    private func animateRelease(pressDuration: CFTimeInterval) {
        guard let view else { return }
        stopAnimations()
        setOverlayVisible(false)
        guard isLiftEffectEnabled(for: view) else { return }
        
        let intensity = PressEffectMetrics.intensity(for: pressDuration)
        let sizing = PressEffectSizing.make(for: view)
        animationGeneration += 1
        let generation = animationGeneration
        
        if pressDuration < PressEffectMetrics.quickTapDuration {
            animateSpringToIdentity(
                generation: generation,
                damping: 0.87,
                velocity: 0.2,
                duration: 0.34
            )
            return
        }
        
        let undershootScaleDelta = PressEffectMetrics.lerp(
            sizing.minUndershootScaleDelta,
            sizing.maxUndershootScaleDelta,
            intensity
        )
        let undershootScale = 1 - undershootScaleDelta
        let undershootY = PressEffectMetrics.lerp(
            sizing.minUndershootTranslationY,
            sizing.maxUndershootTranslationY,
            intensity
        )
        let dropDuration = PressEffectMetrics.lerp(0.06, 0.1, intensity)
        
        UIView.animate(
            withDuration: TimeInterval(dropDuration),
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            view.transform = Self.makeTransform(scale: undershootScale, translationY: undershootY)
        } completion: { [weak self] finished in
            guard finished,
                  let self,
                  self.animationGeneration == generation else { return }
            self.animateSpringToIdentity(
                generation: generation,
                damping: PressEffectMetrics.lerp(0.84, 0.72, intensity),
                velocity: PressEffectMetrics.lerp(0.24, 0.48, intensity),
                duration: PressEffectMetrics.lerp(0.42, 0.52, intensity)
            )
        }
    }
    
    private func animateSpringToIdentity(generation: Int, damping: CGFloat, velocity: CGFloat, duration: CFTimeInterval) {
        guard let view, animationGeneration == generation else { return }
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: velocity,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            view.transform = .identity
        }
    }
    
    private func stopAnimations() {
        animationGeneration += 1
        guard let view else { return }
        if isLiftEffectEnabled(for: view), let presentation = view.layer.presentation() {
            view.transform = CATransform3DGetAffineTransform(presentation.transform)
        }
        view.layer.removeAllAnimations()
    }
    
    private func setOverlayVisible(_ visible: Bool) {
        guard let view else { return }
        guard let overlay = view.pressEffectOverlayView else { return }
        overlay.setNeedsLayout()
        overlay.isHidden = !visible
        guard visible else {
            overlayLayoutGeneration += 1
            return
        }
        overlayLayoutGeneration += 1
        let generation = overlayLayoutGeneration
        DispatchQueue.main.async { [weak self, weak overlay] in
            guard let self, let overlay, !overlay.isHidden else { return }
            guard generation == self.overlayLayoutGeneration else { return }
            overlay.layoutIfNeeded()
        }
    }
    
    private static func makeTransform(scale: CGFloat, translationY: CGFloat) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: 0, y: translationY)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view, view.enablePressEffect else { return false }
        refreshScrollEnvironmentIfNeeded()
        if cachedCompatibilityMode.supportsScrollCancellation, isScrollViewActivelyScrolling() {
            return false
        }
        var current: UIView? = touch.view
        while let candidate = current {
            if candidate.enablePressEffect {
                guard candidate === view else { return false }
                trackingTouch = touch
                return true
            } else if candidate is UISwitch {
                return false
            } else if candidate is UIButton {
                return false
            }
            current = candidate.superview
        }
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

// MARK: - Window hierarchy tracking (cell reuse / reload)

/// Detects when a press-effect view leaves the window and resets any stuck session.
private enum UIViewPressEffectHierarchyTracking {
    private static var isInstalled = false
    
    static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true
        UIView.installPressEffectDidMoveToWindowSwizzle()
    }
}

private extension UIView {
    static func installPressEffectDidMoveToWindowSwizzle() {
        let originalSelector = #selector(UIView.didMoveToWindow)
        let swizzledSelector = #selector(UIView.pressEffect_didMoveToWindow)
        guard let originalMethod = class_getInstanceMethod(UIView.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc func pressEffect_didMoveToWindow() {
        pressEffect_didMoveToWindow()
        if window == nil {
            pressEffectController?.handleViewDetachedFromWindow()
        }
    }
}

extension UIView {
    var enablePressEffect: Bool {
        get {
            if let bool = objc_getAssociatedObject(self, &UIViewEnablePressEffectAssociationKey) as? Bool {
                return bool
            }
            return false
        }
        set(newValue) {
            objc_setAssociatedObject(self, &UIViewEnablePressEffectAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            if newValue {
                if pressEffectController == nil {
                    pressEffectController = UIViewPressEffectController(view: self)
                }
                installPressEffectOverlayIfNeeded()
            } else {
                if focusEffect {
                    objc_setAssociatedObject(self, &UIViewFocusEffectAssociationKey, false, .OBJC_ASSOCIATION_RETAIN)
                    UIViewPressEffectFocusCoordinator.resignIfFocused(self)
                }
                pressEffectController?.tearDown(resetTransform: true)
                pressEffectController = nil
            }
            isFocusable = newValue
        }
    }
    
    var focusEffect: Bool {
        get {
            if let bool = objc_getAssociatedObject(self, &UIViewFocusEffectAssociationKey) as? Bool {
                return bool
            }
            return false
        }
        set {
            internalSetFocusEffect(newValue, releaseAnimation: true)
        }
    }
    
    fileprivate func internalSetFocusEffect(_ newValue: Bool, releaseAnimation: Bool) {
        let currentValue = focusEffect
        guard currentValue != newValue else { return }
        objc_setAssociatedObject(self, &UIViewFocusEffectAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        
        if newValue {
            ensurePressEffectController()
            UIViewPressEffectFocusCoordinator.register(self)
            pressEffectController?.applyFocusLift()
        } else {
            UIViewPressEffectFocusCoordinator.resignIfFocused(self)
            if releaseAnimation {
                pressEffectController?.applyFocusRelease()
            } else {
                pressEffectController?.applyFocusResetForManualInteraction()
            }
        }
    }
    
    fileprivate func ensurePressEffectController() {
        if pressEffectController == nil {
            pressEffectController = UIViewPressEffectController(view: self)
            installPressEffectOverlayIfNeeded()
        }
    }
    
    func enablePressEffectOverlay(backgroundColor: UIColor = R.Color.PressOverlay,
                                  cornerStyle: ASCornerStyle = .circle,
                                  enableLiftEffect: Bool = true) {
        pressEffectOverlayConfiguration = PressEffectOverlayConfiguration(
            backgroundColor: backgroundColor,
            cornerStyle: cornerStyle,
            enableLiftEffect: enableLiftEffect
        )
        installPressEffectOverlayIfNeeded()
    }
    
    /// Removes overlay and restores default lift behavior (`enableLiftEffect` implied `true`).
    func disablePressEffectOverlay() {
        pressEffectOverlayConfiguration = nil
        pressEffectOverlayView?.removeFromSuperview()
        pressEffectOverlayView = nil
    }
    
    enum PressEffectState {
        case lift, release
    }
    
    func setPressEffectListener(_ listener: ((PressEffectState) -> Void)? = nil) {
        pressEffectController?.pressEffectListener = listener
    }
    
    private(set) var pressEffectOverlayConfiguration: PressEffectOverlayConfiguration? {
        get {
            objc_getAssociatedObject(self, &UIViewPressEffectOverlayConfigurationAssociationKey) as? PressEffectOverlayConfiguration
        }
        set {
            objc_setAssociatedObject(
                self,
                &UIViewPressEffectOverlayConfigurationAssociationKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }
    
    /// Lift transform is on by default; overlay setup may disable it via `enablePressEffectOverlay(enableLiftEffect: false)`.
    fileprivate var isPressEffectLiftEnabled: Bool {
        pressEffectOverlayConfiguration?.enableLiftEffect ?? true
    }
    
    fileprivate var pressEffectController: UIViewPressEffectController? {
        get {
            objc_getAssociatedObject(self, &UIViewPressEffectControllerAssociationKey) as? UIViewPressEffectController
        }
        set {
            objc_setAssociatedObject(self, &UIViewPressEffectControllerAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    fileprivate var pressEffectOverlayView: UIView? {
        get {
            objc_getAssociatedObject(self, &UIViewPressEffectOverlayAssociationKey) as? UIView
        }
        set {
            objc_setAssociatedObject(self, &UIViewPressEffectOverlayAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    fileprivate func installPressEffectOverlayIfNeeded() {
        guard let configuration = pressEffectOverlayConfiguration else { return }
        
        if let overlay = pressEffectOverlayView as? PressEffectOverlayView {
            overlay.backgroundColor = configuration.backgroundColor
            overlay.cornerStyle = configuration.cornerStyle
            return
        }
        
        let overlay = PressEffectOverlayView()
        overlay.backgroundColor = configuration.backgroundColor
        overlay.cornerStyle = configuration.cornerStyle
        overlay.isHidden = true
        overlay.clipsToBounds = true
        overlay.isUserInteractionEnabled = false
        if let view = self as? UIVisualEffectView {
            view.contentView.insertSubview(overlay, at: 0)
        } else {
            insertSubview(overlay, at: 0)
        }
        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        pressEffectOverlayView = overlay
    }
}
