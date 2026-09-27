//
//  J2MEView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/28.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
import WebKit
import ZIPFoundation

/// J2ME button mapping for emulator input
enum J2MEButton: String, CaseIterable {
    // Direction keys
    case up
    case down
    case left
    case right
    case fire
    
    // Number keys
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
    
    // Function keys
    case softkeyLeft
    case softkeyRight
    
    /// Returns the key code used by the JavaScript layer
    var keyCode: String {
        switch self {
        case .up: return "ArrowUp"
        case .down: return "ArrowDown"
        case .left: return "ArrowLeft"
        case .right: return "ArrowRight"
        case .fire: return "Enter"
        case .num0: return "Digit0"
        case .num1: return "Digit1"
        case .num2: return "Digit2"
        case .num3: return "Digit3"
        case .num4: return "Digit4"
        case .num5: return "Digit5"
        case .num6: return "Digit6"
        case .num7: return "Digit7"
        case .num8: return "Digit8"
        case .num9: return "Digit9"
        case .star: return "KeyE"
        case .pound: return "KeyR"
        case .softkeyLeft: return "F1"
        case .softkeyRight: return "F2"
        }
    }
}

/// J2ME core type enumeration
enum J2MECoreType: String {
    case j2meJS = "J2meJS"
    case freej2meWeb = "Freej2meWeb"
}

struct J2MESize {
    var width: Int
    var height: Int
    var stringValue: String { "\(width)x\(height)" }
    var cgSize: CGSize { CGSize(width: width, height: height) }
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    init?(stringValue: String) {
        let components = stringValue.components(separatedBy: "x")
        if components.count == 2, let w = components[0].trimmed.int, let h = components[1].trimmed.int {
            self.init(width: w, height: h)
        } else {
            return nil
        }
    }
    
    static var defaultSize: J2MESize {
        return J2MESize(width: 240, height: 320)
    }
}

/// Parsed J2ME JAR manifest
struct J2MEManifest {
    let raw: [String: String]
    var imageData: Data? = nil
    var midletName: String? { raw["MIDlet-Name"] }
    var midletVersion: String? { raw["MIDlet-Version"] }
    var midletVendor: String? { raw["MIDlet-Vendor"] }
    var midletDescription: String? { raw["MIDlet-Description"] }
    var midletInfoURL: String? { raw["MIDlet-Info-URL"] }
    var midletIcon: String? { raw["MIDlet-Icon"] }
    var microEditionProfile: String? { raw["MicroEdition-Profile"] }
    var microEditionConfiguration: String? { raw["MicroEdition-Configuration"] }
    var fileName: String? { raw["File-Name"] }
    var phoneType: String? { raw["Phone-Type"] }
    
    /// Main MIDlet class name (parsed from MIDlet-1)
    var mainClassName: String? {
        guard let midlet1 = raw["MIDlet-1"] else { return nil }
        let parts = midlet1.components(separatedBy: ",")
        return parts.last?.trimmingCharacters(in: .whitespaces)
    }
    
    /// Display name from MIDlet-1 (first field)
    var displayName: String? {
        guard let midlet1 = raw["MIDlet-1"] else { return midletName }
        let parts = midlet1.components(separatedBy: ",")
        let name = parts.first?.trimmingCharacters(in: .whitespaces)
        return (name?.isEmpty == false) ? name : midletName
    }
    
    /// Icon path from MIDlet-1 (second field)
    var iconPath: String? {
        guard let midlet1 = raw["MIDlet-1"] else { return midletIcon }
        let parts = midlet1.components(separatedBy: ",")
        guard parts.count >= 2 else { return midletIcon }
        let icon = parts[1].trimmingCharacters(in: .whitespaces)
        return icon.isEmpty ? midletIcon : icon
    }
    
