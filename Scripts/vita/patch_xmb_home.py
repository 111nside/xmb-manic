#!/usr/bin/env python3
"""Install a PS Vita launcher into Manic XMB's Profile menu.

The huge HomeViewController source is owned by Manic. Keep the feature as a
small, repeatable patch rather than replacing that 6,900-line file.
"""
from pathlib import Path

FILE = Path("ManicEmu/ManicEmu/Sources/Business/Home/ViewControllers/HomeViewController.swift")
text = FILE.read_text()
before = text

def inject(marker: str, body: str):
    global text
    if body.strip() in text:
        return
    if text.count(marker) != 1:
        raise SystemExit(f"PS Vita UI patch mismatch: {marker[:90]}")
    text = text.replace(marker, body + marker, 1)

button = '''#if SIDE_LOAD
    private lazy var vita3KButton = makeProfileMenuButton(title: "PS Vita",
                                                          subtitle: "Play installed titles and import files through XMB",
                                                          symbol: "gamecontroller.fill") { [weak self] in
        self?.openVita3KLibrary()
    }
#endif

    '''
inject("private lazy var ps2MemoryCardsButton =", button)

import_button = '''#if SIDE_LOAD
    private lazy var vitaImportButton = makeProfileMenuButton(title: "Import Vita File",
                                                               subtitle: "Choose firmware or game archives using Manic's Files picker",
                                                               symbol: "square.and.arrow.down") { [weak self] in
        self?.importVitaFile()
    }
#endif

    '''
inject("private lazy var ps2MemoryCardsButton =", import_button)

diagnostics_button = '''#if SIDE_LOAD
    private lazy var vitaDiagnosticsButton = makeProfileMenuButton(title: "Vita Diagnostics",
                                                                   subtitle: "Share the embedded Vita UI and runtime logs",
                                                                   symbol: "doc.text.magnifyingglass") { [weak self] in
        self?.shareVitaDiagnostics()
    }
#endif

    '''
inject("private lazy var ps2MemoryCardsButton =", diagnostics_button)

stack_marker = "        profileMenuStack.axis = .vertical\n"
stack_insert = '''#if SIDE_LOAD
        profileMenuStack.insertArrangedSubview(vita3KButton, at: 1)
        profileMenuStack.insertArrangedSubview(vitaImportButton, at: 2)
        profileMenuStack.insertArrangedSubview(vitaDiagnosticsButton, at: 3)
#endif
'''
inject(stack_marker, stack_insert)

height_marker = "        view.addSubview(actionContainerView)\n"
height_insert = '''#if SIDE_LOAD
        vita3KButton.snp.makeConstraints { $0.height.equalTo(58) }
        vitaImportButton.snp.makeConstraints { $0.height.equalTo(58) }
        vitaDiagnosticsButton.snp.makeConstraints { $0.height.equalTo(58) }
#endif

'''
inject(height_marker, height_insert)

method = r'''#if SIDE_LOAD
    // UIKit dialogs and Files pickers must be presented outside Vita3K's
    // synchronous SDL callback. The embedded core is only entered for a
    // one-shot install or for actual gameplay.
    private var vita3KLaunchPending = false

    private func vitaMessage(_ title: String, _ message: String) {
        guard view.window != nil else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func runVitaOperation(_ operation: @escaping () throws -> String) {
        guard !vita3KLaunchPending, !ManicVitaBridge.shared.isRunning else { return }
        vita3KLaunchPending = true
        // The action sheet needs to finish its dismissal before SDL makes its
        // own window key. Keep this launch off the original button callback.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            defer { self.vita3KLaunchPending = false }
            do {
                let message = try operation()
                if !message.isEmpty {
                    self.vitaMessage("PS Vita", message)
                }
            } catch {
                self.vitaMessage("PS Vita", error.localizedDescription)
            }
        }
    }

    private func openVita3KLibrary() {
        guard !vita3KLaunchPending, !ManicVitaBridge.shared.isRunning else { return }
        let games = ManicVitaBridge.shared.installedTitles()
        let pending = ManicVitaBridge.shared.pendingImportCount
        let hint = games.isEmpty
            ? "No Vita games installed. Import a .PUP firmware or game archive using Manic's Files picker."
            : "Choose an installed Vita game to launch."
        let message = pending > 0 ? hint + "\n\(pending) file(s) queued for installation." : hint
        let menu = UIAlertController(title: "PS Vita Library", message: message,
                                     preferredStyle: .actionSheet)

        for game in games.prefix(30) {
            menu.addAction(UIAlertAction(title: "Play \(game.name)", style: .default) { [weak self] _ in
                self?.runVitaOperation {
                    try ManicVitaBridge.shared.launch(titleID: game.titleID)
                    return ""
                }
            })
        }
        menu.addAction(UIAlertAction(title: "Import Vita File", style: .default) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self?.importVitaFile()
            }
        })
        if pending > 0 {
            menu.addAction(UIAlertAction(title: "Install \(pending) Queued File(s)", style: .default) { [weak self] _ in
                self?.runVitaOperation {
                    try ManicVitaBridge.shared.installQueuedFiles()
                }
            })
        }
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = menu.popoverPresentationController {
            popover.sourceView = vita3KButton
            popover.sourceRect = vita3KButton.bounds
        }
        present(menu, animated: true)
    }
#endif

    '''
