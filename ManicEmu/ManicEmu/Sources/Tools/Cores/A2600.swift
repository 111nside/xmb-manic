//
//  A2600.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/23.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AVFoundation

extension GameType
{
    static let a2600 = GameType("public.aoshuang.game.2600")
}

@objc enum A2600GameInput: Int, Input, CaseIterable {
    case a //fire
    case b //fire
    case start //reset
    case select //select
    case up
    case down
    case left
    case right
    case l1 //Left Difficulty A
    case r1 //Right Difficulty A
    case l2 //Left Difficulty B
    case r2 //Right Difficulty B
    case l3 //Color
    case r3 //Black/White

    case flex
    case menu

    var type: InputType {
        return .game(.a2600)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "l2" { self = .l2 }
        else if stringValue == "r2" { self = .r2 }
        else if stringValue == "l3" { self = .l3 }
        else if stringValue == "r3" { self = .r3 }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct A2600: DeltaCoreProtocol {
    static let core = A2600()
    
    var name: String { "2600" }
    var identifier: String { "com.aoshuang.2600Core" }
    
    var gameType: GameType { GameType.a2600 }
    var gameInputType: Input.Type { A2600GameInput.self }
    var allInputs: [Input] { A2600GameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 192, height: 160))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { A2600EmulatorBridge.shared }
    
    private init() {}
}


class A2600EmulatorBridge : EmulatorBridgeBase {
    static let shared = A2600EmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = A2600GameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: A2600GameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .B }
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
        if let gameInput = A2600GameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
