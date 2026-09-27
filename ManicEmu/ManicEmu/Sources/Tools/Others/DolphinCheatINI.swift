//
//  DolphinCheatINI.swift
//  ManicEmu
//
//  Writes Manic cheat codes into the local Dolphin GameSettings ini.
//  Only [ActionReplay]/[Gecko] (and their Enabled/Disabled lists) are replaced.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import RealmSwift

enum DolphinCheatINI {

    static func sync(game: Game) {
        guard game.isDolphinCore else { return }
        guard let gameID = game.gameIDForDolphin, !gameID.isEmpty else { return }

        let cheats = Array(game.gameCheats.where({ !$0.isDeleted }))
        let iniURL = URL(fileURLWithPath: R.Path.DolphinGameSettings).appendingPathComponent("\(sanitizedFileName(gameID)).ini")

        if cheats.isEmpty, !FileManager.default.fileExists(atPath: iniURL.path) {
            return
        }

        let arCheats = cheats.filter {
            let type = CheatType($0.type)
            return type == .actionReplay || type == .ARMax
        }
        let geckoCheats = cheats.filter { CheatType($0.type) == .Gecko }

        var sections = loadSections(from: iniURL)
        replaceSection(&sections, name: "ActionReplay", lines: codeLines(arCheats))
        replaceSection(&sections, name: "ActionReplay_Enabled", lines: enabledNames(arCheats))
        replaceSection(&sections, name: "ActionReplay_Disabled", lines: disabledNames(arCheats))
        replaceSection(&sections, name: "Gecko", lines: codeLines(geckoCheats))
        replaceSection(&sections, name: "Gecko_Enabled", lines: enabledNames(geckoCheats))
        replaceSection(&sections, name: "Gecko_Disabled", lines: disabledNames(geckoCheats))

        do {
            try FileManager.default.createDirectory(at: iniURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try render(sections).write(to: iniURL, atomically: true, encoding: .utf8)
        } catch {
            Log.error("[DolphinCheatINI] failed to write \(iniURL.lastPathComponent): \(error)")
        }
    }

    private static func sanitizedFileName(_ gameID: String) -> String {
        gameID.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
    }

    private static func codeTitle(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutDollar = trimmed.hasPrefix("$") ? String(trimmed.dropFirst()) : trimmed
        return "$" + withoutDollar.replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
    }

    private static func enabledNames(_ cheats: [GameCheat]) -> [String] {
        cheats.filter(\.activate).map { codeTitle($0.name) }
    }

    private static func disabledNames(_ cheats: [GameCheat]) -> [String] {
        cheats.filter { !$0.activate }.map { codeTitle($0.name) }
    }

    private static func codeLines(_ cheats: [GameCheat]) -> [String] {
        var lines: [String] = []
        for cheat in cheats {
            lines.append(codeTitle(cheat.name))
            lines.append(contentsOf: operationLines(cheat))
        }
        return lines
    }

    private static func operationLines(_ cheat: GameCheat) -> [String] {
        let chunks = cheat.code
            .replacingOccurrences(of: "+", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if CheatType(cheat.type) == .ARMax {
            return chunks.compactMap(formatARMaxLine)
        }
        return chunks.map { $0.uppercased() }
    }

    private static func formatARMaxLine(_ line: String) -> String? {
        let compact = line.uppercased()
            .replacingOccurrences(of: "-", with: "")
            .filter { !$0.isWhitespace }
        if compact.count == 13 {
            let start = compact.startIndex
            let a = compact[start..<compact.index(start, offsetBy: 4)]
            let b = compact[compact.index(start, offsetBy: 4)..<compact.index(start, offsetBy: 8)]
            let c = compact[compact.index(start, offsetBy: 8)...]
            return "\(a)-\(b)-\(c)"
        }
        if line.split(separator: "-").count == 3 {
            return line.uppercased()
        }
        return nil
    }

    // MARK: - Section-preserving ini IO

    private struct INISections {
        var preamble: [String] = []
        var items: [(name: String, lines: [String])] = []
    }

    private static func loadSections(from url: URL) -> INISections {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return INISections()
        }
        var result = INISections()
        var currentName: String?
        var currentLines: [String] = []

        func flush() {
            if let currentName {
                result.items.append((currentName, currentLines))
            } else {
                result.preamble = currentLines
            }
            currentLines = []
        }

        for raw in text.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 {
                flush()
                currentName = String(trimmed.dropFirst().dropLast())
                continue
            }
            currentLines.append(raw)
        }
        flush()
        return result
    }

    private static func replaceSection(_ sections: inout INISections, name: String, lines: [String]) {
        if let index = sections.items.firstIndex(where: { $0.name == name }) {
            sections.items[index].lines = lines
        } else {
            sections.items.append((name, lines))
        }
    }

    private static func render(_ sections: INISections) -> String {
        var parts: [String] = []
        let preamble = trimTrailingEmpty(sections.preamble)
        if !preamble.isEmpty {
            parts.append(preamble.joined(separator: "\n"))
        }
        for item in sections.items {
            var block = "[\(item.name)]"
            let body = trimTrailingEmpty(item.lines)
            if !body.isEmpty {
                block += "\n" + body.joined(separator: "\n")
            }
            parts.append(block)
        }
        return parts.joined(separator: "\n\n") + "\n"
    }

    private static func trimTrailingEmpty(_ lines: [String]) -> [String] {
        var result = lines
        while result.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            result.removeLast()
        }
        return result
    }
}
