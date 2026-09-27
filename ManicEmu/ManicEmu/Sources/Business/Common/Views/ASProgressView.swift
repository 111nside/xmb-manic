//
//  ASProgressView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASProgressView: BaseView {
    class PercentageView: BaseView {
        ///0-1
        var value: Float = 0 {
            didSet {
                UIView.normalAnimate {
                    self.colorView.width = self.width * CGFloat(self.value)
                }
            }
        }
        
        private let colorView = UIView()
        
        init(_ progress: ASProgress) {
            super.init(frame: .zero)
            masksToBounds = true
            backgroundColor = progress.maxColor
            addSubview(colorView)
            colorView.backgroundColor = progress.minColor
            if case let .disabled(size) = progress.interaction {
                colorView.height = (size == .large ? R.Size.ProgressMedium : R.Size.ProgressSmall)
                layerCornerRadius = colorView.height/2
            }
            
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layerCornerRadius = height/2
            UIView.normalAnimate {
                self.colorView.width = self.width * CGFloat(self.value)
            }
        }
    }
    
    private lazy var sliderView: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = progress.minColor
        slider.maximumTrackTintColor = progress.maxColor
        slider.value = progress.value
        slider.on(.valueChanged) { [weak self] sender, forEvent in
            guard let self = self, let sender = sender as? UISlider else { return }
            self.updateShowValue(sender.value)
        }
        slider.on(.touchUpInside) { [weak self] sender, forEvent in
            guard let self = self, let sender = sender as? UISlider else { return }
            self.updateValue(sender.value)
        }
        slider.on(.touchUpOutside) { [weak self] sender, forEvent in
            guard let self = self, let sender = sender as? UISlider else { return }
            self.updateValue(sender.value)
        }
        slider.enableFocusAdjustment()
        slider.enableFocusEffects = false
        return slider
    }()
    
    
    
    private lazy var percentageView: PercentageView = {
        let view = PercentageView(progress)
        view.value = progress.value
        return view
    }()
    
    private lazy var valueLabel: ASLabelView = {
        let view = ASLabelView(text: .smallText(""))
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }()
    
    
    private var progress: ASProgress
    
    var didValueChange: ((Float)->Void)? = nil
    
    var value: Float {
        get { progress.value }
        set {
            switch progress.interaction {
            case .enabled:
                sliderView.value = newValue
            case .disabled(_):
                percentageView.value = newValue
            }
            updateShowValue(newValue)
        }
    }
    
    init(_ progress: ASProgress) {
        self.progress = progress
        super.init(frame: .zero)
        
        let isSlider: Bool
        switch progress.interaction {
        case .enabled:
            isSlider = true
            addSubview(sliderView)
            sliderView.snp.makeConstraints { make in
                if progress.showValue {
                    make.leading.top.bottom.equalToSuperview()
                } else {
                    make.edges.equalToSuperview()
                }
                make.height.equalTo(R.Size.ProgressLarge)
            }
            
            if progress.showValue {
                sliderView.setContentHuggingPriority(.defaultLow, for: .horizontal)
                sliderView.setContentCompressionResistancePriority(.required, for: .horizontal)
            }
            
        case .disabled(let size):
            isSlider = false
            addSubview(percentageView)
            percentageView.snp.makeConstraints { make in
                if progress.showValue {
                    make.leading.top.bottom.equalToSuperview()
                } else {
                    make.edges.equalToSuperview()
                }
                make.height.equalTo(size == .large ? R.Size.ProgressMedium : R.Size.ProgressSmall)
            }
            
            if progress.showValue {
                percentageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
                percentageView.setContentCompressionResistancePriority(.required, for: .horizontal)
            }
        }
        
        if progress.showValue {
            addSubview(valueLabel)
            valueLabel.snp.makeConstraints { make in
                make.top.trailing.bottom.equalToSuperview()
                make.leading.equalTo((isSlider ? sliderView : percentageView).snp.trailing).offset(R.Size.ContentSpaceSmall)
            }
            updateShowValue(progress.value)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateValue(_ value: Float) {
        if progress.value != value {
            progress.value = value
            didValueChange?(value)
            updateShowValue(value)
        }
    }
    
    private func updateShowValue(_ value: Float) {
        if progress.showValue {
            valueLabel.title = progress.valueDisplayFormatter?(value) ?? "\(value.rounded(numberOfDecimalPlaces: 1, rule: .up))"
        }
    }
}
