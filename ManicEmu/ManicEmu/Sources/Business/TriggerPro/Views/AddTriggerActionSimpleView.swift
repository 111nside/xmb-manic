//
//  AddTriggerActionSimpleView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/5.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class AddTriggerActionSimpleView: BaseView {
    private let triggerItem: TriggerItem
    
    private lazy var repeatItemView: ASListItemView = {
        let view = ASListItemView(
            .icon(.symbol(.repeat)),
            .title(.largeText(R.string.localizable.repeatTrigger())),
            .switch(.init(state: triggerItem.simpleActionRepeat ? .on : .off))
        )
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                  case .switch = style,
                  let value = value as? Bool
            else { return }
            self.triggerItem.simpleActionRepeat = value
        }
        return view
    }()
    
    private lazy var intervalItemView: ASListItemView = {
        let view = ASListItemView()
        view.styles = getIntervalStyles()
        view.enablePressEffect = true
        
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            //0.1-0.9s //1-60s
            let values = Array(stride(from: 0.1, through: 0.9, by: 0.1)) + Array(stride(from: 1.0, through: 60.0, by: 1.0))
            let datas = values.map({ $0.roundedDecimal(scale: 1) }).map({ "\($0.stringValue(minFraction: 1, maxFraction: 1))s" })
            let oldValue = self.triggerItem.simpleActionRepeatInterval
            let currentIndex = values.firstIndex(where: { $0 == oldValue }) ?? 0
            ASSheetView.show(.init(style: .picker(title: R.string.localizable.repeatInterval(),
                                                  datas: datas,
                                                  selectedIndex: currentIndex)),
                             action: { [weak self] action, _ in
                guard let self else { return .dismiss() }
                if let index = action.pickerValue?.index {
                    let newValue = values[index]
                    if newValue != oldValue {
                        self.triggerItem.simpleActionRepeatInterval = newValue
                        self.intervalItemView.styles = self.getIntervalStyles()
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
        
        addSubview(repeatItemView)
        repeatItemView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        addSubview(intervalItemView)
        intervalItemView.snp.makeConstraints { make in
            make.top.equalTo(repeatItemView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getIntervalStyles() -> [ASListPage.Cell.Style] {
        return [
            .icon(.symbolImage(R.image.customClockArrowTriangleheadCounterclockwiseRotate90())),
            .title(.largeText(R.string.localizable.repeatInterval())),
            .chevron(.init(title: "\(triggerItem.simpleActionRepeatInterval.roundedString())s"))
        ]
    }
}
