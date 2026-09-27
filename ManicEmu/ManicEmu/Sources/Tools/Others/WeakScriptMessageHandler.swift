//
//  WeakScriptMessageHandler.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/28.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import WebKit

final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {

    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
