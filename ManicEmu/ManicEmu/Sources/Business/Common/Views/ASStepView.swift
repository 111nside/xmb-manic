//
//  ASStepView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASStepView: BaseView {
    var step: ASStep {
        didSet {
            updateViews()
        }
    }
    
    private let containerView = UIStackView()
    private let decreaseButton: ASButtonView
    private let increaseButton: ASButtonView
    private let titleLabel: ASLabelView
    
    var didStepChange: ((ASStep)->Void)? = nil
    
    init(_ step: ASStep) {
        self.step = step
        var fixIndex: Int = 0
        if step.index < step.titles.count {
            fixIndex = step.index
        }
        self.decreaseButton = ASButtonView(step.decrease.enableGlass(true))
        self.increaseButton = ASButtonView(step.increase.enableGlass(true))
        self.titleLabel = {
            if step.titles.count > 0 {
                return ASLabelView(text: step.titles[fixIndex])
            } else {
                return ASLabelView()
            }
        }()
        super.init(frame: .zero)
        
        containerView.alignment = .center
        containerView.distribution = .fill
        containerView.axis = .horizontal
        
        decreaseButton.setContentHuggingPriority(.required, for: .horizontal)
        decreaseButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        increaseButton.setContentHuggingPriority(.required, for: .horizontal)
        increaseButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.isAccessibilityElement = false
        
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addArrangedSubview(decreaseButton)
        containerView.addArrangedSubview(titleLabel)
        containerView.addArrangedSubview(increaseButton)
        
        decreaseButton.didTapButton = { [weak self] in
            guard let self, self.enableDecrease() else { return }
            if self.step.loopSelection, self.step.index == 0 {
                self.step.index = self.step.titles.count - 1
            } else {
                self.step.index -= 1
            }
            self.handleStepChange()
        }
        increaseButton.didTapButton = { [weak self] in
            guard let self, self.enableIncrease() else { return }
            if self.step.loopSelection, self.step.index == self.step.titles.count - 1 {
                self.step.index = 0
            } else {
                self.step.index += 1
            }
            self.handleStepChange()
        }
        
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        containerView.systemLayoutSizeFitting(
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        )
    }
    
    private func enableDecrease() -> Bool { step.titles.count > 0 && (step.loopSelection || step.index > 0) }
    
    private func enableIncrease() -> Bool { step.titles.count > 0 && (step.loopSelection || step.index < step.titles.count - 1) }
    
    
    
    private func handleStepChange() {
        UIDevice.generateHaptic(style: .rigid)
        if step.index < step.titles.count {
            titleLabel.text = step.titles[step.index]
            if !step.fixedWidth {
                invalidateIntrinsicContentSize()
            }
        }
        
        decreaseButton.state = enableDecrease() ? .normal : .disabled
        increaseButton.state = enableIncrease() ? .normal : .disabled
        
        didStepChange?(step)
    }
    
    private func updateViews() {
        containerView.spacing = step.spacing
        
        var fixIndex: Int = 0
        if step.index < step.titles.count {
            fixIndex = step.index
        }
        decreaseButton.button = step.decrease
        increaseButton.button = step.increase
        if step.titles.count > 0 {
            titleLabel.text = step.titles[fixIndex]
        } else {
            titleLabel.text = nil
        }
        
        if step.fixedWidth {
            let width = ASLabelView.maxContentWidth(in: step.titles)
            titleLabel.snp.remakeConstraints { make in
                make.width.equalTo(width)
            }
        } else {
            titleLabel.snp.removeConstraints()
        }
        
        
        decreaseButton.state = enableDecrease() ? .normal : .disabled
        increaseButton.state = enableIncrease() ? .normal : .disabled
    }
}
