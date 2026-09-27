//
//  PageBackgroundMaskView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class PageBackgroundMaskView: UIView {
    private let gradientView = GradientView()
    
    init() {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        updateViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateViews() {
        let bg = R.Color.BackgroundPrimary
        let bgDark = R.Color.BackgroundPrimary.forceStyle(.dark)
        let bgLight = R.Color.BackgroundPrimary.forceStyle(.light)
        let top = UIColor(.dm,
                          light: bgLight.blended(with: .black, fraction: 0.05),
                          dark: bgDark.blended(with: .white, fraction: 0.05))
        let mid = UIColor(.dm,
                          light: bgLight.blended(with: .black, fraction: 0.025),
                          dark: bgDark.blended(with: .white, fraction: 0.025))
        gradientView.setupGradient(
            colors: [top, mid, bg],
            locations: [0.0, 0.3 ,1.0],
            direction: .topToBottom
        )
    }
}
