//
//  ViewTransition.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/24.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

///Get screen rotation events by receiving notifications through Base View.
protocol ViewTransition where Self: BaseView {
    ///About to start rotating.
    ///The device's orientation is correct, but the window size is still using old data.
    ///belove iOS 16 orientation is not correct too!!!
    ///So for iOS 16 and below, this method is simulated using viewAlongsideTransition.
    func viewWillTransition()
    
    ///Rotation in progress, with implicit animation supported.
    ///Both the device orientation and window size are correct values.
    func viewAlongsideTransition()
    
    ///The rotation is done.
    ///Both the device orientation and window size are correct values.
    func viewDidTransition()
}

extension ViewTransition {
    func viewWillTransition() {}
    func viewAlongsideTransition() {}
    func viewDidTransition() {}
}
