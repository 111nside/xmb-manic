//
//  AddTriggerActionComboView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/5.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class AddTriggerActionComboView: BaseView {
    private let triggerItem: TriggerItem
    
    private lazy var durationPerKeyItemView: ASListItemView = {
        let view = ASListItemView()
        view.styles = getDurationPerKeyStyles()
        view.enablePressEffect = true
        
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            //16.7ms 50.0-1000ms
            let values = [16.7] + Array(stride(from: 50.0, through: 1000.0, by: 50.0))
            let datas = values.map({ $0.roundedDecimal(scale: 1) }).map({ "\($0.stringValue(minFraction: 1, maxFraction: 1))ms" })
            let oldValue = self.triggerItem.comboActionPressDurationPerKey
            let currentIndex = values.firstIndex(where: { $0 == oldValue }) ?? 0
            ASSheetView.show(.init(style: .picker(title: R.string.localizable.pressDurationPerKey(),
                                                  datas: datas,
                                                  selectedIndex: currentIndex)),
                             action: { [weak self] action, _ in
                guard let self else { return .dismiss() }
                if let index = action.pickerValue?.index {
                    let newValue = values[index]
                    if newValue != oldValue {
                        self.triggerItem.comboActionPressDurationPerKey = newValue
                        self.durationPerKeyItemView.styles = self.getDurationPerKeyStyles()
                    }
                }
                return .none
            })
            
        }
        return view
    }()
    
    private func getDurationPerKeyStyles() -> [ASListPage.Cell.Style] {
        return [
            .icon(.symbol(.timer)),
            .title(.largeText(R.string.localizable.pressDurationPerKey())),
            .chevron(.init(title: "\(triggerItem.comboActionPressDurationPerKey.roundedString())ms"))
        ]
    }
    
    private lazy var intervalPerKeyItemView: ASListItemView = {
        let view = ASListItemView()
        view.styles = getIntervalPerKeyStyles()
        view.enablePressEffect = true
        
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            //16.7ms 50.0-1000ms
            let values = [16.7] + Array(stride(from: 50.0, through: 1000.0, by: 50.0))
            let datas = values.map({ $0.roundedDecimal(scale: 1) }).map({ "\($0.stringValue(minFraction: 1, maxFraction: 1))ms" })
            let oldValue = self.triggerItem.comboActionIntervalPerKey
            let currentIndex = values.firstIndex(where: { $0 == oldValue }) ?? 0
            ASSheetView.show(.init(style: .picker(title: R.string.localizable.intervalPerKey(),
                                                  datas: datas,
                                                  selectedIndex: currentIndex)),
                             action: { [weak self] action, _ in
                guard let self else { return .dismiss() }
                if let index = action.pickerValue?.index {
                    let newValue = values[index]
                    if newValue != oldValue {
                        self.triggerItem.comboActionIntervalPerKey = newValue
                        self.intervalPerKeyItemView.styles = self.getIntervalPerKeyStyles()
                    }
                }
                return .none
            })
            
        }
        return view
    }()
    
    private func getIntervalPerKeyStyles() -> [ASListPage.Cell.Style] {
        return [
            .icon(.symbolImage(R.image.customClockArrowTriangleheadCounterclockwiseRotate90())),
            .title(.largeText(R.string.localizable.intervalPerKey())),
            .chevron(.init(title: "\(triggerItem.comboActionIntervalPerKey.roundedString())ms"))
        ]
    }
    
    init(triggerItem: TriggerItem) {
        self.triggerItem = triggerItem
        super.init(frame: .zero)
        backgroundColor = R.Color.BackgroundTertiary
        layerCornerRadius = R.Size.CornerRadiusMedium
        
        addSubview(durationPerKeyItemView)
        durationPerKeyItemView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        addSubview(intervalPerKeyItemView)
        intervalPerKeyItemView.snp.makeConstraints { make in
            make.top.equalTo(durationPerKeyItemView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
