//
//  PSP.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/5/14.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let psp = GameType("public.aoshuang.game.psp")
}

@objc enum PSPGameInput: Int, Input, CaseIterable {
    case a
    case b
    case x
    case y
    case start
    case select
    case up
    case down
    case left
    case right
    case l1
    case r1
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight

    case flex
    case menu

    var type: InputType {
        return .game(.psp)
    }
    
    var isContinuous: Bool {
        switch self
        {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        default: return false
        }
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp }
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown }
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft }
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct PSP: DeltaCoreProtocol {
    static let core = PSP()
    
    var name: String { "PSP" }
    var identifier: String { "com.aoshuang.PSPCore" }
    var version: String? { "1.0.0" }
    
    var gameType: GameType { GameType.psp }
    var gameInputType: Input.Type { PSPGameInput.self }
    var allInputs: [Input] { PSPGameInput.allCases }
    var gameSaveFileExtension: String { "psp.sav" }
    
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 480, height: 272))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let cwCheatFormat = CheatFormat(name: NSLocalizedString("CWCheat", comment: ""), format: "_L 0xXXXXXXXX 0xYYYYYYYY", type: .cwCheat)
        return [cwCheatFormat]
    }
    
    var emulatorBridge: EmulatorBridging { PSPEmulatorBridge.shared }
    
    private init() {}
    
    struct GameCheat {
        struct Cheat {
            let name: String
            let code: String
        }

        let gameCode: String
        let gameTitle: String
        let cheats: [Cheat]
    }

    static func parseCheatFiles(content: String) -> [GameCheat] {
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var results: [GameCheat] = []

        var currentGameCode: String?
        var currentGameTitle: String?
        var cheats: [GameCheat.Cheat] = []

        var currentCheatName: String?
        var currentCheatLines: [String] = []

        func flushCheat() {
            guard
                let name = currentCheatName,
                !currentCheatLines.isEmpty
            else {
                currentCheatName = nil
                currentCheatLines.removeAll()
                return
            }

            cheats.append(
                .init(
                    name: name,
                    code: currentCheatLines.joined(separator: "\n")
                )
            )

            currentCheatName = nil
            currentCheatLines.removeAll()
        }

        func flushGame() {
            flushCheat()
            guard
                let code = currentGameCode,
                let title = currentGameTitle,
                !cheats.isEmpty
            else {
                cheats.removeAll()
                return
            }

            results.append(
                .init(
                    gameCode: code,
                    gameTitle: title,
                    cheats: cheats
                )
            )
            cheats.removeAll()
        }

        for line in lines {
            if line.hasPrefix("_S ") {
                flushGame()
                currentGameCode = String(line.dropFirst(3))
                currentGameTitle = nil
            } else if line.hasPrefix("_G "), currentGameTitle == nil {
                currentGameTitle = String(line.dropFirst(3))
            } else if line.hasPrefix("_C0 ") || line.hasPrefix("_C1 ") {
                flushCheat()
                currentCheatName = String(line.dropFirst(4))
            } else if line.hasPrefix("_L ") {
                currentCheatLines.append(line)
            }
        }

        flushGame()
        return results
    }
}


class PSPEmulatorBridge : EmulatorBridgeBase {
    static let shared = PSPEmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if input == PSPGameInput.leftThumbstickUp || input == PSPGameInput.leftThumbstickDown {
            thumbstickPosition.y = input == PSPGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PSPGameInput.leftThumbstickLeft || input == PSPGameInput.leftThumbstickRight {
            thumbstickPosition.x = input == PSPGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = PSPGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: PSPGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == PSPGameInput.leftThumbstickUp || input == PSPGameInput.leftThumbstickDown {
            thumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PSPGameInput.leftThumbstickLeft || input == PSPGameInput.leftThumbstickRight {
            thumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = PSPGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
}


