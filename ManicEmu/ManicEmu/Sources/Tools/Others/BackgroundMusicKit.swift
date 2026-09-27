//
//  BackgroundMusicKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/28.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import AVFoundation
import UniformTypeIdentifiers
import UIKit

/// Landscape-only looping BGM. Yields to the user's other music, the mute switch, gameplay, and the background.
final class BackgroundMusicKit {
    static let shared = BackgroundMusicKit()

    static let defaultTrackTitle = "BGM 1"
    static let directoryName = "sounds/bgm"
    private static let disabledStoredValue = ""
    static let allowedExtensions: Set<String> = ["m4a", "aac", "mp3", "wav"]

    static var importTypes: [UTType] {
        var types: [UTType] = [.mpeg4Audio, .mp3, .wav]
        if let aac = UTType(filenameExtension: "aac") {
            types.append(aac)
        }
        return types
    }

    struct Track {
        let title: String
        let author: String
        let fileURL: URL
        let isCustom: Bool
    }

    private var player: AVAudioPlayer?
    private var playingFileURL: URL?
    private var isAppActive = true
    private var landscapeHomeVisible = false
    private var didStartMonitoring = false

    private init() {}

    var directoryPath: String {
        R.Path.Resource.appendingPathComponent(Self.directoryName)
    }

    var builtInTracks: [Track] {
        tracks(in: directoryPath, isCustom: false)
    }

    var customTracks: [Track] {
        tracks(in: R.Path.Assets, isCustom: true)
    }

    var tracks: [Track] {
        builtInTracks + customTracks
    }

    /// `nil` means BGM is turned off.
    var selectedTitle: String? {
        guard let stored = Settings.defalut.getExtraString(key: ExtraKey.landscapeBackgroundMusic.rawValue) else {
            return Self.defaultTrackTitle
        }
        if stored == Self.disabledStoredValue {
            return nil
        }
        return stored
    }

    var selectedTrack: Track? {
        guard let title = selectedTitle else { return nil }
        if let exact = tracks.first(where: { $0.title == title }) {
            return exact
        }
        return tracks.first(where: {
            $0.fileURL.deletingPathExtension().lastPathComponent.hasPrefix(title)
        })
    }

    var displayName: String {
        selectedTitle ?? R.string.localizable.off()
    }

