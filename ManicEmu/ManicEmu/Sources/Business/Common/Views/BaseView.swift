//
//  BaseView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/24.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class BaseView: UIView {
    private var viewWillTransitionNotification: Any? = nil
    private var viewAlongsideTransitionNotification: Any? = nil
    private var viewDidTransitionNotification: Any? = nil
    
    deinit {
        Log.verbose("✅ \(objectInfo(self)) deinit")
        
        if let viewWillTransitionNotification {
            NotificationCenter.default.removeObserver(viewWillTransitionNotification)
        }
        
        if let viewAlongsideTransitionNotification {
            NotificationCenter.default.removeObserver(viewAlongsideTransitionNotification)
        }
        
        if let viewDidTransitionNotification {
            NotificationCenter.default.removeObserver(viewDidTransitionNotification)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        Log.verbose("⚠️ \(objectInfo(self)) init")
        if let viewTransition = self as? ViewTransition {
            viewWillTransitionNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.ViewWillTransition,
                                                                                    object: nil,
                                                                                    queue: .main,
                                                                                    using: { [weak viewTransition] _ in
                guard let viewTransition,
                        let _ = viewTransition.superview else { return }
                viewTransition.viewWillTransition()
            })
            
            viewAlongsideTransitionNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.ViewAlongsideTransition,
                                                                                         object: nil,
                                                                                         queue: .main,
                                                                                         using: { [weak viewTransition] _ in
                guard let viewTransition,
                        let _ = viewTransition.superview else { return }
                viewTransition.viewAlongsideTransition()
            })
            
            viewDidTransitionNotification = NotificationCenter.default.addObserver(forName: R.NotificationName.ViewDidTransition,
                                                                                   object: nil,
                                                                                   queue: .main,
                                                                                   using: { [weak viewTransition] _ in
                guard let viewTransition,
                        let _ = viewTransition.superview else { return }
                viewTransition.viewDidTransition()
            })
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
