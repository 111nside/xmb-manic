//
//  OptionsSheetView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/4/10.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class OptionsSheetView: BaseView {
    
    ///Show commonly used option sheet
    ///cancelEnable：If disabled, users won’t be able to close the form unless they make a selection.
    ///groupTogether: Should the options be grouped together, or should each option be treated as a separate group?
    ///optionType: What type of icon should be used at the end of each option
    ///completion：The execution will only take place after the sheet is dismissed.
    static func show(icon: ASIcon,
                     title: String,
                     detail: String? = nil,
                     options: [String],
                     selectedIndex: Int? = nil,
                     cancelEnable: Bool = true,
                     optionType: ASSheet.Style.OptionsType = .radio,
                     groupTogether: Bool = false,
                     completion: ((_ index: Int?)->Void)? = nil ) {
        guard options.count > 0 else {
            completion?(nil)
            return
        }
        
        var detailText: ASText? = nil
        if let detail {
            detailText = .smallText(detail, numberOfLines: 0)
        }
        
        var selectedIndexPath: IndexPath? = nil
        if let selectedIndex {
            selectedIndexPath = IndexPath(row: groupTogether ? selectedIndex : 0, section: groupTogether ? 0 : selectedIndex)
        }
        
        let sheetData = ASSheet(style: .options(icon: icon,
                                                title: title,
                                                detail: detailText,
                                                options: groupTogether ? [options] : options.map({ [$0] }),
                                                selectedIndexPath: selectedIndexPath,
                                                cancelEnable: cancelEnable,
                                                optionsType: optionType))
        
        var didComplete = false
        
        ASSheetView.show(sheetData, action: { sheetAction, _ in
            if let indexPath = sheetAction.listPageValue?.normalItemValue?.indexPath {
                didComplete = true
                return .dismiss {
                    completion?(groupTogether ? indexPath.row : indexPath.section)
                }
            } else if let isTapClose = sheetAction.listPageValue?.navigationValue?.isTapClose, isTapClose {
                didComplete = true
                return .dismiss {
                    completion?(nil)
                }
            }
            return .none
        }, dismiss: {
            if !didComplete {
                completion?(nil)
            }
        })
    }
}