    var screenSize: J2MESize {
        let sizeStr = raw["Nokia-MIDlet-Canvas-Size"]
        ?? raw["MIDlet-ScreenSize"]
        ?? raw["Nokia-MIDlet-Original-Display-Size"]
        ?? raw["MIDlet-Display-Size"]
        if let str = sizeStr {
            let parts = str.components(separatedBy: CharacterSet(charactersIn: "x,*"))
            if parts.count == 2,
               let w = Int(parts[0].trimmingCharacters(in: .whitespaces)),
               let h = Int(parts[1].trimmingCharacters(in: .whitespaces)),
               w > 0, h > 0 {
                return J2MESize(width: w, height: h)
            }
        }
        
        if let fileName {
            let pattern = try? NSRegularExpression(pattern: #"(\d{3})x(\d{3})"#, options: .caseInsensitive)
            if let match = pattern?.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)), match.numberOfRanges == 3 {
                let wRange = Range(match.range(at: 1), in: fileName)!
                let hRange = Range(match.range(at: 2), in: fileName)!
                if let w = Int(fileName[wRange]), let h = Int(fileName[hRange]), w > 0, h > 0 {
                    return J2MESize(width: w, height: h)
                }
            }
        }
        
        return J2MESize.defaultSize
    }
    
    private static func containsBytes(_ pattern: [UInt8], in target: [UInt8]) -> Bool {
        guard !pattern.isEmpty, target.count >= pattern.count else { return false }
        let limit = target.count - pattern.count
        for i in 0...limit {
            if target[i..<(i + pattern.count)].elementsEqual(pattern) { return true }
        }
        return false
    }
    
    /// Read manifest from a JAR file at the given path (no WebView needed)
    static func read(from jarPath: String) -> J2MEManifest? {
        guard let archive = Archive(url: URL(fileURLWithPath: jarPath), accessMode: .read) else {
            return nil
        }
        guard let entry = archive["META-INF/MANIFEST.MF"] else {
            return nil
        }
        var data = Data()
        do {
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
        } catch {
            return nil
        }
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        //获取MANIFEST.MF
        var dict = [String: String]()
        var currentKey: String?
        var currentValue: String = ""
        
        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                // Continuation line
                currentValue += line.dropFirst()
            } else {
                if let key = currentKey {
                    dict[key] = currentValue
                }
                if let colonIndex = line.firstIndex(of: ":") {
                    currentKey = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    currentValue = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                } else {
                    currentKey = nil
                    currentValue = ""
                }
            }
        }
        if let key = currentKey {
            dict[key] = currentValue
        }
        
        //FileName
        dict["File-Name"] = jarPath.lastPathComponent
        
        //PhoneType
        let siemensSig  = Array("com/siemens/mp/".utf8)
        let mc3Sig      = Array("com/mascotcapsule/micro3d/v3/".utf8)
        let nokiaCatStr = "Nokia-MIDlet-Category: Game"
        var phoneType: String? = nil
        for entry in archive {
            guard phoneType == nil else { break }
            let name = entry.path
            
            var data = Data()
            guard (try? archive.extract(entry) { data.append($0) }) != nil else { continue }
            let bytes = Array(data)
            
            if name == "META-INF/MANIFEST.MF" {
                if let text = String(data: data, encoding: .utf8), text.contains(nokiaCatStr) {
                    phoneType = "Nokia"
                }
                continue
            }
            
            guard name.hasSuffix(".class") else { continue }
            
            if !name.hasPrefix("com/siemens/") && containsBytes(siemensSig, in: bytes) {
                phoneType = "Siemens"
            } else if containsBytes(mc3Sig, in: bytes) {
                phoneType = "SonyEricsson"
            }
        }
        if let phoneType {
            dict["Phone-Type"] = phoneType
        }
        
        var manifest = J2MEManifest(raw: dict)
        if let iconPath = manifest.iconPath {
            let cleanPath = iconPath.hasPrefix("/") ? String(iconPath.dropFirst()) : iconPath
            guard let entry = archive[cleanPath] else { return nil }
            var data = Data()
            do {
                _ = try archive.extract(entry) { chunk in
                    data.append(chunk)
                }
                manifest.imageData = data
            } catch {
                Log.debug("解析j2me图片失败")
            }
        }
        return manifest
    }
}

/// J2ME Emulator View - WebView based implementation
class J2MEView: BaseView {
    
    /// ROM path
    var romPath: String? = nil
    var savePath: String? = nil
    var screenSize = J2MESize.defaultSize
    var rotation = false
    
