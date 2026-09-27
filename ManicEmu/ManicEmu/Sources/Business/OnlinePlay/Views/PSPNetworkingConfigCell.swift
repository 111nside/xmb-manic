//
//  PSPNetworkingConfigCell.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import BetterSegmentedControl

class PSPNetworkingConfigCell: UICollectionViewCell {
    private lazy var segmentView: ASSegmentView = {
        let view = ASSegmentView(.textSegment(titles: [
            R.string.localizable.lanNetworking(),
            R.string.localizable.wanNetworking()
        ]))
        
        view.didSelectIndex = { [weak self] index in
            guard let self else { return }
            self.didTypeChange?(index == 0 ? .local : .online)
        }
        return view
    }()
    
    private lazy var localNerworkingView: PSPNetworkingConfigLocalView = {
        let view = PSPNetworkingConfigLocalView()
        view.didAsHostChange = { [weak self] asHost in
            self?.didAsHostChange?(asHost)
        }
        view.didPortChange = { [weak self] port in
            self?.didPortChange?(port)
        }
        view.didConnectedIPChange = { [weak self] connectedIP in
            self?.didConnectedIPChange?(connectedIP)
        }
        view.isHidden = true
        return view
    }()
    
    private lazy var onlineNerworkingView: PSPNetworkingConfigOnlineView = {
        let view = PSPNetworkingConfigOnlineView()
        view.didConnectedHostChange = { [weak self] connectedHost in
            self?.didConnectedHostChange?(connectedHost)
        }
        view.isHidden = true
        return view
    }()
    
    var didTypeChange: ((PSPNetworkingConfig.ConfigType)->Void)? = nil
    var didAsHostChange: ((Bool)->Void)? = nil
    var didPortChange: ((Int32)->Void)? = nil
    var didConnectedHostChange: ((String?)->Void)? = nil
    var didConnectedIPChange: ((String?)->Void)? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let containerView = UIView()
        containerView.layerCornerRadius = R.Size.CornerRadiusLarge
        containerView.backgroundColor = R.Color.BackgroundSecondary
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(segmentView)
        segmentView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(R.Size.ContentSpaceMedium)
            make.height.equalTo(R.Size.ItemHeightExtraSmall)
        }
        
        containerView.addSubview(localNerworkingView)
        localNerworkingView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.bottom.equalToSuperview().inset(R.Size.ContentSpaceHuge)
        }
        
        containerView.addSubview(onlineNerworkingView)
        onlineNerworkingView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(segmentView.snp.bottom).offset(R.Size.ContentSpaceLarge)
            make.bottom.equalToSuperview().inset(R.Size.ContentSpaceHuge)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(config: PSPNetworkingConfig) {
        segmentView.index = config.type == .local ? 0 : 1
        if config.type == .local {
            localNerworkingView.isHidden = false
            onlineNerworkingView.isHidden = true
            localNerworkingView.setData(config: config)
        } else {
            localNerworkingView.isHidden = true
            onlineNerworkingView.isHidden = false
            onlineNerworkingView.setData(config: config)
        }
    }
    
    static func CellHeight(config: PSPNetworkingConfig) -> Double {
        var configHeight: CGFloat = 0
        if config.type == .local {
            if config.asHost {
                configHeight = 148
            } else {
                let serviceItemCount = config.hostList.count
                let serviceListHeight = 60*CGFloat(serviceItemCount) + 20*(CGFloat(serviceItemCount)-1) + 10
                configHeight = 44 + 48 + 60 + 48 + (serviceListHeight > 0 ? serviceListHeight : 0) - 11
            }
        } else {
            configHeight = 44
        }
        return 16 + 50 + 20 + configHeight + 24
    }
}
