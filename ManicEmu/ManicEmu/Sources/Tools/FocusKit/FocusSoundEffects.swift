//
//  FocusSoundEffects.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/28.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import AudioToolbox
import UIKit

/// FocusKit navigation cues. Mixes with other audio and follows the hardware mute switch.
final class FocusSoundEffects {
    static let shared = FocusSoundEffects()

    static let defaultPackName = "zen"
    static let directoryName = "sounds/effects"
    static let licenseDetail = "@UI SFX · CC0"
    private static let disabledStoredValue = ""

    enum Cue: Hashable {
        case hover
        case focus
        case cancel

        var fileName: String {
            switch self {
            case .hover: return "hover.caf"
            case .focus: return "focus.caf"
            case .cancel: return "cancel.caf"
            }
        }
    }

    struct Pack {
        let name: String
        let directoryURL: URL
    }

    private var soundIDs: [Cue: SystemSoundID] = [:]
    private var loadedPackName: String?
    private var didStartMonitoring = false

    private init() {}

    var directoryPath: String {
        R.Path.Resource.appendingPathComponent(Self.directoryName)
    }

    var packs: [Pack] {
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: directoryPath),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }
        return urls.compactMap { url -> Pack? in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { return nil }
            let cues: [Cue] = [.hover, .focus, .cancel]
            let hasAll = cues.allSatisfy { FileManager.default.fileExists(atPath: url.appendingPathComponent($0.fileName).path) }
            guard hasAll else { return nil }
            return Pack(name: url.lastPathComponent, directoryURL: url)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// `nil` means sound effects are turned off.
    var selectedPackName: String? {
        guard let stored = Settings.defalut.getExtraString(key: ExtraKey.landscapeSoundEffects.rawValue) else {
            return Self.defaultPackName
        }
        if stored == Self.disabledStoredValue {
            return nil
        }
        return stored
    }

    var selectedPack: Pack? {
        guard let name = selectedPackName else { return nil }
        return packs.first(where: { $0.name == name })
    }

    var displayName: String {
        selectedPackName ?? R.string.localizable.off()
    }

    func startMonitoring() {
        guard !didStartMonitoring else {
            reloadIfNeeded()
            return
        }
        didStartMonitoring = true
        reloadIfNeeded()
    }

    func select(packName: String?) {
        Settings.defalut.updateExtra(key: ExtraKey.landscapeSoundEffects.rawValue, value: packName ?? Self.disabledStoredValue)
        reloadIfNeeded()
    }

    func play(_ cue: Cue) {
        guard FocusSystem.shared.isEnabled else { return }
        guard FocusSystem.shared.currentContext != nil else { return }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard selectedPackName != nil else { return }
        reloadIfNeeded()
        guard let soundID = soundIDs[cue], soundID != 0 else { return }
        AudioServicesPlaySystemSound(soundID)
    }

    // MARK: - Private

    private func reloadIfNeeded() {
        let packName = selectedPackName
        if packName == loadedPackName, packName == nil || !soundIDs.isEmpty {
            return
        }
        disposeSounds()
        loadedPackName = packName
        guard let pack = selectedPack else { return }
        for cue: Cue in [.hover, .focus, .cancel] {
            let url = pack.directoryURL.appendingPathComponent(cue.fileName) as CFURL
            var soundID: SystemSoundID = 0
            let status = AudioServicesCreateSystemSoundID(url, &soundID)
            if status == kAudioServicesNoError, soundID != 0 {
                soundIDs[cue] = soundID
            } else {
                Log.error("[FocusSoundEffects] failed to load \(cue.fileName) in \(pack.name) (\(status))")
            }
        }
    }

    private func disposeSounds() {
        for soundID in soundIDs.values {
            AudioServicesDisposeSystemSoundID(soundID)
        }
        soundIDs.removeAll()
    }
}
