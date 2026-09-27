//
//  WFCSettingView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/7.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit


class WFCSettingView: BaseView {
    
    private lazy var wfcs: [WFC] = {
        return WFC.getList()
    }()
    
    private lazy var listPageView: ASListPageView = {
        let view = ASListPageView(getListPage())
        view.didActionOccurred = { [weak self] action in
            guard let self else { return }
            if let navigationValue = action.navigationValue {
                if navigationValue.isTapClose {
                    self.hide()
                } else if let _ = navigationValue.tapToolsValue {
                    UIView.makeLoading()
                    WFC.refreshList { [weak self] wfs in
                        UIView.hideLoading()
                        guard let self else { return }
                        self.wfcs = wfs
                        self.updateViews()
                    }
                }
            } else if let index = action.normalItemValue?.indexPath.section {
                let wfcs = self.wfcs
                guard wfcs.count > index else { return }
                let wfc = wfcs[index]
                if let _ = action.normalItemValue?.subActions {
                    if let url = URL(string: wfc.url) {
                        ASWebView.show(url: url)
                    }
                } else {
                    self.wfcs = WFC.selectWFC(wfc)
                    self.updateViews()
                }
            } else if action.isBottom {
                UIView.makeAlert(title: R.string.localizable.dsWfcReset(),
                                 detail: R.string.localizable.dsWfcResetAlert(),
                                 confirmTitle: R.string.localizable.confirmTitle(),
                                 confirmAction: { [weak self] in
                    guard let self else { return }
                    WFC.resetWFC()
                    UIView.makeToast(message: R.string.localizable.toastSuccess())
                })
            }
        }
        return view
    }()
    
    required init?(parameters: Any...) {
        super.init(frame: .zero)
        addSubview(listPageView)
        listPageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getCell(wfc: WFC) -> ASListPage.Cell {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.title(.largeText(wfc.name)))
        styles.append(.detail(.extraSmallText(wfc.dns)))
        styles.append(.button(.smallIconButton(icon: .symbolImage(R.image.info_iconSymbols(),
                                                                  colors: [R.Color.LabelSecondary]),
                                               background: .clear,
                                               insets: .init(inset: R.Size.ContentSpaceExtraExtraSmall))))
        styles.append(.radio(.init(isSelected: wfc.isSelect)))
        return .normal(styles)
    }
    
    private func getListPage() -> ASListPage {
        let navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.nintendoWFC(),
                                                                 titleIcon: .symbolImage(R.image.online_iconSymbols()),
                                                                 tools: [.symbolImage(R.image.refresh_iconSymbols())])
        
        let sections = wfcs.map({
            ASListPage.Section(cells: [getCell(wfc: $0)])
        })
        return ASListPage(navigation: navigation,
                          sections: sections,
                          bottom: .extraLarge(title: R.string.localizable.dsWfcReset(),
                                              titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                              titleAlignment: .center,
                                              background: R.Color.Main),
                          backgroundColor: .clear,
                          pageInsets: .insets(top: R.Size.SheetGrabberTopInset))
    }
    
    private func updateViews() {
        listPageView.updatePage(getListPage())
    }
}

extension WFCSettingView: ShowableView {
    
}
