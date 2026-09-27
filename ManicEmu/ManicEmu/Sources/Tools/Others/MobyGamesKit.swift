//
//  MobyGamesKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/30.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import SQLite
import Fuse


struct MobyGamesKit {
    struct Result {
        var name: String
        var url: String
    }
    
    static func getGameInfoUrl(gameType: GameType, name: String, completion: ((URL)->Void)? = nil) {
        let gameTypeName = gameType == .fds ? GameType.nes.localizedShortName : gameType.localizedShortName
        let searchPattern = name
        DispatchQueue.global().async {
            do {
                let db = try Connection(R.Path.GamesDB)
                try db.key(R.Cipher.ManicKey)
                let table = Table(gameTypeName)
                let id = SQLite.Expression<Int>("id")
                let url = SQLite.Expression<String>("url")
                let name = SQLite.Expression<String>("name")
                let allGameInfos = try db.prepare(table)
                let fuse = Fuse()
                let pattern = fuse.createPattern(from: searchPattern)
                let matchList = allGameInfos.map({
                    let url = R.URLs.MobyGames.absoluteString.appendingPathComponent("game").appendingPathComponent("\($0[id])").appendingPathComponent($0[url])
                    return Result(name: $0[name], url: url)
                })
                if let result = matchList.min(by: {
                    if let result0 = fuse.search(pattern, in: $0.name) {
                        if let result1 = fuse.search(pattern, in: $1.name) {
                            return result0.score < result1.score
                        } else {
                            return true
                        }
                    } else if let _ = fuse.search(pattern, in: $1.name) {
                        return false
                    } else {
                        return true
                    }
                }) {
                    if let score = fuse.search(pattern, in: result.name)?.score, score < 0.35 {
                        //匹配结果OK
                        DispatchQueue.main.async {
                            completion?(URL(string: result.url) ?? R.URLs.MobyGames)
                        }
                    } else {
                        //匹配结果的相似度太低 放弃
                        DispatchQueue.main.async {
                            completion?(R.URLs.MobyGames)
                        }
                    }
                } else {
                    //无法匹配
                    DispatchQueue.main.async {
                        completion?(R.URLs.MobyGames)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(R.URLs.MobyGames)
                }
            }
        }
    }
    
    static func getGameInfoUrl(game: Game, completion: ((URL)->Void)? = nil) {
        self.getGameInfoUrl(gameType: game.gameType, name: game.translatedName ?? game.displayName, completion: completion)
    }
}
