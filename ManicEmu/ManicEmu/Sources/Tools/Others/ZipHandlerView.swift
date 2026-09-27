//
//  ZipHandlerView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/18.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import UIKit
import ProHUD

class ZipHandlerView: BaseView {
    static func show(urls: [URL],
                     completion: ((_ unzipUrls: [URL], _ noActionUrls: [URL])->Void)? = nil ) {
        var navigation = ASListPage.Navigation.defaultNavigation(title: R.string.localizable.zipHandlerTitle(),
                                                                 titleIcon: .symbolImage(R.image.zip_iconSymbols()))
        navigation.enableClose = false
        
        let sections: [ASListPage.Section] = [.init(cells: urls.map({ .iconTitleDetailCheckCell(title: $0.lastPathComponent) }),
                                                    header: .texts([.smallText(R.string.localizable.zipHandlerDetail(),
                                                                               numberOfLines: 0)], pin: false))]
        
        let bottom = ASButton.large(title: R.string.localizable.confirmTitle(),
                                    titleColor: R.Color.LabelPrimary.forceStyle(.dark),
                                    titleAlignment: .center,
                                    background: R.Color.Main)
        
        let listPage = ASListPage(navigation: navigation,
                                  sections: sections,
                                  bottom: bottom,
                                  backgroundColor: .clear)
        
        var selectedItems = Set<Int>()

        ASSheetView.show(.init(style: .listPage(listPage), enableGrabber: false),
                         action: { action, updation in
            if let listPageValue = action.listPageValue {
                if listPageValue.isBottom {
                    //comfirm
                    return .dismiss(completion: {
                        var unzipUrls = [URL]()
                        var noActionUrls = [URL]()
                        for (index, url) in urls.enumerated() {
                            if selectedItems.contains(index) {
                                unzipUrls.append(url)
                            } else {
                                noActionUrls.append(url)
                            }
                        }
                        completion?(unzipUrls, noActionUrls)
                    })
                } else if let index = listPageValue.normalItemValue?.indexPath.row {
                    if selectedItems.contains(index) {
                        //deselected
                        selectedItems.remove(index)
                    } else {
                        //selected
                        selectedItems.insert(index)
                    }
                    var newListPage = listPage
                    newListPage.sections[0].cells = urls.enumerated().map({
                        .iconTitleDetailCheckCell(title: $0.element.lastPathComponent,
                                                  isSelected: selectedItems.contains($0.offset))
                    })
                    updation?(.listPage(newListPage))
                    return .none
                }
            }
            return .none
        })
    }
}