    /// Core type (J2meJS or Freej2meWeb)
    private let coreType: J2MECoreType
    
    /// Local server for serving web assets
    private let localServer: LocalWebServer
    
    /// Export save state complete callback
    private var onExportSaveStateComplete: ((_ data: Data?, _ success: Bool) -> Void)?
    
    /// Import save state complete callback
    private var onImportSaveStateComplete: ((_ success: Bool, _ error: String?) -> Void)?
    
    /// Initialization complete callback
    var didFinishedInit: (() -> Void)? = nil
    
    /// MIDlet exit callback (game requested to quit)
    var onExit: (() -> Void)? = nil
    
    /// Save data written callback (for auto-save)
    private var onSaveDataWritten: ((_ data: Data) -> Void)?
    
    /// Pending save request (path + completion) for getSaveDataResult message
    private var pendingSavePath: String?
    private var pendingSaveCompletion: ((Bool) -> Void)?
    private var pendingSaveWorkItem: DispatchWorkItem?
    
    /// load jar callback
    var openJarCompletion: ((Bool)->Void)? = nil
    
    private var pressingButtons: [J2MEButton] = []
    private var lastKnownBounds: CGRect = .zero
    
    /// Network bridge for evalNative HTTP/socket operations (J2meJS only)
    private var networkBridge: J2MENetworkBridge?
    
    private(set) var isPaused: Bool = false
    
    // MARK: - Initialization
    
