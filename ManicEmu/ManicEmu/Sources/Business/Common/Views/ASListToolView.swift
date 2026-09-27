//
//  ASListToolView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/17.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class ASListToolView: BaseView {
    private let mainButtonView: ASButtonView
    private let otherButtonsView = ASSymbolsButtonView()
    
    var tool: ASListPage.Tool {
        didSet {
            updateViews()
        }
    }
    
    var didTapToolButtons: ((ASListPage.Tool.Action) -> Void)? = nil
    
    init(_ tool: ASListPage.Tool) {
        var button = ASButton.iconOnly(icon: tool.mainIcon,
                                       iconSize: CGSize(R.Size.ButtonLarge),
                                       background: R.Color.BackgroundSecondary,
                                       insets: UIEdgeInsets(inset: R.Size.ContentSpaceExtraSmall))
        button.allAttributes[.normal]?.border = ASBorderStyle(color: R.Color.Border,
                                                              width: R.Size.Border)
        self.mainButtonView = ASButtonView(button)
        self.tool = tool
        super.init(frame: .zero)
        addSubview(mainButtonView)
        mainButtonView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        mainButtonView.didTapButton = { [weak self] in
            UIDevice.generateHaptic()
            self?.didTapToolButtons?(.tapMain)
        }
        
        updateViews()
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateViews() {
        mainButtonView.isHidden = tool.hideMainIcon
        
        if tool.otherIcons.count > 0 {
            if tool.otherIcons.count == 1 {
                otherButtonsView.containerInsets = UIEdgeInsets(inset: R.Size.ContentSpaceExtraSmall)
            } else {
                otherButtonsView.containerInsets = UIEdgeInsets(horizontal: R.Size.ContentSpaceMedium*2,
                                                                vertical: 10*2)
            }
            
            otherButtonsView.icons = tool.otherIcons
            addSubview(otherButtonsView)
            otherButtonsView.snp.remakeConstraints { make in
                make.leading.centerY.top.bottom.equalToSuperview()
            }
            otherButtonsView.layerBorderColor = R.Color.Border
            otherButtonsView.layerBorderWidth = R.Size.Border
            
            otherButtonsView.didTapButton = { [weak self] index in
                self?.didTapToolButtons?(.tapOthers(index: index))
            }
            
        } else {
            otherButtonsView.removeFromSuperview()
        }
    }
}
