//
//  MAMEBiosView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit

class MAMEBiosView: BaseView {    
    private lazy var listPageView: ASListPageView = {
        let mameBios = R.BIOS.MAMEBiosMap.map({
            BIOSItem(fileName: $0.key,
                     imported: FileManager.default.fileExists(atPath: R.Path.Data.appendingPathComponent($0.key)),
                     desc: $0.value,
                     required: false)
        }).sorted(by: {
            $0.fileName < $1.fileName
        })
        
        let sections = mameBios.map({
            ASListPage.Section(cells: [getCell(item: $0)])
        })
        
        let view = ASListPageView(.init(navigation: .defaultNavigation(title: R.Strings.MAMEBiosTitle,
                                                                       titleIcon: .symbolImage(R.image.bios_iconSymbols())),
                                             sections: sections,
                                             backgroundColor: .clear,
                                             pageInsets: .insets(top: R.Size.SheetGrabberTopInset)))
        view.didActionOccurred = { [weak self] action in
            if action.navigationValue?.isTapClose ?? false {
                self?.hide()
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
    
    private func getCell(item: BIOSItem) -> ASListPage.Cell {
        var styles = [ASListPage.Cell.Style]()
        styles.append(.title(.largeText(item.fileName)))
        styles.append(.detail(.extraSmallText(item.desc)))
        let importTitle: String
        if item.imported {
            importTitle = R.string.localizable.biosImported()
        } else {
            importTitle = ""
        }
        styles.append(.button(.large(title: importTitle,
                                     titleColor: R.Color.Green,
                                     background: .clear)))
        return .normal(styles, enablePressEffect: false)
    }
}

extension MAMEBiosView: ShowableView {
    
}
