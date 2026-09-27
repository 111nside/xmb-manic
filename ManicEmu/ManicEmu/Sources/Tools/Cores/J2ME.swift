//
//  J2ME.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/3/2.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import AVFoundation

extension GameType {
    static let j2me = GameType("public.aoshuang.game.j2me")
}

@objc enum J2MEGameInput: Int, Input, CaseIterable {
    case up
    case down
    case left
    case right
    case fire
    case num0
    case num1
    case num2
    case num3
    case num4
    case num5
    case num6
    case num7
    case num8
    case num9
    case star
    case pound
    case softkeyLeft
    case softkeyRight

    case flex
    case menu

    var type: InputType {
        return .game(.j2me)
    }

    init?(stringValue: String) {
        if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "fire" { self = .fire }
        else if stringValue == "num0" { self = .num0 }
        else if stringValue == "num1" { self = .num1 }
        else if stringValue == "num2" { self = .num2 }
        else if stringValue == "num3" { self = .num3 }
        else if stringValue == "num4" { self = .num4 }
        else if stringValue == "num5" { self = .num5 }
        else if stringValue == "num6" { self = .num6 }
        else if stringValue == "num7" { self = .num7 }
        else if stringValue == "num8" { self = .num8 }
        else if stringValue == "num9" { self = .num9 }
        else if stringValue == "star" { self = .star }
        else if stringValue == "pound" { self = .pound }
        else if stringValue == "softkeyLeft" { self = .softkeyLeft }
        else if stringValue == "softkeyRight" { self = .softkeyRight }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct J2ME: DeltaCoreProtocol {
    static let core = J2ME()

    var name: String { "J2ME" }
    var identifier: String { "com.aoshuang.J2MECore" }

    var gameType: GameType { GameType.j2me }
    var gameInputType: Input.Type { J2MEGameInput.self }
    var allInputs: [Input] { J2MEGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }

    // J2ME typically runs at variable frame rate
    
    let videoFormat = VideoFormat(format: .bitmap(.rgba8), dimensions: J2MESize.defaultSize.cgSize)

    var supportedCheatFormats: Set<CheatFormat> {
        // J2ME doesn't support cheat codes
        return []
    }

    // J2ME uses WebView, so it doesn't need a traditional emulator connector
    var emulatorBridge: EmulatorBridging { J2MEEmulatorBridge.shared }

    private init() {}
}


class J2MEEmulatorBridge: EmulatorBridgeBase {
    static let shared = J2MEEmulatorBridge()

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0,
              let gameInput = J2MEGameInput(rawValue: input) else { return }
        
        if let button = convertToJ2MEButton(gameInput) {
            PlayViewController.j2meView?.pressButton(button, pressed: true)
        }
        
    }

    override func deactivateInput(_ input: Int, playerIndex: Int) {
        guard playerIndex >= 0,
              let gameInput = J2MEGameInput(rawValue: input) else { return }

        if let button = convertToJ2MEButton(gameInput) {
            PlayViewController.j2meView?.pressButton(button, pressed: false)
        }
    }

    private func convertToJ2MEButton(_ input: J2MEGameInput) -> J2MEButton? {
        switch input {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .fire: return .fire
        case .num0: return .num0
        case .num1: return .num1
        case .num2: return .num2
        case .num3: return .num3
        case .num4: return .num4
        case .num5: return .num5
        case .num6: return .num6
        case .num7: return .num7
        case .num8: return .num8
        case .num9: return .num9
        case .star: return .star
        case .pound: return .pound
        case .softkeyLeft: return .softkeyLeft
        case .softkeyRight: return .softkeyRight
        default: return nil
        }
    }
}
