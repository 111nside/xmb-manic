//
//  ImportServiceListCollectionViewCell.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit

class ImportServiceListCollectionViewCell: UICollectionViewCell {
    var didValueChange: ((Bool)->Void)? = nil
    
    private var carView = ASCardView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        enablePressEffect = true
        
        addSubview(carView)
        carView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setData(service: ImportService) {
        let enableSwitch = service.type == .wifi
        let switchState: ASSwitch.State = (enableSwitch && WebServer.shard.isRunning) ? .on : .off
        
         
        carView.setData(icon: .image(service.iconImage),
                        iconBackgroundColor: service.iconBackgroundColor,
                        iconBorderColor: service.iconBorderColor,
                        iconCornerRadius: service.iconCornerRadius,
                        title: service.title,
                        detail: service.detail,
                        enableSwitch: enableSwitch,
                        switchState: switchState,
                        didSwitchChange: enableSwitch ? { [weak self] isOn in
            self?.didValueChange?(isOn)
        } : nil)
    }
    
}
