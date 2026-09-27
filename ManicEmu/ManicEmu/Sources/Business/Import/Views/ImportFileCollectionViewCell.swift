//
//  ImportFileCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/23.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class ImportFileCollectionViewCell: UICollectionViewCell {
    private var iconView: ServiceIconView = {
        let view = ServiceIconView(roundCorner: .allCorners)
        return view
    }()
    
    private var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        return view
    }()
    
    private var infoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = R.Color.BackgroundSecondary
        return view
    }()
    
    var topLeftGradientView = UIImageView()
    var bottomRightGradientView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enablePressEffect = true
        layerCornerRadius = R.Size.CornerRadiusLarge
        
        infoContainerView.addSubview(topLeftGradientView)
        topLeftGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        infoContainerView.addSubview(bottomRightGradientView)
        bottomRightGradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(infoContainerView)
        infoContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(100)
        }
        
        infoContainerView.addSubviews([iconView, titleLabel])
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(R.Size.ContentSpaceLarge)
            make.centerY.equalToSuperview()
            make.size.equalTo(48)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(R.Size.ContentSpaceSmall)
            make.trailing.equalToSuperview().inset(R.Size.ContentSpaceLarge)
            make.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.size
        guard size != .zero else { return }
        
        if topLeftGradientView.image == nil {
            UIImage.radialGradientImage(size: size, colors: [R.Color.Indigo.forceStyle(.dark).withAlphaComponent(0.5), .clear], startCenter: CGPoint(x: 0, y: 0)) { [weak self] topLeftDarkImage in
                UIImage.radialGradientImage(size: size, colors: [R.Color.Indigo.forceStyle(.light).withAlphaComponent(0.5), R.Color.BackgroundSecondary.forceStyle(.light).withAlphaComponent(0)], startCenter: CGPoint(x: 0, y: 0)) { [weak self] topLeftLightImage in
                    if let topLeftDarkImage, let topLeftLightImage {
                        self?.topLeftGradientView.image = UIImage(.dm, light: topLeftLightImage, dark: topLeftDarkImage)
                    }
                }
            }
        }
        
        if bottomRightGradientView.image == nil {
            UIImage.radialGradientImage(size: size, colors: [R.Color.Indigo.forceStyle(.dark).withAlphaComponent(0.5), .clear], startCenter: CGPoint(x: 1, y: 1)) { [weak self] bottomRightDarkImage in
                UIImage.radialGradientImage(size: size, colors: [R.Color.Indigo.forceStyle(.light).withAlphaComponent(0.5), R.Color.BackgroundSecondary.forceStyle(.light).withAlphaComponent(0) ], startCenter: CGPoint(x: 1, y: 1)) { [weak self] bottomRightLightImage in
                    if let bottomRightDarkImage, let bottomRightLightImage {
                        self?.bottomRightGradientView.image = UIImage(.dm, light: bottomRightLightImage, dark: bottomRightDarkImage)
                    }
                }
            }
        }
    }
    
    func setData(service: ImportService) {
        
        iconView.imageView.image = service.iconImage
        iconView.backgroundColor = service.iconBackgroundColor
        iconView.borderColor = service.iconBorderColor
        iconView.radius = service.iconCornerRadius
        titleLabel.text = service.title
        
        var matt = NSMutableAttributedString(string: service.title, attributes: [.font: R.Font.Body(emphasis: true), .foregroundColor: R.Color.LabelPrimary])
        if let detail = service.detail {
            matt.append(NSAttributedString(string: "\n" + detail, attributes: [.font: R.Font.Caption(), .foregroundColor: R.Color.LabelSecondary]))
            let style = NSMutableParagraphStyle()
            style.lineSpacing = R.Size.ContentSpaceTiny/2
            matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        style.lineSpacing = R.Size.ContentSpaceTiny
        matt = matt.applying(attributes: [.paragraphStyle: style]) as! NSMutableAttributedString
        titleLabel.attributedText = matt
    }
    
}
