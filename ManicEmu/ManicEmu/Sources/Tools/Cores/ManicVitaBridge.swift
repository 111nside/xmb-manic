// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Native Vita3K session adapter. The embedded runtime is built from the pinned
// Tsubomi upstream-core source and linked as Vita3KManicRuntime.framework.
// There is no separate UIApplicationMain or second installed emulator app.
import Foundation
import Vita3KManicRuntime

@MainActor
final class ManicVitaBridge {
    static let shared = ManicVitaBridge()
    private init() {}

    enum RuntimeError: LocalizedError {
        case wrongThread
        case alreadyRunning
        case initializationFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .wrongThread:
                return "Vita3K must start on the UIKit main thread."
            case .alreadyRunning:
                return "A Vita3K session is already active."
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

    func requestExit() {
        manic_vita3k_request_exit()
    }
}
