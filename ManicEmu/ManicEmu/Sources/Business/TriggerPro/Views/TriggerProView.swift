//
//  TriggerProView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/10/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import Haptica

class TriggerProView: BaseView {
    var hapticType: GameOption.HapticType = .soft {
        didSet {
            isHapticEnabled = true
            switch hapticType {
            case .off:
                isHapticEnabled = false
            case .soft:
                hapticFeedbackStyle = .soft
            case .light:
                hapticFeedbackStyle = .light
            case .medium:
                hapticFeedbackStyle = .medium
            case .heavy:
                hapticFeedbackStyle = .heavy
            case .rigid:
                hapticFeedbackStyle = .rigid
            }
        }
    }
    
    ///EditMode回调
    var didTapButton: ((TriggerItem)->Void)? = nil
    
    ///非EditMode回调
    var activateHandler: ((Set<AnyInput>) -> Void)?
    var deactivateHandler: ((Set<AnyInput>) -> Void)?
    
    private var isHapticEnabled = true
    private var hapticFeedbackStyle: HapticFeedbackStyle = .soft
    /// TriggerPro拥有两套触摸系统
    /// isEditMode = true 将使用UIGestureRecognizer
    /// isEditMode = false 将使用touchesBegan
    private var isEditMode: Bool
    private var trigger: Trigger
    
    private var touchMappingDic: [UITouch: Set<TriggerButton>] = [:]
    private var preTouchButtons = Set<TriggerButton>()
    private var touchButtons: Set<TriggerButton> {
        return self.touchMappingDic.values.reduce(Set<TriggerButton>(), { $0.union($1) })
    }
    
    private var buttonItemMap: [TriggerButton: TriggerItem] = [:]
    
    private var buttonsWithoutPosition: [TriggerButton] = []
    private var needsLayoutButtons: Bool = false
    
    // MARK: - Action State Management
    
    /// Item 配置数据（值类型，可以安全地在线程间传递）
    private struct ItemConfig {
        let mappings: [String]
        let action: TriggerItem.Action
        let simpleActionRepeat: Bool
        let simpleActionRepeatInterval: Double
        let holdActionAutoStop: Bool
        let holdActionDuration: Double
        let comboActionPressDurationPerKey: Double
        let comboActionIntervalPerKey: Double
        
        init(item: TriggerItem) {
            self.mappings = Array(item.mappings)
            self.action = item.action
            self.simpleActionRepeat = item.simpleActionRepeat
            self.simpleActionRepeatInterval = item.simpleActionRepeatInterval
            self.holdActionAutoStop = item.holdActionAutoStop
            self.holdActionDuration = item.holdActionDuration
            self.comboActionPressDurationPerKey = item.comboActionPressDurationPerKey
            self.comboActionIntervalPerKey = item.comboActionIntervalPerKey
        }
    }
    
    /// 按钮状态管理
    private class ButtonState {
        var isHoldActive: Bool = false
        var pendingHoldToggle: Bool = false
        var repeatTimer: DispatchSourceTimer?
        var holdTimer: DispatchSourceTimer?
        var comboTimer: DispatchSourceTimer?
        var comboIndex: Int = 0
        var config: ItemConfig
        
        init(config: ItemConfig) {
            self.config = config
        }
    }
    
    private var buttonStates: [TriggerButton: ButtonState] = [:]
    private var buttonConfigMap: [TriggerButton: ItemConfig] = [:]
    private let timerQueue = DispatchQueue(label: "com.manicemu.trigger.timer", qos: .userInteractive)
    
