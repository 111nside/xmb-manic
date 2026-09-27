//
//  ASCheckView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/11.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASCheckView: BaseView {
    private let buttonView: ASButtonView
    
    var didTapButton: (()->Void)? = nil {
        didSet {
            buttonView.didTapButton = didTapButton
        }
    }
    
    var isSelected: Bool {
        didSet {
            guard isSelected != oldValue else { return }
            updateViews()
        }
    }
    
    private static func getIcon(_ isSelected: Bool) -> ASIcon  {
        ASIcon.symbol(isSelected ? .checkmarkCircleFill : .circle,
                      colors: isSelected ? [.white, R.Color.Main] : [R.Color.LabelTertiary])
    }
    
    init(_ check: ASCheck) {
        self.isSelected = check.isSelected
        self.buttonView = ASButtonView(.iconOnly(icon: Self.getIcon(isSelected),
                                                 iconSize: R.Size.ButtonSizeAccessory,
                                                 background: .clear))
        super.init(frame: .zero)
        
        if !check.enableInteration {
            buttonView.state = .disabled
        }
        
        buttonView.didTapButton = didTapButton
        
        addSubview(buttonView)
        buttonView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        buttonView.intrinsicContentSize
    }
    
    private func updateViews() {
        buttonView.setIcon(Self.getIcon(isSelected))
    }
}
