// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Native Vita3K session adapter. The embedded runtime is built from the pinned
// Tsubomi upstream-core source and linked as Vita3KManicRuntime.framework.
// There is no separate UIApplicationMain or second installed emulator app.
import Foundation

// A stable, directly linked C ABI. The framework is linked by the Sideload
// target; these declarations avoid depending on Tsubomi's internal SwiftUI
// module name (which is deliberately kept as "Tsubomi").
@_silgen_name("manic_vita3k_run")
private func manic_vita3k_run() -> Int32
@_silgen_name("manic_vita3k_request_exit")
private func manic_vita3k_request_exit()
@_silgen_name("manic_vita3k_is_running")
private func manic_vita3k_is_running() -> Int32
@_silgen_name("manic_vita3k_enqueue_import")
private func manic_vita3k_enqueue_import(_ path: UnsafePointer<CChar>, _ kind: Int32) -> Int32

@MainActor
final class ManicVitaBridge {
    static let shared = ManicVitaBridge()
    private init() {}

    enum RuntimeError: LocalizedError {
        case wrongThread
        case alreadyRunning
        case initializationFailed(Int32)
        case stagingFailed

        var errorDescription: String? {
            switch self {
            case .wrongThread:
                return "Vita3K must start on the UIKit main thread."
            case .alreadyRunning:
                return "A Vita3K session is already active."
            case .stagingFailed:
                return "The selected file could not be staged in Manic storage."
            case .initializationFailed(let code):
                return "The native Vita3K session failed to start or exited with status \(code)."
            }
        }
    }

    var isRunning: Bool { manic_vita3k_is_running() != 0 }

    /// Opens the complete Tsubomi game library, firmware importer, and native
    /// emulator view inside Manic's process. The call is synchronous: Tsubomi
    /// pumps UIKit's nested event loop until the user leaves the Vita frontend.
    ///
    /// The standalone Tsubomi app has a different iOS Documents sandbox;
    /// games/firmware must be imported into Manic's Documents/Tsubomi folder.
    func openNativeLibrary() throws {
        guard Thread.isMainThread else { throw RuntimeError.wrongThread }
        guard !isRunning else { throw RuntimeError.alreadyRunning }
        let status = manic_vita3k_run()
        guard status == 0 else { throw RuntimeError.initializationFailed(status) }
    }

    /// Manic's own picker runs BEFORE the nested Vita SDL loop. Copy its
    /// security-scoped selection into app-owned storage, then hand an absolute
    /// path to the embedded runtime for automatic installation upon launch.
    func queueImport(from selectedURL: URL, completion: @escaping (String?) -> Void) {
        let fileExtension = selectedURL.pathExtension.lowercased()
        let kind: Int32
        if fileExtension == "pup" {
            kind = 1
        } else if ["zip", "vpk", "pkg"].contains(fileExtension) {
            kind = 2
        } else {
            completion("Choose an official .pup firmware or a .vpk, .zip, or .pkg game archive.")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let manager = FileManager.default
            let accessing = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if accessing { selectedURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let documents = try manager.url(for: .documentDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil, create: true)
                let inbox = documents.appendingPathComponent("Tsubomi/manic-inbox",
                                                             isDirectory: true)
                try manager.createDirectory(at: inbox, withIntermediateDirectories: true)
                let destination = inbox.appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(fileExtension)
                var coordinationError: NSError?
                var copyError: Error?
                let coordinator = NSFileCoordinator(filePresenter: nil)
                coordinator.coordinate(readingItemAt: selectedURL, options: [],
                                       error: &coordinationError) { source in
                    do { try manager.copyItem(at: source, to: destination) }
                    catch { copyError = error }
                }
                if let error = copyError ?? coordinationError {
                    try? manager.removeItem(at: destination)
                    throw error
                }
                guard manager.fileExists(atPath: destination.path) else {
                    throw RuntimeError.stagingFailed
                }
                DispatchQueue.main.async {
                    let queued = destination.path.withCString {
                        manic_vita3k_enqueue_import($0, kind)
                    }
                    if queued != 1 {
                        try? manager.removeItem(at: destination)
                        completion("Vita import queue is full. Open PS Vita first, then try again.")
                    } else {
                        completion(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion("Unable to copy Vita file: \(error.localizedDescription)")
                }
            }
        }
    }

    func requestExit() {
        manic_vita3k_request_exit()
    }
}
