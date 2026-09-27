//
//  SettingsMembershipView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/24.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class SettingsMembershipView: BaseView {
    
    private lazy var animatedGradientView: AnimatedGradientView = {
        let view = AnimatedGradientView(notifiedUpadate: true, alphaComponent: 0.9)
        return view
    }()
    
    private var membershipInfoView = MembershipInfoView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        enablePressEffect = true
        enableFocusEffects = false
        
        let containerView = UIView()
        containerView.layerCornerRadius = R.Size.CornerRadiusLarge
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        containerView.addSubview(animatedGradientView)
        animatedGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(membershipInfoView)
        membershipInfoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