    init(coreType: J2MECoreType) {
        self.coreType = coreType
        
        // Determine server type
        let serverType: LocalWebServer.ServerType
        switch coreType {
        case .j2meJS:
            serverType = .J2meJS
        case .freej2meWeb:
            serverType = .freej2meWeb
        }
        
        self.localServer = LocalWebServer()
        super.init(frame: .zero)
        
        // Start local server
        try? localServer.start(serverType: serverType)
        
        setupWebView()
        
        // Initialize network bridge for J2meJS (freej2meWeb has its own network handling)
        if coreType == .j2meJS {
            networkBridge = J2MENetworkBridge(webView: webView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        localServer.stop()
    }
    
    // MARK: - WebView Setup
    
    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Use non-persistent data store for local files, persistent for CheerpJ caching
        let dataStore = WKWebsiteDataStore.default()
        configuration.websiteDataStore = dataStore
        
        // Add message handlers
        let contentController = WKUserContentController()
        let proxy = WeakScriptMessageHandler(target: self)
        contentController.add(proxy, name: "console")
        contentController.add(proxy, name: "j2me")
        configuration.userContentController = contentController
        
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.isOpaque = false
        view.backgroundColor = .black
        
        // Console hook
        let consoleHookJS = """
        (function () {
            function wrap(type) {
                const original = console[type];
                console[type] = function () {
                    window.webkit.messageHandlers.console.postMessage({
                        type: type,
                        message: Array.from(arguments).join(' ')
                    });
                    original.apply(console, arguments);
                };
            }
        
            ['log', 'warn', 'error', 'info', 'debug'].forEach(wrap);
        
            // Intercept fetch to log all network requests (JS, WASM, assets, etc.)
            const _originalFetch = window.fetch;
            window.fetch = function(input, init) {
                const url = typeof input === 'string' ? input : (input && input.url ? input.url : String(input));
                const method = (init && init.method) ? init.method.toUpperCase() : 'GET';
                console.log('[fetch] ' + method + ' ' + url);
                return _originalFetch.apply(this, arguments).then(function(response) {
                    console.log('[fetch] ' + response.status + ' ' + url);
                    return response;
                }).catch(function(err) {
                    console.log('[fetch] ERR ' + url + ' ' + err);
                    throw err;
                });
            };
        
            // Intercept XHR
            const _XHROpen = XMLHttpRequest.prototype.open;
            const _XHRSend = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.open = function(method, url) {
                this._logUrl = url;
                this._logMethod = method;
                console.log('[xhr] ' + method.toUpperCase() + ' ' + url);
                return _XHROpen.apply(this, arguments);
            };
            XMLHttpRequest.prototype.send = function() {
                const self = this;
                this.addEventListener('loadend', function() {
                    console.log('[xhr] ' + self.status + ' ' + self._logUrl);
                });
                return _XHRSend.apply(this, arguments);
            };
        })();
        """
        let script = WKUserScript(
            source: consoleHookJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        view.configuration.userContentController.addUserScript(script)
        
        return view
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != lastKnownBounds else { return }
        lastKnownBounds = bounds
        let script: String
        switch coreType {
        case .j2meJS:
            script = "if (window.j2meAPI && window.j2meAPI.safeApply) window.j2meAPI.safeApply();"
        case .freej2meWeb:
            script = "if (window.freej2meAPI && window.freej2meAPI.safeApply) window.freej2meAPI.safeApply();"
        }
        webView.evaluateJavaScript(script)
    }
    
    private func setupWebView() {
        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if let url = localServer.getURL() {
            webView.load(URLRequest(url: url, cachePolicy: coreType == .freej2meWeb ? .useProtocolCachePolicy : .reloadIgnoringCacheData))
        }
    }
    
    // MARK: - Public API
    
    /// Open a JAR file for emulation
    func openJar(filePath: String, savePath: String?, screenSize: J2MESize, rotation: Bool, completion: ((Bool)->Void)? = nil) {
        openJarCompletion = completion
        
        // Setup WebView if not already done
        if webView.superview == nil {
            setupWebView()
        }
        
        romPath = filePath
        self.savePath = savePath
        self.screenSize = screenSize
        self.rotation = rotation
        
        // Same host as the page (127.0.0.1). localhost is a different origin and may resolve to ::1.
        let fileId = localServer.registerFile(filePath: filePath)
        let jarURL = localServer.fileURL(for: fileId)
        let fileName = filePath.lastPathComponent
        
        // Build the JavaScript to load the JAR
        let script: String
        switch coreType {
        case .j2meJS:
            // j2meJS: load save separately before openJar (different engine, no CheerpJ conflict)
            if let savePath, FileManager.default.fileExists(atPath: savePath) {
                loadSave(path: savePath)
            }
            script = buildJ2meJSLoadScript(jarURL: jarURL, fileName: fileName, screenSize: screenSize, rotation: rotation)
        case .freej2meWeb:
            // freej2meWeb: pass save data into openJar so it's restored BEFORE FreeJ2ME.main()
            // is called — CheerpJ rejects importData() while Java code is already running.
            var saveBase64: String? = nil
            if let savePath, FileManager.default.fileExists(atPath: savePath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: savePath)) {
                saveBase64 = data.base64EncodedString()
            }
            script = buildFreej2meLoadScript(jarURL: jarURL, fileName: fileName, saveBase64: saveBase64, screenSize: screenSize, rotation: rotation)
        }
        
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error = error {
                Log.debug("❌ Execute JavaScript failed: \(error)")
            } else {
                Log.debug("✅ JavaScript injection successful")
            }
            _ = self // Capture self
        }
    }
    
    /// Reset the emulator (reload WebView and re-open the current JAR)
    func reset(screenSize: J2MESize, rotation: Bool, completion: ((Bool)->Void)? = nil) {
        guard let currentRomPath = romPath else {
            Log.debug("❌ No ROM loaded, nothing to reset")
            return
        }
        self.screenSize = screenSize
        self.rotation = rotation
        
        let previousInitCallback = didFinishedInit
        didFinishedInit = { [weak self] in
            guard let self = self else { return }
            self.didFinishedInit = previousInitCallback
            self.openJar(filePath: currentRomPath, savePath: savePath, screenSize: screenSize, rotation: rotation, completion: completion)
        }
        
        if let url = localServer.getURL() {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
        }
    }
    
    // MARK: - Save/Load
    
    /// Save SRAM to file (uses message handler so result is delivered after _getSaveData Promise resolves)
    func save(to path: String, completion: ((_ isSucess: Bool) -> Void)? = nil) {
        let apiObj: String
        switch coreType {
        case .j2meJS: apiObj = "j2meAPI"
        case .freej2meWeb: apiObj = "freej2meAPI"
        }
        
        pendingSaveWorkItem?.cancel()
        pendingSavePath = path
        pendingSaveCompletion = completion
        
        let timeout = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.pendingSavePath != nil {
                Log.debug("❌ Get save data timeout")
                self.pendingSaveWorkItem = nil
                self.pendingSavePath = nil
                self.pendingSaveCompletion?(false)
                self.pendingSaveCompletion = nil
            }
        }
        pendingSaveWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
        
