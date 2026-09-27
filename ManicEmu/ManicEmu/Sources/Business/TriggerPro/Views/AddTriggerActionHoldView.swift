//
//  AddTriggerActionHoldView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/5.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class AddTriggerActionHoldView: BaseView {
    private let triggerItem: TriggerItem
    
    private lazy var autoStopItemView: ASListItemView = {
        let view = ASListItemView(
            .icon(.symbol(.stopCircle)),
            .title(.largeText(R.string.localizable.autoStop())),
            .switch(.init(state: triggerItem.holdActionAutoStop ? .on : .off))
        )
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                  case .switch = style,
                  let value = value as? Bool
            else { return }
            self.triggerItem.holdActionAutoStop = value
        }
        return view
    }()
    
    private lazy var durationItemView: ASListItemView = {
        let view = ASListItemView()
        view.styles = getDurationStyles()
        view.enablePressEffect = true
        
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            //0.1-0.9s 1-59s 60-3600s
            let values = Array(stride(from: 1.0, through: 0.9, by: 0.1)) + Array(stride(from: 1.0, through: 59.0, by: 1.0)) + Array(stride(from: 60.0, through: 3600.0, by: 60.0))
            let datas = values.map({ $0.roundedDecimal(scale: 1) }).map({ "\($0.stringValue(minFraction: 1, maxFraction: 1))s" })
            let oldValue = self.triggerItem.holdActionDuration
            let currentIndex = values.firstIndex(where: { $0 == oldValue }) ?? 0
            ASSheetView.show(.init(style: .picker(title: R.string.localizable.holdDuration(),
                                                  datas: datas,
                                                  selectedIndex: currentIndex)),
                             action: { [weak self] action, _ in
                guard let self else { return .dismiss() }
                if let index = action.pickerValue?.index {
                    let newValue = values[index]
                    if newValue != oldValue {
                        self.triggerItem.holdActionDuration = newValue
                        self.durationItemView.styles = self.getDurationStyles()
                    }
                }
                return .none
            })
            
        }
        return view
    }()
    
    init(triggerItem: TriggerItem) {
        self.triggerItem = triggerItem
        super.init(frame: .zero)
        backgroundColor = R.Color.BackgroundTertiary
        layerCornerRadius = R.Size.CornerRadiusMedium
        
        addSubview(autoStopItemView)
        autoStopItemView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        addSubview(durationItemView)
        durationItemView.snp.makeConstraints { make in
            make.top.equalTo(autoStopItemView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getDurationStyles() -> [ASListPage.Cell.Style] {
        return [
            .icon(.symbol(.timer)),
            .title(.largeText(R.string.localizable.holdDuration())),
            .chevron(.init(title: "\(triggerItem.holdActionDuration.roundedString())s"))
        ]
    }
}
