//
//  MAMEKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/11/18.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import SQLite

struct MAMEKit {
    static func isSupportTitle(fileName: String) -> Bool {
        do {
            let db = try Connection(R.Path.MAMEDB)
            try db.key(R.Cipher.ManicKey)
            let table = Table("Title")
            let title = SQLite.Expression<String>("title")
            let allTitles = try db.prepare(table)
            return allTitles.first(where: { $0[title] == fileName }) != nil
        } catch {
            return false
        }
    }
    
    static func getMAMEInfo(fileName: String) -> (title: String, name: String)? {
        do {
            let db = try Connection(R.Path.MAMEDB)
            try db.key(R.Cipher.ManicKey)
            let table = Table("Title")
            let title = SQLite.Expression<String>("title")
            let name = SQLite.Expression<String>("name")
            let allTitles = try db.prepare(table)
            if let row = allTitles.first(where: { $0[title] == fileName }) {
                return (row[title], row[name])
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}
