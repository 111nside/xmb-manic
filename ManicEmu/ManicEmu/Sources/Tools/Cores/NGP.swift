//
//  NGP.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType {
    static let ngp = GameType("public.aoshuang.game.ngp")
    static let ngpc = GameType("public.aoshuang.game.ngpc")
}

@objc enum NGPGameInput: Int, Input, CaseIterable {
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
    case l2
    case r2
    case l3
    case r3

    case flex
    case menu

    var type: InputType {
        return .game(.ngp)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a}
        else if stringValue == "b" { self = .b}
        else if stringValue == "x" { self = .x}
        else if stringValue == "y" { self = .y}
        else if stringValue == "start" { self = .start}
        else if stringValue == "select" { self = .select}
        else if stringValue == "up" { self = .up}
        else if stringValue == "down" { self = .down}
        else if stringValue == "left" { self = .left}
        else if stringValue == "right" { self = .right}
        else if stringValue == "l1" { self = .l1}
        else if stringValue == "r1" { self = .r1}
        else if stringValue == "l2" { self = .l2}
        else if stringValue == "r2" { self = .r2}
        else if stringValue == "l3" { self = .l3}
        else if stringValue == "r3" { self = .r3}
        else { return nil }
    }
}

struct NGP: DeltaCoreProtocol {
    static let core = NGP()
    
    var name: String { "NGP" }
    var identifier: String { "com.aoshuang.NGPCore" }
    
    var gameType: GameType { GameType.ngp }
    var gameInputType: Input.Type { NGPGameInput.self }
    var allInputs: [Input] { NGPGameInput.allCases }
    var gameSaveFileExtension: String { "flash" }
        
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 160, height: 152))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { NGPEmulatorBridge.shared }
    
    private init() {}
}


class NGPEmulatorBridge : EmulatorBridgeBase {
    static let shared = NGPEmulatorBridge()

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = NGPGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: NGPGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .l2 { return .L2 }
        else if gameInput == .r2 { return .R2 }
        else if gameInput == .l3 { return .L3 }
        else if gameInput == .r3 { return .R3 }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = NGPGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
