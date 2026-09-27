//
//  Functions.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

func objectInfo(_ object: AnyObject) -> String {
    "\(NSStringFromClass(type(of: object))): \(Unmanaged.passUnretained(object).toOpaque())"
}

func topViewController(appController: Bool = false) -> UIViewController? {
    if appController {
        //如果设置为true则只找自己应用的window 弹窗那些window就不去找了
        if let vc = topViewController(rootViewController: ApplicationSceneDelegate.applicationWindow?.rootViewController) {
            return vc
        }
    } else if let window = UIWindow.topWindow,
              let vc = topViewController(rootViewController: window.rootViewController) {
        return vc
    }
    return nil
}

private func topViewController(rootViewController: UIViewController?) -> UIViewController? {
    if rootViewController is UITabBarController, let vc = (rootViewController as! UITabBarController).selectedViewController {
        return topViewController(rootViewController: vc)
    } else if rootViewController is UINavigationController, let vc = (rootViewController as! UINavigationController).visibleViewController {
        return topViewController(rootViewController: vc)
    } else if let vc = rootViewController?.presentedViewController {
        return topViewController(rootViewController: vc)
    } else {
        return rootViewController
    }
}
