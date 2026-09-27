//
//  EmulatorBridgingBase.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/6/6.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

class EmulatorBridgeBase: NSObject, EmulatorBridging {
    var gameURL: URL?
    
    let frameDuration: TimeInterval = 1/60.0
    
    var audioRenderer: (any DeltaCore.AudioRendering)?
    
    var videoRenderer: (any DeltaCore.VideoRendering)?
    
    var saveUpdateHandler: (() -> Void)?
    
    func start(withGameURL gameURL: URL) {
        
    }
    
    func stop() {
        
    }
    
    func pause() {
        
    }
    
    func resume() {
        
    }
    
    func runFrame(processVideo: Bool) {
        
    }
    
    func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        
    }
    
    func deactivateInput(_ input: Int, playerIndex: Int) {
        
    }
    
    func resetInputs() {
        
    }
    
    func saveSaveState(to url: URL) {
        
    }
    
    func loadSaveState(from url: URL) {
        
    }
    
    func saveGameSave(to url: URL) {
        
    }
    
    func loadGameSave(from url: URL) {
        
    }
    
    func addCheatCode(_ cheatCode: String, type: String) -> Bool {
        false
    }
    
    func resetCheats() {
        
    }
    
    func updateCheats() {
        
    }
    
    
}
