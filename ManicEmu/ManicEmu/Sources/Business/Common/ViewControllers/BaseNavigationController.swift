//
//  BaseNavigationController.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class BaseNavigationController: UINavigationController {
    deinit {
        Log.verbose("✅ \(objectInfo(self)) deinit")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        Log.verbose("⚠️ \(objectInfo(self)) init")
        configStyle()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        Log.verbose("⚠️ \(objectInfo(self)) init")
        configStyle()
    }
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        Log.verbose("⚠️ \(objectInfo(self)) init")
        configStyle()
    }
    
    func configStyle() {
        if let sheetPresentationController = self.sheetPresentationController {
            sheetPresentationController.preferredCornerRadius = R.Size.CornerRadiusLarge
        }
    }
}
