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
                                                          subtitle: "Open the native Vita3K game library and firmware installer",
                                                          symbol: "gamecontroller.fill") { [weak self] in
        self?.openVita3KLibrary()
    }
#endif

    '''
inject("private lazy var ps2MemoryCardsButton =", button)

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
        profileMenuStack.insertArrangedSubview(vitaDiagnosticsButton, at: 2)
#endif
'''
inject(stack_marker, stack_insert)

height_marker = "        view.addSubview(actionContainerView)\n"
height_insert = '''#if SIDE_LOAD
        vita3KButton.snp.makeConstraints { $0.height.equalTo(58) }
        vitaDiagnosticsButton.snp.makeConstraints { $0.height.equalTo(58) }
#endif

'''
inject(height_marker, height_insert)

method = '''#if SIDE_LOAD
    // Starting a nested SDL/UIKit run loop from inside the button's touch
    // handler traps the original touch dispatch on the stack. Give UIKit a
    // normal turn to finish that event before handing off to the Vita frontend.
    private var vita3KLaunchPending = false

    private func openVita3KLibrary() {
        guard !vita3KLaunchPending, !ManicVitaBridge.shared.isRunning else { return }
        vita3KLaunchPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.vita3KLaunchPending = false
            guard !ManicVitaBridge.shared.isRunning else { return }
            do {
                try ManicVitaBridge.shared.openNativeLibrary()
            } catch {
                let alert = UIAlertController(title: "PS Vita",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
#endif

    '''
inject("private func openPS2MemoryCards() {", method)

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
