//
//  NDS.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/9/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let ds = GameType("public.aoshuang.game.ds")
}

@objc enum DSGameInput: Int, Input, CaseIterable {
    case a
    case b
    case x
    case y
    case l
    case r
    case l1
    case r1
    case l2//Microphone
    case l3//Close Lid
    case r3//Touch Virtual Cursor
    case start
    case select
    case up
    case down
    case left
    case right
    /// Right analog moves the touch cursor.
    case rightThumbstickUp
    case rightThumbstickDown
    case rightThumbstickLeft
    case rightThumbstickRight
    
    case touchScreenX
    case touchScreenY

    case flex
    case menu

    var type: InputType {
        return .game(.ds)
    }
    
    var isContinuous: Bool {
        switch self
        {
        case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: return true
        case .touchScreenX, .touchScreenY: return true
        default: return false
        }
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "l" { self = .l }
        else if stringValue == "r" { self = .r }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "l2" { self = .l2 }
        else if stringValue == "l3" { self = .l3 }
        else if stringValue == "r3" { self = .r3 }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "rightThumbstickUp" { self = .rightThumbstickUp }
        else if stringValue == "rightThumbstickDown" { self = .rightThumbstickDown }
        else if stringValue == "rightThumbstickLeft" { self = .rightThumbstickLeft }
        else if stringValue == "rightThumbstickRight" { self = .rightThumbstickRight }
        else if stringValue == "touchScreenX" { self = .touchScreenX }
        else if stringValue == "touchScreenY" { self = .touchScreenY }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "menu" { self = .menu }
        else { return nil }
    }
}

struct DS: DeltaCoreProtocol {
    static let core = DS()
    
    var name: String { "DS" }
    var identifier: String { "com.aoshuang.DSCore" }
    
    var gameType: GameType { GameType.ds }
    var gameInputType: Input.Type { DSGameInput.self }
    var allInputs: [Input] { DSGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 256, height: 384))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Action Replay", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .actionReplay)
        return [actionReplayFormat]
    }
    
    var emulatorBridge: EmulatorBridging { DSEmulatorBridge.shared }
        
    private init()
    {
    }
}


class DSEmulatorBridge : EmulatorBridgeBase {
    static let shared = DSEmulatorBridge()
    var isDeSmuMECore: Bool = false

    private var leftThumbstickPosition: CGPoint = .zero
    private var rightThumbstickPosition: CGPoint = .zero
    private var touchPointX: CGFloat? = nil
    private var touchPointY: CGFloat? = nil
    var touchInputFrame: CGRect = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        
        if input == DSGameInput.rightThumbstickUp || input == DSGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = input == DSGameInput.rightThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DSGameInput.rightThumbstickLeft || input == DSGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = input == DSGameInput.rightThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if input == DSGameInput.touchScreenX || input == DSGameInput.touchScreenY {
                if input == DSGameInput.touchScreenX {
                    touchPointX = value
                } else if input == DSGameInput.touchScreenY {
                    touchPointY = value
                }
                if let x = touchPointX, let y = touchPointY {
                    let touchPoint = CGPoint(x: touchInputFrame.minX + touchInputFrame.width*x, y: touchInputFrame.minY + touchInputFrame.height*y)
#if DEBUG
                    Log.debug("🎮 \(objectInfo(self))  \n触摸屏幕:(\(touchInputFrame.minX + touchInputFrame.width*x), \(touchInputFrame.minY + touchInputFrame.height*y) touchPoint:\(touchPoint) Ratio:(\(x), \(y))")
#endif
                    LibretroCore.sharedInstance().sendTouchEventX(touchPoint.x, y: touchPoint.y)
                    touchPointX = nil
                    touchPointY = nil
                }
            } else if let gameInput = DSGameInput(rawValue: input),
                      let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
                Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    //功能映射以MelonDS为准
    func gameInputToCoreInput(gameInput: DSGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .l { return .L1 }
        else if gameInput == .r { return .R1 }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .l2 { return isDeSmuMECore ? .L3 : .L2 }
        else if gameInput == .l3 { return isDeSmuMECore ? .L2 : .L3 }
        else if gameInput == .r3 { return isDeSmuMECore ? .R2 : .R3 }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == DSGameInput.rightThumbstickUp || input == DSGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == DSGameInput.rightThumbstickLeft || input == DSGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if input == DSGameInput.touchScreenX || input == DSGameInput.touchScreenY {
                if input == DSGameInput.touchScreenX {
                    touchPointX = nil
                } else if input == DSGameInput.touchScreenY {
                    touchPointY = nil
                }
                if touchPointX == nil, touchPointY == nil {
                    LibretroCore.sharedInstance().releaseTouchEvent()
                }
            } else if let gameInput = DSGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
}