    init(trigger: Trigger, isEditMode: Bool = false) {
        self.trigger = trigger
        self.isEditMode = isEditMode
        super.init(frame: .zero)
        backgroundColor = .clear
        DispatchQueue.main.asyncAfter(delay: 0.35) {
            self.reloadButtons()
        }
        if !isEditMode {
            isMultipleTouchEnabled = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        cancelAllActions()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if needsLayoutButtons {
            layoutButtonsInCenter(buttonsWithoutPosition)
        }
    }
    
    func reloadButtons() {
        // 取消所有正在进行的动作
        cancelAllActions()
        
        self.subviews.forEach({ $0.removeFromSuperview() })
        buttonItemMap.removeAll()
        buttonStates.removeAll()
        buttonConfigMap.removeAll()
        buttonsWithoutPosition.removeAll()
        
        // 第一遍：创建所有按钮，有坐标的直接设置位置
        for item in trigger.items {
            var image: UIImage? = nil
            if let imageFilePath = item.customImage?.filePath {
                image = UIImage(contentsOfFile: imageFilePath.path)
            }
            let button = TriggerButton(style: item.style,
                                       image: image,
                                       title: item.buttonText,
                                       buttonSize: item.buttonSize,
                                       buttonCornerRadius: item.buttonCornerRadius,
                                       buttonOpacity: item.buttonOpacity,
                                       isEditMode: isEditMode)
            addSubview(button)
            
            // 建立按钮和 item 的映射关系
            buttonItemMap[button] = item
            
            // 提取配置数据（值类型，可以安全地在线程间传递）
            buttonConfigMap[button] = ItemConfig(item: item)
            
            // 添加手势识别器
            setupGestures(for: button)
            if let position = item.position {
                if self.frame.contains(position) {
                    button.x = position.x
                    button.y = position.y
                } else {
                    //超出屏幕外部了
                    buttonsWithoutPosition.append(button)
                }
            } else {
                // 收集没有坐标的按钮，稍后统一布局
                buttonsWithoutPosition.append(button)
            }
        }
        
        // 第二遍：为没有坐标的按钮进行自动布局
        if !buttonsWithoutPosition.isEmpty {
            needsLayoutButtons = true
            setNeedsLayout()
        }
    }
    
    private func layoutButtonsInCenter(_ buttons: [TriggerButton]) {
        needsLayoutButtons = false
        guard !buttons.isEmpty else { return }
        
        let spacing: CGFloat = R.Size.ContentSpaceSmall // 按钮之间的间距
        let padding: CGFloat = R.Size.ContentSpaceLarge // 边距
        let maxWidth = bounds.width - padding * 2
        
        // 使用流式布局计算每个按钮的位置
        var rows: [[TriggerButton]] = [[]]
        var currentRowWidth: CGFloat = 0
        
        for button in buttons {
            let buttonWidth = button.bounds.width
            
            if currentRowWidth + buttonWidth <= maxWidth {
                // 当前行可以放下这个按钮
                rows[rows.count - 1].append(button)
                currentRowWidth += buttonWidth + spacing
            } else {
                // 需要换行
                rows.append([button])
                currentRowWidth = buttonWidth + spacing
            }
        }
        
        // 计算总高度
        let rowHeight = buttons.first?.bounds.height ?? 0
        let totalHeight = CGFloat(rows.count) * rowHeight + CGFloat(max(0, rows.count - 1)) * spacing
        
        // 计算起始Y坐标（居中）
        var startY = (bounds.height - totalHeight) / 2
        
        // 为每一行的按钮设置位置
        for row in rows {
            // 计算当前行的总宽度
            let rowWidth = row.reduce(0) { $0 + $1.bounds.width } + CGFloat(max(0, row.count - 1)) * spacing
            
            // 计算当前行的起始X坐标（居中）
            var currentX = (bounds.width - rowWidth) / 2
            
            // 设置当前行每个按钮的位置
            for button in row {
                button.x = currentX
                button.y = startY
                currentX += button.bounds.width + spacing
            }
            
            // 移动到下一行
            startY += rowHeight + spacing
        }
    }
    
    private func createInput(stringValue: String) -> AnyInput {
        if stringValue.hasPrefix("KB_") {
            return AnyInput(stringValue: stringValue.replacingOccurrences(of: "KB_", with: ""), intValue: nil, type: .controller(GameControllerInputType("directKeyboard")))
        } else {
            return AnyInput(stringValue: stringValue, intValue: 1, type: .controller(.controllerSkin))
        }
    }
    
    // MARK: - Gesture Setup
    
    private func setupGestures(for button: TriggerButton) {
        if isEditMode {
            // 编辑模式：添加拖动手势
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            button.addGestureRecognizer(panGesture)
            
            //编辑模式：添加点击手势
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            button.addGestureRecognizer(tapGesture)
        }
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let button = gesture.view as? TriggerButton else {
            return
        }
        
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .began, .changed:
            // 计算新位置
            let newX = button.x + translation.x
            let newY = button.y + translation.y
            
            // 限制按钮不超出父视图边界
            let minX: CGFloat = 0
            let minY: CGFloat = 0
            let maxX = bounds.width - button.bounds.width
            let maxY = bounds.height - button.bounds.height
            
            button.x = max(minX, min(newX, maxX))
            button.y = max(minY, min(newY, maxY))
            
            // 重置 translation
            gesture.setTranslation(.zero, in: self)
            
        case .ended, .cancelled:
            // 拖动结束，更新 TriggerItem 的坐标
            updateItemPosition(for: button)
            
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let button = gesture.view as? TriggerButton else {
            return
        }
        if let item = buttonItemMap[button] {
            didTapButton?(item)
        }
    }
    
    private func updateItemPosition(for button: TriggerButton) {
        guard let item = buttonItemMap[button] else {
            return
        }
        
        // 根据设备类型更新对应的坐标
        item.position = CGPoint(x: button.x.rounded(numberOfDecimalPlaces: 1, rule: .toNearestOrEven), y: button.y.rounded(numberOfDecimalPlaces: 1, rule: .toNearestOrEven))
    }
    
    // MARK: - Hit Test
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 遍历所有子视图（按钮），检查点击是否在某个按钮上
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if subview.bounds.contains(convertedPoint) {
                if isEditMode {
                    //编辑模式响应具体的按钮
                    return subview
                } else {
                    //非编辑模式只让父View响应
                    return self
                }
            }
        }
        // 点击不在任何按钮上，返回 nil 让点击穿透
        return nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isEditMode else { return }
        for touch in touches {
            touchMappingDic[touch] = []
        }
        updateInputs(for: touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isEditMode else { return }
        updateInputs(for: touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isEditMode else { return }
        for touch in touches {
            touchMappingDic[touch] = nil
        }
        updateInputs(for: touches)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isEditMode else { return }
        touchesEnded(touches, with: event)
    }
    
    private func updateInputs(for touches: Set<UITouch>) {
        for touch in touches where touchMappingDic[touch] != nil {
            guard touch.view == self else { continue }
            
            let point = touch.location(in: self)
            
            var needsActivetedbuttons: [TriggerButton] = []
            
            for button in buttonItemMap.keys {
                let convertedPoint = button.convert(point, from: self)
                if button.bounds.contains(convertedPoint), let _ = buttonItemMap[button] {
                    needsActivetedbuttons.append(button)
                }
            }
            touchMappingDic[touch] = Set(needsActivetedbuttons)
        }
        
        let activatedButtons = touchButtons.subtracting(preTouchButtons)
        let deactivatedButtons = preTouchButtons.subtracting(touchButtons)
        
        preTouchButtons = touchButtons
        
        if !activatedButtons.isEmpty {
            activateButtons(activatedButtons)
            activatedButtons.forEach({ $0.pressEffect() })
            
            if isHapticEnabled {
                UIDevice.generateHaptic(style: hapticFeedbackStyle)
            }
        }
        
        if !deactivatedButtons.isEmpty {
            deactivateButtons(deactivatedButtons)
            deactivatedButtons.forEach({ $0.releaseEffect() })
        }
    }
    
    // MARK: - Action Management
    
    /// 取消所有动作
    private func cancelAllActions() {
        for (_, state) in buttonStates {
            state.repeatTimer?.cancel()
            state.holdTimer?.cancel()
            state.comboTimer?.cancel()
        }
        buttonStates.removeAll()
    }
    
    /// 取消特定按钮的动作
    private func cancelButtonAction(_ button: TriggerButton) {
        guard let state = buttonStates[button] else { return }
        
        state.repeatTimer?.cancel()
        state.repeatTimer = nil
        
        state.holdTimer?.cancel()
        state.holdTimer = nil
        
        state.comboTimer?.cancel()
        state.comboTimer = nil
    }
    
    private func activateButtons(_ buttons: Set<TriggerButton>) {
        for button in buttons {
            guard let config = buttonConfigMap[button] else { continue }
            
            switch config.action {
            case .simple:
                handleSimpleAction(button: button, config: config)
            case .hold:
                handleHoldAction(button: button, config: config)
            case .combo:
                break
            }
        }
    }
    
    private func deactivateButtons(_ buttons: Set<TriggerButton>) {
        for button in buttons {
            guard let config = buttonConfigMap[button] else { continue }
            
            switch config.action {
            case .simple:
                handleSimpleDeactivate(button: button, config: config)
            case .hold:
                handleHoldDeactivate(button: button, config: config)
            case .combo:
                handleComboAction(button: button, config: config)
                break
            }
        }
    }
    
    // MARK: - Simple Action
    
    private func handleSimpleAction(button: TriggerButton, config: ItemConfig) {
        // 立即激活一次
        let inputs = Set(config.mappings.map { createInput(stringValue: $0) })
        activateHandler?(inputs)
        
        // 如果需要重复
        if config.simpleActionRepeat {
            startRepeatTimer(for: button, config: config)
        }
    }
    
    private func handleSimpleDeactivate(button: TriggerButton, config: ItemConfig) {
        // 停止重复定时器
        if config.simpleActionRepeat {
            cancelButtonAction(button)
        }
        
        // 发送 deactivate
        let inputs = Set(config.mappings.map { createInput(stringValue: $0) })
        deactivateHandler?(inputs)
    }
    
    private func startRepeatTimer(for button: TriggerButton, config: ItemConfig) {
        let state = buttonStates[button] ?? ButtonState(config: config)
        buttonStates[button] = state
        
        // 创建高精度定时器，用于重复按键
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
        let interval = max(0.001, config.simpleActionRepeatInterval) // 最小 1ms
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .microseconds(100))
        
        // 捕获配置数据（值类型），避免在后台线程访问 Realm 对象
        let mappings = config.mappings
        
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let inputs = Set(mappings.map { self.createInput(stringValue: $0) })
            
            // 在主线程执行回调 - 每次重复都是一次完整的按键操作
            DispatchQueue.main.async {
                // 先 deactivate 上一次的按压
                self.deactivateHandler?(inputs)
            }
            
            // 使用高精度定时器来确保 activate 在 deactivate 后立即触发 60hz刷新率的一帧时间大概是16.7ms 如果小于16.7毫秒则输入会失效 这里取20ms
            self.timerQueue.asyncAfter(deadline: .now() + .milliseconds(20)) { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.activateHandler?(inputs)
                }
            }
        }
        
        state.repeatTimer = timer
        timer.resume()
    }
    
    // MARK: - Hold Action
    
    private func handleHoldAction(button: TriggerButton, config: ItemConfig) {
        let state = buttonStates[button] ?? ButtonState(config: config)
        buttonStates[button] = state
        
        // 在 activate 时标记待切换，不立即切换状态
        state.pendingHoldToggle = true
    }
    
    private func handleHoldDeactivate(button: TriggerButton, config: ItemConfig) {
        guard let state = buttonStates[button] else { return }
        
        // 只有在有待切换标记时才处理（确保是完整的点击）
        guard state.pendingHoldToggle else { return }
        state.pendingHoldToggle = false
        
        if state.isHoldActive {
            // 当前已经在 hold 状态，点击则停止 hold
            stopHold(for: button, config: config)
        } else {
            // 开始 hold
            startHold(for: button, config: config)
        }
    }
    
    private func startHold(for button: TriggerButton, config: ItemConfig) {
        guard let state = buttonStates[button] else { return }
        
        state.isHoldActive = true
        
        let inputs = Set(config.mappings.map { createInput(stringValue: $0) })
        
        // 激活 hold
        DispatchQueue.main.async { [weak self] in
            UIView.makeToast(message: R.string.localizable.activateHold(inputs.reduce("", { $0 + " " + "[\($1.stringValue)]" })))
            self?.activateHandler?(inputs)
        }
        
        // 如果设置了自动停止
        if config.holdActionAutoStop {
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
            let duration = max(0.1, config.holdActionDuration)
            timer.schedule(deadline: .now() + duration)
            
            // 捕获配置数据（值类型），避免在后台线程访问 Realm 对象
            let mappings = config.mappings
            
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.stopHold(for: button, mappings: mappings)
            }
            
            state.holdTimer = timer
            timer.resume()
        }
    }
    
    private func stopHold(for button: TriggerButton, config: ItemConfig) {
        stopHold(for: button, mappings: config.mappings)
    }
    
    private func stopHold(for button: TriggerButton, mappings: [String]) {
        guard let state = buttonStates[button] else { return }
        guard state.isHoldActive else { return }
        
        state.isHoldActive = false
        state.holdTimer?.cancel()
        state.holdTimer = nil
        
        let inputs = Set(mappings.map { createInput(stringValue: $0) })
        
        // 停用 hold
        DispatchQueue.main.async { [weak self] in
            UIView.makeToast(message: R.string.localizable.deactivateHold(inputs.reduce("", { $0 + " " + "[\($1.stringValue)]" })))
            self?.deactivateHandler?(inputs)
        }
    }
    
    // MARK: - Combo Action
    
    private func handleComboAction(button: TriggerButton, config: ItemConfig) {
        // 取消之前的 combo
        cancelButtonAction(button)
        
        guard !config.mappings.isEmpty else { return }
        
        let state = buttonStates[button] ?? ButtonState(config: config)
        state.comboIndex = 0
        buttonStates[button] = state
        
        // 开始执行 combo 序列
        executeComboSequence(button: button, config: config)
    }
    
    private func executeComboSequence(button: TriggerButton, config: ItemConfig) {
        guard let state = buttonStates[button] else { return }
        
        let mappings = config.mappings
        let pressDuration = max(0.001, config.comboActionPressDurationPerKey / 1000.0)
        let interval = max(0.001, config.comboActionIntervalPerKey / 1000.0)
        
        // 立即执行第一个 input
        executeComboInput(mapping: mappings[0], pressDuration: pressDuration)
        
        // 如果有多个 input，创建定时器按间隔执行后续的 input
        if mappings.count > 1 {
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
            // 第一个在 interval 后执行，然后每隔 interval 执行一次
            timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .microseconds(100))
            
            var currentIndex = 1
            
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                guard self.buttonStates[button] != nil else {
                    timer.cancel()
                    return
                }
                
                if currentIndex < mappings.count {
                    self.executeComboInput(mapping: mappings[currentIndex], pressDuration: pressDuration)
                    currentIndex += 1
                } else {
                    // 所有 input 都已触发，取消定时器
                    timer.cancel()
                    
                    // 在最后一个 input deactivate 后清理状态
                    // 最后一个 input 的 deactivate 时间是 pressDuration
                    self.timerQueue.asyncAfter(deadline: .now() + pressDuration) { [weak self] in
                        self?.buttonStates[button] = nil
                    }
                }
            }
            
            state.comboTimer = timer
            timer.resume()
        } else {
            // 只有一个 input，在 deactivate 后清理状态
            timerQueue.asyncAfter(deadline: .now() + pressDuration) { [weak self] in
                self?.buttonStates[button] = nil
            }
        }
    }
    
    /// 执行单个 combo input 的 activate 和 deactivate
    private func executeComboInput(mapping: String, pressDuration: TimeInterval) {
        let input = createInput(stringValue: mapping)
        
        // Activate
        DispatchQueue.main.async { [weak self] in
            self?.activateHandler?(Set([input]))
        }
        
        // 设置定时器在 pressDuration 后 deactivate
        timerQueue.asyncAfter(deadline: .now() + pressDuration) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.deactivateHandler?(Set([input]))
            }
        }
    }
}