    func startMonitoring() {
        guard !didStartMonitoring else {
            schedulePlaybackUpdate()
            return
        }
        didStartMonitoring = true
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isAppActive = false
            self?.updatePlayback()
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isAppActive = true
            self?.updatePlayback()
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isAppActive = false
            self?.updatePlayback()
        }
        center.addObserver(forName: R.NotificationName.StartPlayGame, object: nil, queue: .main) { [weak self] _ in
            self?.updatePlayback()
        }
        center.addObserver(forName: R.NotificationName.StopPlayGame, object: nil, queue: .main) { [weak self] _ in
            self?.updatePlayback()
        }
        center.addObserver(forName: R.NotificationName.ViewAlongsideTransition, object: nil, queue: .main) { [weak self] _ in
            self?.updatePlayback()
        }
        center.addObserver(forName: R.NotificationName.ViewDidTransition, object: nil, queue: .main) { [weak self] _ in
            self?.updatePlayback()
        }
        center.addObserver(forName: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updatePlayback()
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            self?.handleInterruption(notification)
        }
        isAppActive = UIApplication.shared.applicationState != .background
        schedulePlaybackUpdate()
    }

    func setLandscapeHomeVisible(_ visible: Bool) {
        landscapeHomeVisible = visible
        schedulePlaybackUpdate()
    }

    func select(title: String?) {
        Settings.defalut.updateExtra(key: ExtraKey.landscapeBackgroundMusic.rawValue, value: title ?? Self.disabledStoredValue)
        updatePlayback()
    }

    func updatePlayback() {
        guard canPlay, let track = selectedTrack else {
            if selectedTitle == nil {
                stopPlayer()
            } else {
                pausePlayback()
            }
            return
        }
        play(track)
    }

    static func parseFileName(_ fileName: String) -> (title: String, author: String) {
        let stem = (fileName as NSString).deletingPathExtension
        if let parsed = parseAuthorSuffix(stem, open: "(", close: ")") {
            return parsed
        }
        if let parsed = parseAuthorSuffix(stem, open: "（", close: "）") {
            return parsed
        }
        return (stem, "")
    }

    /// `Song Title(Author)` or `Song Title（Author）`. Uses the last matching pair so a title can contain other parentheses.
    private static func parseAuthorSuffix(_ stem: String, open: Character, close: Character) -> (title: String, author: String)? {
        guard let closeIndex = stem.lastIndex(of: close), closeIndex == stem.index(before: stem.endIndex) else {
            return nil
        }
        guard let openIndex = stem[..<closeIndex].lastIndex(of: open), openIndex != stem.startIndex else {
            return nil
        }
        let title = stem[..<openIndex].trimmingCharacters(in: .whitespaces)
        let author = stem[stem.index(after: openIndex)..<closeIndex].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !author.isEmpty else { return nil }
        return (title, author)
    }

    // MARK: - Private

    private var canPlay: Bool {
        guard landscapeHomeVisible, isAppActive else { return false }
        guard !PlayViewController.isGaming else { return false }
        guard selectedTitle != nil, selectedTrack != nil else { return false }
        return true
    }

    private func tracks(in directory: String, isCustom: Bool) -> [Track] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }
        return names.compactMap { name -> Track? in
            guard Self.allowedExtensions.contains(name.pathExtension.lowercased()) else { return nil }
            let parsed = Self.parseFileName(name)
            return Track(title: parsed.title,
                         author: parsed.author,
                         fileURL: URL(fileURLWithPath: directory.appendingPathComponent(name)),
                         isCustom: isCustom)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func schedulePlaybackUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.updatePlayback()
        }
    }

    private func play(_ track: Track) {
        activateAmbientSession()
        // Ambient mixes and does not interrupt. After the session is up, yield if another app is the primary mix.
        if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint {
            pausePlayback()
            return
        }
        if let player, playingFileURL == track.fileURL {
            if !player.isPlaying {
                player.play()
            }
            return
        }
        stopPlayer()
        do {
            let player = try makePlayer(url: track.fileURL)
            player.numberOfLoops = -1
            player.volume = 0.35
            player.prepareToPlay()
            player.play()
            self.player = player
            playingFileURL = track.fileURL
        } catch {
            Log.error("[BackgroundMusicKit] failed to play \(track.fileURL.lastPathComponent): \(error)")
            self.player = nil
            playingFileURL = nil
        }
    }

    /// `.aac` is ADTS. Many exports are MPEG-4/M4A with a wrong `.aac` suffix;
    /// Core Audio then refuses to open them unless we hint `m4a`.
    private func makePlayer(url: URL) throws -> AVAudioPlayer {
        if Self.isMPEG4Container(url) {
            let data = try Data(contentsOf: url)
            return try AVAudioPlayer(data: data, fileTypeHint: AVFileType.m4a.rawValue)
        }
        return try AVAudioPlayer(contentsOf: url)
    }

    static func resolvedImportFileName(for url: URL) -> String {
        let name = url.lastPathComponent
        if url.pathExtension.lowercased() == "aac", isMPEG4Container(url) {
            return url.deletingPathExtension().lastPathComponent + ".m4a"
        }
        return name
    }

    static func isMPEG4Container(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 12), header.count >= 8 else { return false }
        return header[4..<8] == Data("ftyp".utf8)
    }

    private func pausePlayback() {
        player?.pause()
    }

    private func stopPlayer() {
        player?.stop()
        player = nil
        playingFileURL = nil
    }

    private func activateAmbientSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            Log.error("[BackgroundMusicKit] failed to activate ambient session: \(error)")
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            pausePlayback()
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) {
                updatePlayback()
            }
        @unknown default:
            break
        }
    }
}
