// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Manic-side Vita frontend adapter. This intentionally has no compile-time
// dependency on Tsubomi until its native target is linked into Manic.
// TsubomiBridge is an Objective-C facade defined in Vendor/Tsubomi/ios/include/
// vita3k_ios/TsubomiBridge.h. This adapter never starts another UIApplication.
import Foundation
import UIKit

@MainActor
final class ManicVitaBridge {
    static let shared = ManicVitaBridge()
    private init() {}

    enum BridgeError: LocalizedError {
        case runtimeNotLinked
        case unsupportedAction(String)
        case invalidTitle
        var errorDescription: String? {
            switch self {
            case .runtimeNotLinked:
                return "Tsubomi's native Vita3K runtime is not linked into this Manic build."
            case .unsupportedAction(let action):
                return "The installed Vita3K bridge does not support \(action)."
            case .invalidTitle:
                return "A Vita title ID is required to launch a game."
            }
        }
    }

    struct InstalledGame: Identifiable {
        let id: String
        let name: String
        let iconPath: String?
        let bannerPath: String?
        let playTimeSeconds: Int64
    }

    /// Becomes true only after the native TsubomiBridge ObjC class is linked.
    var isRuntimeLinked: Bool {
        NSClassFromString("TsubomiBridge") != nil
    }

    private func runtime() throws -> NSObject.Type {
        guard let cls = NSClassFromString("TsubomiBridge") as? NSObject.Type else {
            throw BridgeError.runtimeNotLinked
        }
        return cls
    }

    private func perform(_ action: String, selector: Selector, argument: NSString? = nil) throws -> Any? {
        let cls = try runtime()
        guard cls.responds(to: selector) else {
            throw BridgeError.unsupportedAction(action)
        }
        // TsubomiBridge's public facade uses Objective-C class methods.
        // The selector and its arguments must match the pinned header exactly.
        return cls.perform(selector, with: argument)?.takeUnretainedValue()
    }

    func refreshLibrary() throws {
        _ = try perform("refreshLibrary", selector: NSSelectorFromString("refreshLibrary"))
    }

    func installedGames() throws -> [InstalledGame] {
        guard let objects = try perform("libraryEntries", selector: NSSelectorFromString("libraryEntries")) as? [NSObject] else {
            return []
        }
        return objects.compactMap { entry in
            // Read only the properties declared in TsubomiGameEntry.
            guard let titleID = entry.perform(NSSelectorFromString("titleID"))?.takeUnretainedValue() as? String,
                  !titleID.isEmpty else { return nil }
            let title = entry.perform(NSSelectorFromString("displayTitle"))?.takeUnretainedValue() as? String ?? titleID
            let icon = entry.perform(NSSelectorFromString("iconPath"))?.takeUnretainedValue() as? String
            let banner = entry.perform(NSSelectorFromString("wideArtPath"))?.takeUnretainedValue() as? String
            return InstalledGame(id: titleID, name: title,
                                 iconPath: icon?.isEmpty == false ? icon : nil,
                                 bannerPath: banner?.isEmpty == false ? banner : nil,
                                 playTimeSeconds: 0)
        }
    }

    func launch(titleID: String) throws {
        guard !titleID.isEmpty else { throw BridgeError.invalidTitle }
        _ = try perform("launchTitle:", selector: NSSelectorFromString("launchTitle:"), argument: titleID as NSString)
    }

    func importGame() throws {
        _ = try perform("presentGameImportPicker", selector: NSSelectorFromString("presentGameImportPicker"))
    }

    func importFirmware() throws {
        _ = try perform("presentFirmwareImportPicker", selector: NSSelectorFromString("presentFirmwareImportPicker"))
    }

    func showSettings() throws {
        _ = try perform("presentGlobalSettings", selector: NSSelectorFromString("presentGlobalSettings"))
    }

    func showJITHelp() throws {
        _ = try perform("presentJITRequiredAlert", selector: NSSelectorFromString("presentJITRequiredAlert"))
    }
}