        let script = """
        (function(){
          var api = window.\(apiObj);
          if (!api || typeof api.getSaveData !== 'function') {
            try { window.webkit.messageHandlers.j2me.postMessage({ type: 'getSaveDataResult', base64: null }); } catch(e) {}
            return;
          }
          api.getSaveData().then(function(b64) {
            console.log("!!!!!!success!!!!");
            try { window.webkit.messageHandlers.j2me.postMessage({ type: 'getSaveDataResult', base64: b64 }); } catch(e) {}
          }).catch(function() {
            console.log("!!!!!!failed!!!!");
            try { window.webkit.messageHandlers.j2me.postMessage({ type: 'getSaveDataResult', base64: null }); } catch(e) {}
          });
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error = error {
                Log.debug("❌ Get save data script failed: \(error)")
                self?.pendingSaveWorkItem?.cancel()
                self?.pendingSavePath = nil
                self?.pendingSaveCompletion?(false)
                self?.pendingSaveCompletion = nil
            }
        }
    }
    
    /// Load SRAM from file
    func loadSave(path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            Log.debug("❌ Save file not found: \(path)")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let base64 = data.base64EncodedString()
            
            let apiObj: String
            switch coreType {
            case .j2meJS: apiObj = "j2meAPI"
            case .freej2meWeb: apiObj = "freej2meAPI"
            }
            let script = "if (window.\(apiObj)) window.\(apiObj).loadSaveData('\(base64)');"
            
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    Log.debug("❌ Load save failed: \(error)")
                } else {
                    Log.debug("✅ Save loaded: \(path)")
                }
            }
        } catch {
            Log.debug("❌ Read save file failed: \(error)")
        }
    }
    
    // MARK: - Save State (Instant Save)
    
    /// Save instant save state to file
    func saveState(completion: ((_ data: Data?) -> Void)? = nil) {
        let previousCallback = onExportSaveStateComplete
        
        onExportSaveStateComplete = { [weak self] data, success in
            self?.onExportSaveStateComplete = previousCallback
            
            guard success, let data = data else {
                Log.debug("❌ Export save state failed")
                completion?(nil)
                return
            }
            
            Log.debug("✅ Save state generated")
            completion?(data)
        }
        
        let apiObj: String
        switch coreType {
        case .j2meJS: apiObj = "j2meAPI"
        case .freej2meWeb: apiObj = "freej2meAPI"
        }
        let script = "if (window.\(apiObj) && window.\(apiObj).exportSaveState) window.\(apiObj).exportSaveState();"
        
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error = error {
                Log.debug("❌ Export save state call failed: \(error)")
                self?.onExportSaveStateComplete = previousCallback
                completion?(nil)
            }
        }
    }
    
    /// Load instant save state from file
    func loadSaveState(path: String, completion: ((_ isSuccess: Bool) -> Void)? = nil) {
        guard FileManager.default.fileExists(atPath: path) else {
            Log.debug("❌ Save state file not found: \(path)")
            completion?(false)
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let base64String = data.base64EncodedString()
            
            let previousCallback = onImportSaveStateComplete
            onImportSaveStateComplete = { [weak self] success, error in
                guard let self else { return }
                self.onImportSaveStateComplete = previousCallback
                
                if success {
                    Log.debug("✅ Save state imported, resetting game...")
                    // For j2meJS: RecordStore is now in IndexedDB; reset so the game
                    // restarts and loads its state from the restored RecordStore.
                    if self.coreType == .j2meJS {
                        self.reset(screenSize: self.screenSize, rotation: self.rotation)
                    }
                } else {
                    Log.debug("❌ Load save state failed: \(error ?? "unknown error")")
                }
                completion?(success)
            }
            
            let apiObj: String
            switch coreType {
            case .j2meJS: apiObj = "j2meAPI"
            case .freej2meWeb: apiObj = "freej2meAPI"
            }
            let script = "if (window.\(apiObj) && window.\(apiObj).importSaveState) window.\(apiObj).importSaveState('\(base64String)');"
            
            webView.evaluateJavaScript(script) { [weak self] _, error in
                if let error = error {
                    Log.debug("❌ Import save state failed: \(error)")
                    self?.onImportSaveStateComplete = previousCallback
                    completion?(false)
                }
            }
        } catch {
            Log.debug("❌ Read save state file failed: \(error)")
            completion?(false)
        }
    }
    
    // MARK: - Screen Settings
    
    /// Set screen size
    func setAspect(width: Int, height: Int) {
        let script: String
        switch coreType {
        case .j2meJS:
            script = "if (window.j2meAPI && window.j2meAPI.setScreenSize) window.j2meAPI.setScreenSize(\(width), \(height));"
        case .freej2meWeb:
            script = "if (window.freej2meAPI && window.freej2meAPI.setScreenSize) window.freej2meAPI.setScreenSize(\(width), \(height));"
        }
        webView.evaluateJavaScript(script)
    }
    
    // MARK: - Input Control
    
    /// Press a button
    /// - Parameters:
    ///   - button: The button to press
    func pressButton(_ button: J2MEButton, pressed: Bool) {
        if coreType == .j2meJS {
            //需要处理以下防抖
            if pressed {
                if pressingButtons.contains([button]) {
                    return
                }
                pressingButtons.append(button)
            } else {
                pressingButtons.removeAll(where: { $0 == button })
            }
        }
        let action = pressed ? "keyDown" : "keyUp"
        let script = "if (window.Input) window.Input.\(action)('\(button.keyCode)');"
        webView.evaluateJavaScript(script)
    }
    
    // MARK: - Audio
    
    /// Set mute state
    func setMute(_ mute: Bool) {
        let script: String
        switch coreType {
        case .j2meJS:
            script = "if (window.j2meAPI) window.j2meAPI.setMute(\(mute));"
        case .freej2meWeb:
            script = "if (window.freej2meAPI) window.freej2meAPI.setMute(\(mute));"
        }
        webView.evaluateJavaScript(script)
    }
    
    // MARK: - Screenshot
    
    /// Get screenshot
    func snapShot() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: webView.bounds)
        let image = renderer.image { _ in
            webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: true)
        }
        return image
    }
    
    // MARK: - Fast Forward
    
    /// Set emulation speed (1.0 = normal, 2.0 = 2x, etc.)
    func fastForward(speed: Float) {
        let script: String
        switch coreType {
        case .j2meJS:
            script = "if (window.j2meAPI && window.j2meAPI.setSpeed) window.j2meAPI.setSpeed(\(speed));"
        case .freej2meWeb:
            script = "if (window.freej2meAPI) window.freej2meAPI.setSpeed(\(speed));"
        }
        webView.evaluateJavaScript(script)
    }
    
    // MARK: - Pause/Resume
    
    /// Pause the emulator
    func pause() {
        let script: String
        switch coreType {
        case .j2meJS:
            script = "if (window.j2meAPI && window.j2meAPI.pause) window.j2meAPI.pause();"
        case .freej2meWeb:
            script = "if (window.freej2meAPI && window.freej2meAPI.pause) window.freej2meAPI.pause();"
        }
        webView.evaluateJavaScript(script)
        isPaused = true
    }
    
    /// Resume the emulator
    func resume() {
        let script: String
        switch coreType {
        case .j2meJS:
            script = "if (window.j2meAPI && window.j2meAPI.resume) window.j2meAPI.resume();"
        case .freej2meWeb:
            script = "if (window.freej2meAPI && window.freej2meAPI.resume) window.freej2meAPI.resume();"
        }
        webView.evaluateJavaScript(script)
        isPaused = false
    }
    
    /// Set scale mode ('stretch' or 'fit')
    func setScaleMode(_ scale: GameOption.ScreenScaling) {
        let script: String
        let mode = scale == .stretch ? "stretch" : "fit"
        switch coreType {
        case .j2meJS:
            script = "if (window.j2meAPI && window.j2meAPI.setScaleMode) window.j2meAPI.setScaleMode('\(mode)');"
        case .freej2meWeb:
            script = "if (window.freej2meAPI && window.freej2meAPI.setScaleMode) window.freej2meAPI.setScaleMode('\(mode)');"
        }
        webView.evaluateJavaScript(script)
    }
    
    // MARK: - Private Helpers
    
    private func buildJ2meJSLoadScript(jarURL: String, fileName: String, screenSize: J2MESize, rotation: Bool) -> String {
        // Pass screen size as third arg to _openJar so canvas is sized before startApp() runs.
        // JS accepts "WxH" string or null.
        let sizeArg = "'\(screenSize.width)x\(screenSize.height)'"
        let rotationArg = rotation ? "true" : "false"
        return """
        (async () => {
            try {
                console.log('🔄 Loading JAR: \(fileName)');
        
                const response = await fetch('\(jarURL)');
                if (!response.ok) {
                    console.log('Download error:' + response.status);
                    throw new Error('HTTP ' + response.status);
                }
                const buffer = await response.arrayBuffer();
                const bytes = new Uint8Array(buffer);
        
                console.log('📦 JAR size:', bytes.length, 'bytes');
        
                if (window.j2me && window.j2me.openJar) {
                    window.j2me.openJar(bytes, '\(fileName)', \(sizeArg), \(rotationArg));
                    console.log('✅ JAR loaded successfully');
                    try { window.webkit.messageHandlers.j2me.postMessage({ type: 'openJarCompletion', success: true }); } catch(e) {}
                } else {
                    console.error('❌ J2ME not ready');
                    try { window.webkit.messageHandlers.j2me.postMessage({ type: 'openJarCompletion', success: false }); } catch(e) {}
                }
            } catch (error) {
                console.error('❌ JAR loading failed:', error);
                try { window.webkit.messageHandlers.j2me.postMessage({ type: 'openJarCompletion', success: false }); } catch(e) {}
            }
        })();
        null;
        """
    }
    
    private func buildFreej2meLoadScript(jarURL: String, fileName: String, saveBase64: String? = nil, screenSize: J2MESize, rotation: Bool) -> String {
        // Pass saveBase64 as a JS string literal (null if none). The openJar function
        // will call LauncherUtil.importData() BEFORE starting FreeJ2ME.main() so that
        // CheerpJ has no running Java code when the import happens.
        let saveArg = saveBase64.map { "'\($0)'" } ?? "null"
        
        // Pass device locale so freej2me sets microedition.locale to match the system
        // language (same behavior as J2meJS which reads navigator.language).
        // Converts iOS locale format (e.g. "zh-Hans-CN") to BCP-47 short form ("zh-CN").
        let locale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        // Simplify script-subtag locales: "zh-Hans-CN" → "zh-CN"
        let localeParts = locale.components(separatedBy: "-")
        let shortLocale: String
        if localeParts.count >= 3 {
            shortLocale = "\(localeParts[0])-\(localeParts[localeParts.count - 1])"
        } else {
            shortLocale = locale
        }
        
        let sizeArg = "'\(screenSize.width)x\(screenSize.height)'"
        let rotationArg = rotation ? "true" : "false"
        
        return """
        (async () => {
            try {
                console.log('🔄 Loading JAR: \(fileName)');
        
                const response = await fetch('\(jarURL)');
                if (!response.ok) {
                    console.log('Download error:' + response.status);
                    throw new Error('HTTP ' + response.status);
                }
                const buffer = await response.arrayBuffer();
                const bytes = new Uint8Array(buffer);
        
                console.log('📦 JAR size:', bytes.length, 'bytes');
        
                if (window.freej2meAPI && window.freej2meAPI.openJar) {
                    await window.freej2meAPI.openJar(bytes, '\(fileName)', \(saveArg), '\(shortLocale)', \(sizeArg), \(rotationArg));
                    console.log('✅ freej2me JAR loaded successfully');
                    try { window.webkit.messageHandlers.j2me.postMessage({ type: 'openJarCompletion', success: true }); } catch(e) {}
                } else {
                    console.error('❌ freej2me not ready');
                    try { window.webkit.messageHandlers.j2me.postMessage({ type: 'openJarCompletion', success: false }); } catch(e) {}
                }
            } catch (error) {
                console.error('❌ JAR loading failed:', error);
                try { window.webkit.messageHandlers.j2me.postMessage({ type: 'openJarCompletion', success: false }); } catch(e) {}
            }
        })();
        null;
        """
    }
}

// MARK: - WKScriptMessageHandler
extension J2MEView: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "console" {
            if let body = message.body as? [String: String],
               let type = body["type"],
               let msg = body["message"] {
                Log.debug("JS [\(type)]: \(msg)")
            }
            return
        }
        
        guard message.name == "j2me",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            return
        }
        
        switch type {
        case "openJarCompletion":
            if let success = body["success"] as? Bool {
                DispatchQueue.main.asyncAfter(delay: 3.75) { [weak self] in
                    self?.openJarCompletion?(success)
                }
            }
            
        case "getSaveDataResult":
            //手动调用save方法获取游戏存档
            pendingSaveWorkItem?.cancel()
            pendingSaveWorkItem = nil
            let path = pendingSavePath
            let comp = pendingSaveCompletion
            pendingSavePath = nil
            pendingSaveCompletion = nil
            guard let path = path else { break }
            let base64String = body["base64"] as? String
            if let b64 = base64String, !b64.isEmpty, let data = Data(base64Encoded: b64) {
                do {
                    try data.write(to: URL(fileURLWithPath: path))
                    Log.debug("✅ Save data written to: \(path)")
                    comp?(true)
                } catch {
                    Log.debug("❌ Write save data failed: \(error)")
                    comp?(false)
                }
            } else {
                Log.debug("❌ No save data available")
                comp?(false)
            }
            
        case "saveDataWritten":
            // Auto-save triggered by game
            if let base64Data = body["data"] as? String,
               let data = Data(base64Encoded: base64Data),
               let savePath {
                try? data.write(to: URL(fileURLWithPath: savePath))
                Log.debug("✅ Auto-save updated")
            }
            
        case "exportSaveStateComplete":
            let success = body["success"] as? Bool ?? false
            if success, let base64Data = body["data"] as? String,
               let data = Data(base64Encoded: base64Data) {
                onExportSaveStateComplete?(data, true)
            } else {
                onExportSaveStateComplete?(nil, false)
            }
            
        case "importSaveStateComplete":
            let success = body["success"] as? Bool ?? false
            let error = body["error"] as? String
            onImportSaveStateComplete?(success, error)
            
        case "ready":
            Log.debug("✅ J2ME core ready")
            didFinishedInit?()
            
        case "exit":
            Log.debug("🚪 MIDlet requested exit")
            onExit?()
            
        case "evalNative":
            // Handle network commands from JavaScript evalNative bridge
            guard let networkBridge = networkBridge,
                  let command = body["command"] as? String,
                  let data = body["data"] as? [String: Any] else {
                break
            }
            let hasCallback = body["hasCallback"] as? Bool ?? false
            networkBridge.handleCommand(command, data: data, callback: hasCallback ? { result in
                // Callback is handled by injectCallback in networkBridge
                // The result is already injected into JavaScript by the bridge
            } : nil)
            
        default:
            break
        }
    }
}

// MARK: - WKNavigationDelegate
extension J2MEView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Log.debug("✅ WebView loaded")
        checkInitStatus()
    }
    
    func checkInitStatus() {
        let script: String
        switch coreType {
        case .j2meJS:
            script = "typeof window.j2me !== 'undefined'"
        case .freej2meWeb:
            script = "window.freej2meReady === true"
        }
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            if let isAvailable = result as? Bool, isAvailable {
                Log.debug("✅ J2ME API ready")
                // didFinishedInit is also called from the 'ready' message handler;
                // avoid calling it twice by checking here.
            } else {
                Log.debug("⚠️ J2ME API not ready, waiting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.checkInitStatus()
                }
            }
        }
    }
}

// MARK: - WKUIDelegate
extension J2MEView: WKUIDelegate {
}
