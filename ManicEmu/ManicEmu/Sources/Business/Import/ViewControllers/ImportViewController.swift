//
//  ImportViewController.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2024/12/29.
//  Copyright © 2024 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import SideMenu

class ImportViewController: BaseViewController {
    private var cornerMaskViewForiPad: TransparentHoleView = {
        let view = TransparentHoleView()
        return view
    }()
    
    private lazy var importServiceListView: ImportServiceListView = {
        let view = ImportServiceListView()
        view.didTapAddService = { [weak self] in
            guard let self = self else { return }
            self.showSideMenu()
        }
        return view
    }()
    
    private lazy var addImportServiceView: AddImportServiceView = {
        let view = AddImportServiceView()
        view.requireToHideSideMenu = { [weak self] in
            guard let self = self else { return }
            self.hideSideMenu()
        }
        return view
    }()
    
    private weak var sideMenu: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.isPhone {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.hideSideMenu()
            }
        }
    }
    
    private func setupViews() {
        if UIDevice.isPhone {
            view.addSubview(importServiceListView)
            importServiceListView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            }
        } else {
            view.backgroundColor = UIColor(.dm, light: .white, dark: .black)
            importServiceListView.backgroundColor = R.Color.BackgroundPrimary
            view.addSubview(importServiceListView)
            importServiceListView.snp.makeConstraints { make in
                make.top.bottom.trailing.equalToSuperview()
                make.width.equalToSuperview().offset(-R.Size.SideMenuWidth*1.2)
            }
            
            view.addSubview(addImportServiceView)
            addImportServiceView.snp.makeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.trailing.equalTo(importServiceListView.snp.leading)
            }
            
            view.addSubview(cornerMaskViewForiPad)
            cornerMaskViewForiPad.snp.makeConstraints { make in
                make.edges.equalTo(importServiceListView)
            }
        }
    }
    
    override func handleScreenPanGesture(edges: UIRectEdge, gesture: UIScreenEdgePanGestureRecognizer) {
        if UIDevice.isPhone || (UIDevice.isPad && !UIDevice.isLandscape) {
            if edges == .left {
                showSideMenu()
            }
        }
    }
    
    private func showSideMenu() {
        UIDevice.generateHaptic()
        let containerVC = BaseViewController()
        containerVC.enableBackgroundMask = false
        containerVC.view.backgroundColor = .clear
        containerVC.view.addSubview(addImportServiceView)
        addImportServiceView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        let menu = SideMenuNavigationController(rootViewController: containerVC)
        menu.navigationBar.isHidden = true
        menu.presentDuration = R.Numbers.LongAnimationDuration
        menu.dismissDuration = R.Numbers.LongAnimationDuration
        menu.leftSide = !Locale.isRTLLanguage
        menu.menuWidth = R.Size.SideMenuWidth
        menu.presentationStyle = SideMenuShowStyle()
        topViewController()?.present(menu, animated: true)
        sideMenu = menu
    }
    
    private func hideSideMenu() {
        sideMenu?.dismiss(animated: true)
    }
}

