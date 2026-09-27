//
//  NimbusCollectionCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class NimbusCollectionCell: UICollectionViewCell {
    
    private lazy var descLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        let text = R.string.localizable.pretendoNimbusDesc()
        let matt = NSMutableAttributedString(string: text, attributes: [.font: R.Font.Footnote(), .foregroundColor: R.Color.LabelSecondary])
        let style = NSMutableParagraphStyle()
        style.lineSpacing = R.Size.ContentSpaceTiny
        style.alignment = .left
        label.attributedText = matt.applying(attributes: [.paragraphStyle: style])
        return label
    }()
    
    private lazy var button: SymbolButton = {
        let view = SymbolButton(image: nil,
                                title: R.string.localizable.installNimbus(),
                                titleFont: R.Font.Body2(),
                                titleColor: R.Color.LabelSecondary,
                                titleAlignment: .right,
                                horizontalContian: true)
        view.backgroundColor = R.Color.BackgroundTertiary
        view.isUserInteractionEnabled = false
        view.addTapGesture { [weak self] gesture in
            guard let self else { return }
            self.didTapButton?()
        }
        return view
    }()
    
    var didTapButton: (()->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = R.Size.CornerRadiusLarge
        containerView.backgroundColor = R.Color.BackgroundSecondary
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
        }
        
        containerView.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(descLabel.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ItemHeightMedium)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(config: PretendoNetworkingConfig) {
        if config.articBaseDone {
            button.isUserInteractionEnabled = true
            button.titleLabel.textColor = R.Color.LabelPrimary
            button.backgroundColor = R.Color.Main
        } else {
            button.isUserInteractionEnabled = false
            button.titleLabel.textColor = R.Color.LabelSecondary
            button.backgroundColor = R.Color.BackgroundTertiary
        }
    }
}
