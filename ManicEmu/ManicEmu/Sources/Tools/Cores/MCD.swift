//
//  MCD.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/6/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let mcd = GameType("public.aoshuang.game.mcd")
}

@objc enum MCDGameInput: Int, Input, CaseIterable {
    case a
    case b
    case c
    case x
    case y
    case z
    case l
    case l1
    case r
    case r1
    case start
    case select
    case up
    case down
    case left
    case right

    case flex
    case menu

    var type: InputType {
        return .game(.mcd)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "c" { self = .c }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "z" { self = .z }
        else if stringValue == "l" { self = .l }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r" { self = .r }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct MCD: DeltaCoreProtocol {
    static var isJGenesisCore: Bool = false
    
    static let core = MCD()
    
    var name: String { "MCD" }
    var identifier: String { "com.aoshuang.MCDCore" }
    
    var gameType: GameType { GameType.mcd }
    var gameInputType: Input.Type { MCDGameInput.self }
    var allInputs: [Input] { MCDGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 320, height: 224))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let gameGenieFormat = CheatFormat(name: NSLocalizedString("Game Genie", comment: ""), format: "XXXX-YYYY", type: .gameGenie)
        let proActionReplayFormat = CheatFormat(name: NSLocalizedString("Pro Action Replay 16Bit", comment: ""), format: "XXXXXXYYYY", type: .actionReplay16)
        return [gameGenieFormat, proActionReplayFormat]
    }
    
    var emulatorBridge: EmulatorBridging { MCDEmulatorBridge.shared }
        
    private init()
    {
    }
}


class MCDEmulatorBridge : EmulatorBridgeBase {
    static let shared = MCDEmulatorBridge()

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = MCDGameInput(rawValue: input) {
#if DEBUG
                    Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            if MCD.isJGenesisCore {
                if let jGenesisButton = gameInputToJGenesisCoreInput(gameInput: gameInput) {
                    PlayViewController.jGenesisView?.pressButton(jGenesisButton, pressed: true, player: playerIndex-1)
                }
            } else {
                if let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                    LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
                }
            }
            
        }
        
    }
    
    func gameInputToCoreInput(gameInput: MCDGameInput) -> LibretroButton? {
        if gameInput == .a { return .Y }
        else if gameInput == .b { return .B }
        else if gameInput == .c { return .A }
        else if gameInput == .x { return .L1 }
        else if gameInput == .y { return .X }
        else if gameInput == .z { return .R1 }
        else if gameInput == .l { return .L2 }
        else if gameInput == .l1 { return .L2 }
        else if gameInput == .r { return .R2 }
        else if gameInput == .r1 { return .R2 }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    func gameInputToJGenesisCoreInput(gameInput: MCDGameInput) -> JGenesisButton? {
        if gameInput == .a { return .a }
        else if gameInput == .b { return .b }
        else if gameInput == .c { return .c }
        else if gameInput == .x { return .x }
        else if gameInput == .y { return .y }
        else if gameInput == .z { return .z }
        else if gameInput == .start { return .start }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = MCDGameInput(rawValue: input) {
            if MCD.isJGenesisCore {
                if let jGenesisButton = gameInputToJGenesisCoreInput(gameInput: gameInput) {
                    PlayViewController.jGenesisView?.pressButton(jGenesisButton, pressed: false, player: playerIndex-1)
                }
            } else {
                if let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                    LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
                }
            }
            
        }
    }
}
