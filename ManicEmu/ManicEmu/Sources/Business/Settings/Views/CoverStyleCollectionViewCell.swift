//
//  CoverStyleCollectionViewCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import BetterSegmentedControl

class CoverStyleCollectionViewCell: UICollectionViewCell {
    
    private lazy var segmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: [
            R.string.localizable.themeCoverStyleName(1),
            R.string.localizable.themeCoverStyleName(2),
            R.string.localizable.themeCoverStyleName(3)
        ], index: Theme.defalut.coverStyle.rawValue))
        
        view.didSelectIndex = { [weak self] index in
            guard let self else { return }
            if let style = CoverStyle(rawValue: index) {
                self.sliderView.value = Float(style.defaultCornerRadius()/style.maxCornerRadius())
                self.coverView.setData(gameType: ._3ds,
                                       image: UIImage.placeHolder(preferenceSize: CGSize(154),
                                                                  color: R.Color.BackgroundQuaternary),
                                       style: style,
                                       cornerRadius: CGFloat(self.sliderView.value) * style.maxCornerRadius())
                self.cornerRadiusLabel.text = "\(String(format: "%.0f", self.sliderView.value * 100))%"
                self.updateCoverStyle(style, ratio: self.sliderView.value)
            }
        }
        
        return view
    }()
    
    private var coverView: GameCoverView = {
        let view = GameCoverView()
        view.imageView.backgroundColor = R.Color.BackgroundTertiary
        view.backgroundColor = R.Color.BackgroundSecondary
        return view
    }()
    
    private var cornerRadiusLabel: UILabel = {
        let label = UILabel()
        label.font = R.Font.Body()
        label.textColor = R.Color.LabelPrimary
        return label
    }()
    
    private var sliderView: UISlider = {
        let view = UISlider()
        view.minimumValue = 0
        view.maximumValue = 1
        view.minimumTrackTintColor = R.Color.Main
        view.maximumTrackTintColor = R.Color.BackgroundTertiary
        view.enableFocusAdjustment()
        view.enableFocusEffects = false
        return view
    }()
    
    private lazy var forceSquareItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.square)))
        styles.append(.title(.largeText(R.string.localizable.forceSquareRatioTitle())))
        if UIDevice.isPad {
            styles.append(.detail(.extraSmallText(R.string.localizable.forceSquareRatioDetail())))
        }
        styles.append(.switch(.init(state: Theme.defalut.forceSquare ? .on : .off)))
        let view = ASListItemView()
        view.styles = styles
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                    case .switch = style,
                    let value = value as? Bool else { return }
            self.updateCoverForceSquare(value)
        }
        return view
    }()
    
    private lazy var hideGameTitleItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.characterTextbox)))
        styles.append(.title(.largeText(R.string.localizable.hideGameTitleDesc())))
        styles.append(.switch(.init(state: Theme.defalut.hideGameTitle ? .on : .off)))
        let view = ASListItemView()
        view.styles = styles
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                    case .switch = style,
                    let value = value as? Bool else { return }
            self.updateGameTitle(value)
        }
        return view
    }()
    
    private lazy var hideGameRatingItemView: ASListItemView = {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.icon(.symbol(.starCircle)))
        styles.append(.title(.largeText(R.string.localizable.hideGameRatingIcon())))
        let hideGameRating = Theme.defalut.getExtraBool(key: ExtraKey.hideGameRating.rawValue) ?? false
        styles.append(.switch(.init(state: hideGameRating ? .on : .off)))
        let view = ASListItemView()
        view.styles = styles
        view.didActionOccurred = { [weak self] style, value in
            guard let self,
                    case .switch = style,
                    let value = value as? Bool else { return }
            self.coverView.updateRating(esrp: value ? nil : .E)
            Theme.defalut.updateExtra(key: ExtraKey.hideGameRating.rawValue, value: value)
            R.Style.GameHideRating = value
            NotificationCenter.default.post(name: R.NotificationName.HideGameRating, object: nil)
        }
        return view
    }()
    
    private var mainColorChangeNotification: Any? = nil
    
    deinit {
        if let mainColorChangeNotification {
            NotificationCenter.default.removeObserver(mainColorChangeNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layerCornerRadius = R.Size.CornerRadiusLarge
        backgroundColor = R.Color.BackgroundSecondary
        
        let theme = Theme.defalut
        let style = theme.coverStyle
        
        let defaultImage = UIImage.placeHolder(preferenceSize: CGSize(154),
                                               color: R.Color.BackgroundQuaternary)
        
        addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightExtraSmall)
        }
        
        addSubview(coverView)
        coverView.snp.makeConstraints { make in
            make.size.equalTo(154)
            make.centerX.equalToSuperview()
            make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        coverView.setData(gameType: ._3ds,
                          image: defaultImage,
                          style: style,
                          cornerRadius: CGFloat(theme.coverRadiusRatio) * style.maxCornerRadius(),
                          scalePlatform: false)
        
        
        addSubview(cornerRadiusLabel)
        cornerRadiusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(R.Size.ContentSpaceHuge)
            make.top.equalTo(coverView.snp.bottom).offset(R.Size.ContentSpaceLarge)
        }
        cornerRadiusLabel.text = "\(String(format: "%.0f", theme.coverRadiusRatio * 100))%"
        
        addSubview(sliderView)
        sliderView.snp.makeConstraints { make in
            make.leading.equalTo(cornerRadiusLabel.snp.trailing).offset(R.Size.ContentSpaceHuge)
            make.centerY.equalTo(cornerRadiusLabel)
            make.trailing.equalToSuperview().offset(-R.Size.ContentSpaceHuge)
            make.height.equalTo(22)
        }
        sliderView.value = theme.coverRadiusRatio
        sliderView.on(.valueChanged) { [weak self] sender, forEvent in
            guard let self = self else { return }
            if let style = CoverStyle(rawValue: self.segmentView.index) {
                self.coverView.updateCornerRadius(CGFloat(self.sliderView.value) * style.maxCornerRadius())
                self.cornerRadiusLabel.text = "\(String(format: "%.0f", self.sliderView.value * 100))%"
            }
        }
        sliderView.on(.touchUpInside) { [weak self] sender, forEvent in
            guard let self = self else { return }
            self.updateCornerRadiusRatio(ratio: self.sliderView.value)
        }
        sliderView.on(.touchUpOutside) { [weak self] sender, forEvent in
            guard let self = self else { return }
            self.updateCornerRadiusRatio(ratio: self.sliderView.value)
        }
        
        let cornerContainer = UIView()
        cornerContainer.backgroundColor = R.Color.BackgroundTertiary
        cornerContainer.layerCornerRadius = R.Size.CornerRadiusMedium
        addSubview(cornerContainer)
        cornerContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.top.equalTo(sliderView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.height.equalTo(R.Size.ItemHeightLarge * 3)
        }
        
        cornerContainer.addSubview(forceSquareItemView)
        forceSquareItemView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        cornerContainer.addSubview(hideGameTitleItemView)
        hideGameTitleItemView.snp.makeConstraints { make in
            make.top.equalTo(forceSquareItemView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        cornerContainer.addSubview(hideGameRatingItemView)
        hideGameRatingItemView.snp.makeConstraints { make in
            make.top.equalTo(hideGameTitleItemView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightLarge)
        }
        
        //通知更新主色
        mainColorChangeNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.MainColorChange, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            self.sliderView.minimumTrackTintColor = R.Color.Main
            self.forceSquareItemView.switchButtons.forEach({ $0.onColor = R.Color.Main })
            self.hideGameTitleItemView.switchButtons.forEach({ $0.onColor = R.Color.Main })
            self.hideGameRatingItemView.switchButtons.forEach({ $0.onColor = R.Color.Main })
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateCornerRadiusRatio(ratio: Float) {
        let theme = Theme.defalut
        guard theme.coverRadiusRatio != ratio else { return }
        Theme.change { realm in
            theme.coverRadiusRatio = ratio
        }
    }
    
    private func updateCoverStyle(_ style: CoverStyle, ratio: Float) {
        let theme = Theme.defalut
        guard theme.coverRadiusRatio != ratio || theme.coverStyle != style else { return }
        Theme.change { realm in
            theme.coverStyle = style
            theme.coverRadiusRatio = ratio
        }
    }
    
    private func updateCoverForceSquare(_ forceSquare: Bool) {
        let theme = Theme.defalut
        guard theme.forceSquare != forceSquare else { return }
        Theme.change { realm in
            theme.forceSquare = forceSquare
        }
    }
    
    private func updateGameTitle(_ hideGameTitle: Bool) {
        let theme = Theme.defalut
        guard theme.hideGameTitle != hideGameTitle else { return }
        Theme.change { realm in
            theme.hideGameTitle = hideGameTitle
        }
    }
    
}