inject("private func openPS2MemoryCards() {", method)

picker_delegate = '''#if SIDE_LOAD
// Keep the UIKit document-picker delegate alive for its entire presentation.
// The former shared FilesImporter chose a different presenting controller when
// Vita3K had previously made an SDL window key.
private final class XMBVitaPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void

    init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
        self.onPick = onPick
        self.onCancel = onCancel
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        onPick(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onCancel()
    }
}
#endif

'''
inject("class HomeViewController: BaseViewController {", picker_delegate)

import_method = r'''#if SIDE_LOAD
    // Present Files from the visible Manic XMB view controller, not from a
    // shared/root presenter that may still point at Vita3K's SDL UIWindow.
    private var vitaFileImportPending = false
    private var vitaFilePickerDelegate: XMBVitaPickerDelegate?

    private func importVitaFile() {
        guard !vitaFileImportPending, !ManicVitaBridge.shared.isRunning else { return }
        // The PS Vita Library action sheet may still be dismissing. Never
        // attempt a second modal presentation on top of an active action sheet.
        if let activeModal = presentedViewController {
            activeModal.dismiss(animated: true) { [weak self] in
                self?.importVitaFile()
            }
            return
        }
        guard viewIfLoaded?.window != nil else { return }

        vitaFileImportPending = true
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item],
                                                     asCopy: true)
        picker.allowsMultipleSelection = false
        vitaFilePickerDelegate = XMBVitaPickerDelegate(
            onPick: { [weak self] urls in
                guard let self else { return }
                self.vitaFilePickerDelegate = nil
                guard let selected = urls.first else {
                    self.vitaFileImportPending = false
                    return
                }
                UIView.makeLoading()
                ManicVitaBridge.shared.queueImport(from: selected) { [weak self] error in
                    DispatchQueue.main.async {
                        UIView.hideLoading()
                        guard let self else { return }
                        self.vitaFileImportPending = false
                        let title = error == nil ? "Vita Import Ready" : "Vita Import Failed"
                        let message = error ?? "File queued. Open PS Vita, then choose Install Queued Files."
                        // UIKit may still be dismissing the Files sheet here.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                            self?.vitaMessage(title, message)
                        }
                    }
                }
            },
            onCancel: { [weak self] in
                self?.vitaFilePickerDelegate = nil
                self?.vitaFileImportPending = false
            }
        )
        picker.delegate = vitaFilePickerDelegate
        present(picker, animated: true)
    }
#endif

    '''
inject("private func openPS2MemoryCards() {", import_method)

diagnostics_method = '''#if SIDE_LOAD
    private func shareVitaDiagnostics() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let folder = documents.appendingPathComponent("Tsubomi", isDirectory: true)
        let filenames = ["ui-diagnostics.log", "tsubomi.log"]
        let logs = filenames.map { folder.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !logs.isEmpty else {
            let alert = UIAlertController(title: "Vita Diagnostics",
                                          message: "No Vita logs yet. Open PS Vita, reproduce the issue, then return here.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let activity = UIActivityViewController(activityItems: logs, applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = vitaDiagnosticsButton
            popover.sourceRect = vitaDiagnosticsButton.bounds
        }
        present(activity, animated: true)
    }
#endif

    '''
inject("private func openPS2MemoryCards() {", diagnostics_method)

if text != before:
    FILE.write_text(text)
    print("Added PS Vita launcher to XMB Profile (Sideload only)")
else:
    print("PS Vita XMB Profile launcher already installed")
