//
//  AddTriggerActionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/4.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class AddTriggerActionView: UICollectionViewCell {
    
    private lazy var segmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: [
            R.string.localizable.simple(),
            R.string.localizable.hold(),
            R.string.localizable.combo()
        ], index: triggerItem.action.rawValue))
        view.didSelectIndex = { [weak self] index in
            guard let self = self else { return }
            if let action = TriggerItem.Action(rawValue: index) {
                switch action {
                case .simple:
                    simpleActionView.isHidden = false
                    holdActionView.isHidden = true
                    comboActionView.isHidden = true
                case .hold:
                    simpleActionView.isHidden = true
                    holdActionView.isHidden = false
                    comboActionView.isHidden = true
                case .combo:
                    simpleActionView.isHidden = true
                    holdActionView.isHidden = true
                    comboActionView.isHidden = false
                }
                self.triggerItem.action = action
                self.didActionChange?()
            }
        }
        return view
    }()
    
    private lazy var simpleActionView: AddTriggerActionSimpleView = {
        let view = AddTriggerActionSimpleView(triggerItem: triggerItem)
        return view
    }()
    
    private lazy var holdActionView: AddTriggerActionHoldView = {
        let view = AddTriggerActionHoldView(triggerItem: triggerItem)
        return view
    }()
    
    private lazy var comboActionView: AddTriggerActionComboView = {
        let view = AddTriggerActionComboView(triggerItem: triggerItem)
        return view
    }()
    
    private let triggerItem: TriggerItem
    
    var didActionChange: (() -> Void)? = nil
    
    init(triggerItem: TriggerItem) {
        self.triggerItem = triggerItem
        super.init(frame: .zero)
        
        addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightSmall)
        }
        
        addSubview(simpleActionView)
        simpleActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(120)
        }
        
        holdActionView.isHidden = true
        addSubview(holdActionView)
        holdActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(120)
        }
        
        addSubview(comboActionView)
        comboActionView.isHidden = true
        comboActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(120)
        }
        
        switch triggerItem.action {
        case .simple:
            simpleActionView.isHidden = false
            holdActionView.isHidden = true
            comboActionView.isHidden = true
        case .hold:
            simpleActionView.isHidden = true
            holdActionView.isHidden = false
            comboActionView.isHidden = true
        case .combo:
            simpleActionView.isHidden = true
            holdActionView.isHidden = true
            comboActionView.isHidden = false
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
