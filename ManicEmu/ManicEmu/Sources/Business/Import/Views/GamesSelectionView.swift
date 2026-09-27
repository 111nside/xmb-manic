//
//  GamesSelectionView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/3.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import RealmSwift

class GamesSelectionView: BaseView {
    
    static func show(title: String,
                     detail: String? = nil,
                     showGames: [Game]?,
                     groupByType: Bool = true,
                     completion: ((Game?) -> Void)? = nil) {
        let games: [Game]
        if let showGames, showGames.count > 0 {
            games = showGames
        } else {
            games = Array(Database.realm.objects(Game.self).where({ !$0.isDeleted }))
        }
        guard games.count > 0 else {
            UIView.makeToast(message: R.string.localizable.transferPakNoGames())
            return
        }
        
        var detailText: ASText? = nil
        if let detail {
            detailText = ASText.smallText(detail + "\n", numberOfLines: 0)
        }
        var gameGroups = [[Game]]()
        var sections = [ASListPage.Section]()
        
        if groupByType {
            let predefinedOrder = System.allGameTypes
            gameGroups = games.grouped(by: { $0.gameType }).sorted(by: {
                if let lGame = $0.first,
                   let rGame = $1.first,
                   let left = predefinedOrder.firstIndex(of: lGame.gameType),
                   let right = predefinedOrder.firstIndex(of: rGame.gameType) {
                    return left < right
                }
                return false
            })
            sections = gameGroups.enumerated().map { index, typeGames in
                var headerTexts = [ASText]()
                if index == 0, let detailText {
                    headerTexts.append(detailText)
                }
                if let gameType = typeGames.first?.gameType {
                    headerTexts.append(.init(attributes: .init(text: gameType.localizedShortName,
                                                               color: R.Color.LabelSecondary,
                                                               font: R.Font.Subheadline(emphasis: true))))
                }
                return ASListPage.Section(cells: typeGames.map({
                    .iconTitleDetailChevronCell(icon: $0.gameCoverIcon,
                                                iconSize: R.Size.ButtonMedium,
                                                title: $0.displayName)
                }), header: .texts(headerTexts, pin: false))
            }
        } else {
            gameGroups = games.map { [$0] }
            sections = games.map {
                ASListPage.Section(cells: [.iconTitleDetailChevronCell(icon: $0.gameCoverIcon,
                                                                       iconSize: R.Size.ButtonMedium,
                                                                       title: $0.displayName)])
            }
            if sections.count > 0, let detailText {
                sections[0].header = .texts([detailText], pin: false)
            }
        }
        
        let listPage = ASListPage(navigation: .defaultNavigation(title: title,
                                                                 titleIcon: .symbolImage(R.image.controller_iconSymbols())),
                                  sections: sections,
                                  backgroundColor: .clear)
        var isFunctionDismiss = false
        ASSheetView.show(.init(style: .listPage(listPage)), action: { action, _ in
            if let indexPath = action.listPageValue?.normalItemValue?.indexPath,
               indexPath.section < gameGroups.count,
               indexPath.row < gameGroups[indexPath.section].count {
                let game = gameGroups[indexPath.section][indexPath.row]
                isFunctionDismiss = true
                return .dismiss(completion: {
                    completion?(game)
                })
            }
            isFunctionDismiss = true
            return .dismiss(completion: {
                completion?(nil)
            })
        }, dismiss: {
            if !isFunctionDismiss {
                completion?(nil)
            }
        })
    }
    
    ///Import save to match game screen
    static func showSaveMatch(title: String,
                              detail: String,
                              gameSaveUrl: URL,
                              showGames: [Game]? = nil,
                              completion: (()->Void)? = nil) {
        
        let groupByType: Bool
        if let showGames, showGames.count > 0 {
            groupByType = false
        } else {
            groupByType = true
        }
        show(title: title,
             detail: detail,
             showGames: showGames,
             groupByType: groupByType,
             completion: { game in
            if let game {
                func copyGameSave() {
                    var url = gameSaveUrl
                    if game.gameType == .j2me,
                       game.defaultCore == 0,
                       let fixedUrl = Database.fixJ2meJSSave(fileName: game.fileName, url: url) {
                        url = fixedUrl
                    }
                    try? FileManager.safeCopyItem(at: url, to: game.gameSaveUrl, shouldReplace: true)
                    SyncManager.upload(localFilePath: game.gameSaveUrl.path)
                    UIView.makeToast(message: R.string.localizable.importGameSaveSuccessTitle())
                    completion?()
                }
                
                if game.isSaveExtsts {
                    UIView.makeAlert(title: R.string.localizable.gameSaveAlreadyExistTitle(),
                                     detail: R.string.localizable.filesImporterErrorSaveAlreadyExist(gameSaveUrl.lastPathComponent),
                                     confirmTitle: R.string.localizable.confirmTitle(),
                                     enableForceHide: false,
                                     cancelAction: {
                        completion?()
                    }, confirmAction: {
                        copyGameSave()
                    })
                } else {
                    copyGameSave()
                }
            }
        })
    }
}
