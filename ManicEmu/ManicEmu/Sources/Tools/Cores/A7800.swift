//
//  A7800.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/23.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AVFoundation

extension GameType
{
    static let a7800 = GameType("public.aoshuang.game.7800")
}

@objc enum A7800GameInput: Int, Input, CaseIterable {
    case a //right red button
    case b //left red button
    case x //reset
    case start //pause
    case select //select
    case up
    case down
    case left
    case right
    case l1 //Left Difficulty
    case r1 //Right Difficulty

    case flex
    case menu

    var type: InputType {
        return .game(.a7800)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct A7800: DeltaCoreProtocol {
    static let core = A7800()
    
    var name: String { "7800" }
    var identifier: String { "com.aoshuang.7800Core" }
    
    var gameType: GameType { GameType.a7800 }
    var gameInputType: Input.Type { A7800GameInput.self }
    var allInputs: [Input] { A7800GameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 320, height: 240))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { A7800EmulatorBridge.shared }
    
    private init() {}
}


class A7800EmulatorBridge : EmulatorBridgeBase {
    static let shared = A7800EmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = A7800GameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: A7800GameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = A7800GameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
