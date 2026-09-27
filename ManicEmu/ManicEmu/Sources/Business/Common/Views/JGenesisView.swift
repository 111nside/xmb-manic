//
//  JGenesisView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/12/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
import WebKit

// MARK: - JGenesis 配置枚举
enum JGenesisAspectRatio: String {
    case auto = "Auto"
    case ntsc = "Ntsc"
    case pal = "Pal"
    case squarePixels = "SquarePixels"
}

enum JGenesisFilterMode: String {
    case nearest = "Nearest"
    case linear = "Linear"
}

enum JGenesisBlendShader: String {
    case none = "None"
    case horizontalBlurTwoPixels = "HorizontalBlurTwoPixels"
    case horizontalBlurThreePixels = "HorizontalBlurThreePixels"
    case antiDitherWeak = "AntiDitherWeak"
    case antiDitherStrong = "AntiDitherStrong"
}

/// Genesis/Sega CD/32X 6键手柄按钮映射
/// 这些值对应 KeyboardEvent.code 字符串，用于与 JGenesis 核心通信
enum JGenesisButton: String, CaseIterable {
    // 方向键
    case up = "ArrowUp"
    case down = "ArrowDown"
    case left = "ArrowLeft"
    case right = "ArrowRight"
    
    // 6键手柄按钮（默认键盘映射）
    case a = "KeyA"
    case b = "KeyS"
    case c = "KeyD"
    case x = "KeyQ"
    case y = "KeyW"
    case z = "KeyE"
    
    // 功能键
    case start = "Enter"
    case mode = "ShiftRight"
    
    /// 返回用于 JavaScript KeyboardEvent 的 code 值（用于 DOM 事件模式）
    var keyCode: String {
        return self.rawValue
    }
    
    /// 返回按钮名称（用于直接输入模式）
    var buttonName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        case .start: return "Start"
        case .mode: return "Mode"
        }
    }
}

class JGenesisView: BaseView {
    /// 导出 Save State 完成回调（内部使用）
    private var onExportSaveStateComplete: ((_ data: Data?, _ success: Bool) -> Void)?
    /// 导入 Save State 完成回调（内部使用）
    private var onImportSaveStateComplete: ((_ success: Bool, _ error: String?) -> Void)?
    
    /// 初始化完成回调
    var didFinishedInit: (()->Void)? = nil
    
    /// ROM路径
    var romPath: String? = nil
    
    private(set) var isPaused: Bool = false
    
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 添加消息处理器
        let contentController = WKUserContentController()
        let proxy = WeakScriptMessageHandler(target: self)
        contentController.add(proxy, name: "console")
        contentController.add(proxy, name: "jgenesis")
        configuration.userContentController = contentController
        
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.scrollView.isScrollEnabled = false
        
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
    
    private lazy var localServer: LocalWebServer = {
        let server = LocalWebServer()
        try? server.start(serverType: .JGenesis)
        return server
    }()
    
    deinit {
        localServer.stop()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if let url = localServer.getURL() {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 公开接口
extension JGenesisView {
    
    // MARK: 文件操作
    
    /// 打开 ROM 文件（通过文件路径）
    /// - Parameters:
    ///   - filePath: ROM 文件路径
    ///   - fileName: 文件名（包含扩展名，如 "game.32x"）
    func openFile(filePath: String) {
        let saveFilePath = filePath.deletingPathExtension + ".srm"
        if FileManager.default.fileExists(atPath: saveFilePath) {
            loadSave(path: saveFilePath)
        }
        
        romPath = filePath
        let fileName = filePath.lastPathComponent.escapeJSString()
        
        // Register file to local server (127.0.0.1, same origin as the page)
        let fileId = localServer.registerFile(filePath: filePath)
        let romURL = localServer.fileURL(for: fileId)

        let script = """
        (async () => {
            try {
                console.log('🔄 开始加载文件: \(fileName)');

                    const response = await fetch('\(romURL)');
                    if (!response.ok) {
                        console.log('Download error:' + response.status);
                        throw new Error('HTTP ' + response.status);
                    }
                    const buffer = await response.arrayBuffer();
                    const bytes = new Uint8Array(buffer);

                window.jgenesisAPI.openFile(bytes, '\(fileName)');
                console.log('✅ 文件加载成功: \(fileName)');
            } catch (error) {
                console.error('❌ 文件加载失败:', error);
            }
        })();

        null;
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                Log.debug("❌ 执行 JavaScript 失败: \(error)")
            } else {
                Log.debug("✅ JavaScript 注入成功")
            }
        }
    }
    
    /// 打开 Sega CD ROM 文件（同时传入 ROM 和 BIOS 文件）
    /// - Parameters:
    ///   - filePath: ROM 文件路径（CHD 格式）
    ///   - americasBiosPath: 美版 BIOS 文件路径（可选）
    ///   - japanBiosPath: 日版 BIOS 文件路径（可选）
    ///   - europeBiosPath: 欧版 BIOS 文件路径（可选）
    func openSegaCdFile(filePath: String, americasBiosPath: String?, japanBiosPath: String?, europeBiosPath: String?) {
        let saveFilePath = filePath.deletingPathExtension + ".srm"
        if FileManager.default.fileExists(atPath: saveFilePath) {
            loadSave(path: saveFilePath)
        }
        
        romPath = filePath
        let fileName = filePath.lastPathComponent.escapeJSString()
        
        // Register ROM to local server (127.0.0.1, same origin as the page)
        let romFileId = localServer.registerFile(filePath: filePath)
        let romURL = localServer.fileURL(for: romFileId)
        
        // Register BIOS files if present
        var americasBiosURL: String? = nil
        var japanBiosURL: String? = nil
        var europeBiosURL: String? = nil
        
        if let path = americasBiosPath, FileManager.default.fileExists(atPath: path) {
            let fileId = localServer.registerFile(filePath: path)
            americasBiosURL = localServer.fileURL(for: fileId)
        }
        
        if let path = japanBiosPath, FileManager.default.fileExists(atPath: path) {
            let fileId = localServer.registerFile(filePath: path)
            japanBiosURL = localServer.fileURL(for: fileId)
        }
        
        if let path = europeBiosPath, FileManager.default.fileExists(atPath: path) {
            let fileId = localServer.registerFile(filePath: path)
            europeBiosURL = localServer.fileURL(for: fileId)
        }
        
        // 构建 JavaScript 代码中的 BIOS URL 参数
        let americasBiosURLJS = americasBiosURL.map { "'\($0)'" } ?? "null"
        let japanBiosURLJS = japanBiosURL.map { "'\($0)'" } ?? "null"
        let europeBiosURLJS = europeBiosURL.map { "'\($0)'" } ?? "null"
        
        let script = """
        (async () => {
            try {
                console.log('🔄 开始加载 Sega CD 文件: \(fileName)');
                
                // 加载 ROM 文件（直接保持为 Uint8Array，避免 Array.from() 导致的内存膨胀）
                const romResponse = await fetch('\(romURL)');
                if (!romResponse.ok) {
                    console.log('ROM Download error:' + romResponse.status);
                    throw new Error('HTTP ' + romResponse.status);
                }
                const romBuffer = await romResponse.arrayBuffer();
                const romBytes = new Uint8Array(romBuffer);
                console.log('📦 ROM 文件大小:', romBytes.length, 'bytes');
                
                // 加载 BIOS 文件（BIOS 文件较小，使用 Uint8Array）
                let americasBiosBytes = null;
                let japanBiosBytes = null;
                let europeBiosBytes = null;
                
                const americasBiosURL = \(americasBiosURLJS);
                const japanBiosURL = \(japanBiosURLJS);
                const europeBiosURL = \(europeBiosURLJS);
                
                if (americasBiosURL) {
                    try {
                        const response = await fetch(americasBiosURL);
                        if (response.ok) {
                            const buffer = await response.arrayBuffer();
                            americasBiosBytes = new Uint8Array(buffer);
                            console.log('📦 Americas BIOS 大小:', americasBiosBytes.length, 'bytes');
                        }
                    } catch (e) {
                        console.warn('⚠️ 加载 Americas BIOS 失败:', e);
                    }
                }
                
                if (japanBiosURL) {
                    try {
                        const response = await fetch(japanBiosURL);
                        if (response.ok) {
                            const buffer = await response.arrayBuffer();
                            japanBiosBytes = new Uint8Array(buffer);
                            console.log('📦 Japan BIOS 大小:', japanBiosBytes.length, 'bytes');
                        }
                    } catch (e) {
                        console.warn('⚠️ 加载 Japan BIOS 失败:', e);
                    }
                }
                
                if (europeBiosURL) {
                    try {
                        const response = await fetch(europeBiosURL);
                        if (response.ok) {
                            const buffer = await response.arrayBuffer();
                            europeBiosBytes = new Uint8Array(buffer);
                            console.log('📦 Europe BIOS 大小:', europeBiosBytes.length, 'bytes');
                        }
                    } catch (e) {
                        console.warn('⚠️ 加载 Europe BIOS 失败:', e);
                    }
                }
                
                // 检查是否至少有一个 BIOS 可用
                if (!americasBiosBytes && !japanBiosBytes && !europeBiosBytes) {
                    console.error('❌ 没有可用的 Sega CD BIOS 文件');
                    throw new Error('No Sega CD BIOS available');
                }
                
                // 调用 openSegaCdFile API（ROM 直接传递 Uint8Array，避免内存膨胀）
                console.log('✅ 调用 window.jgenesisAPI.openSegaCdFile');
                window.jgenesisAPI.openSegaCdFile(
                    romBytes,
                    '\(fileName)',
                    americasBiosBytes,
                    japanBiosBytes,
                    europeBiosBytes
                );
                
                console.log('✅ Sega CD 文件加载成功: \(fileName)');
            } catch (error) {
                console.error('❌ Sega CD 文件加载失败:', error);
            }
        })();
        
        null;
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                Log.debug("❌ 执行 JavaScript 失败: \(error)")
            } else {
                Log.debug("✅ JavaScript 注入成功")
            }
        }
    }
    
    // MARK: 模拟器控制
    
    /// 重置模拟器
    func reset() {
        let script = "window.jgenesisAPI.reset();"
        webView.evaluateJavaScript(script)
    }
    
    // MARK: - 存档操作 (SRAM Save)
    
    /// 保存 SRAM 存档到文件
    /// - Parameters:
    ///   - path: 保存路径
    ///   - completion: 完成回调
    func save(to path: String, completion: ((_ isSucess: Bool)->Void)? = nil) {
        // 通过 JavaScript 获取当前 SRAM 数据
        let script = """
        (function() {
            if (window.jgenesisAPI && window.jgenesisAPI.getSaveData) {
                return window.jgenesisAPI.getSaveData();
            }
            return null;
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else {
                return
            }
            
            if let error = error {
                Log.debug("❌ 获取存档数据失败: \(error)")
                return
            }
            
            let downloadScript = "window.jgenesisAPI.downloadSave();"
            self.webView.evaluateJavaScript(downloadScript)
        }
    }
    
    /// 从文件加载 SRAM 存档
    /// - Parameter path: 存档文件路径
    func loadSave(path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            Log.debug("❌ 存档文件不存在: \(path)")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            
            let base64 = data.base64EncodedString()
            let script = "window.jgenesisAPI.uploadSave('\(base64)');"
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    Log.debug("❌ 加载存档失败: \(error)")
                } else {
                    Log.debug("✅ 存档已加载: \(path)")
                }
            }
        } catch {
            Log.debug("❌ 读取存档文件失败: \(error)")
        }
    }
    
    // MARK: - 即时存档操作 (Save State)
    
    /// 保存即时存档到文件
    /// - Parameters:
    ///   - completion: 完成回调
    func saveState(completion: ((_ data: Data?)->Void)? = nil) {
        
        // 临时保存回调
        let previousCallback = onExportSaveStateComplete
        
        onExportSaveStateComplete = { [weak self] data, success in
            // 恢复之前的回调
            self?.onExportSaveStateComplete = previousCallback
            
            guard success, let data = data else {
                Log.debug("❌ 导出即时存档失败")
                completion?(nil)
                return
            }
            
            Log.debug("✅ 即时存档已生成")
            completion?(data)
        }
        
        // 触发导出
        let script = "window.jgenesisAPI.exportSaveState();"
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error = error {
                Log.debug("❌ 导出即时存档调用失败: \(error)")
                self?.onExportSaveStateComplete = previousCallback
                completion?(nil)
            }
        }
    }
    
    /// 从文件加载即时存档
    /// - Parameter path: 即时存档文件路径
    func loadSaveState(path: String, completion: ((_ isSuccess: Bool)->Void)? = nil) {
        guard FileManager.default.fileExists(atPath: path) else {
            Log.debug("❌ 即时存档文件不存在: \(path)")
            completion?(false)
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            
            // 保存回调，等待 importSaveStateComplete 消息
            let previousCallback = onImportSaveStateComplete
            onImportSaveStateComplete = { [weak self] success, error in
                // 恢复之前的回调
                self?.onImportSaveStateComplete = previousCallback
                
                if success {
                    Log.debug("✅ 即时存档已加载: \(path)")
                } else {
                    Log.debug("❌ 加载即时存档失败: \(error ?? "未知错误")")
                }
                completion?(success)
            }
            
            let base64String = data.base64EncodedString()
            let script = "window.jgenesisAPI.importSaveState('\(base64String)');"
            webView.evaluateJavaScript(script) { [weak self] _, error in
                if let error = error {
                    Log.debug("❌ 加载即时存档失败: \(error)")
                    // 恢复回调并通知失败
                    self?.onImportSaveStateComplete = previousCallback
                    completion?(false)
                }
            }
        } catch {
            Log.debug("❌ 读取即时存档文件失败: \(error)")
            completion?(false)
        }
    }
    
    // MARK: Genesis/MCD/32X 配置
    
    /// 设置纵横比
    func setAspectRatio(_ ratio: JGenesisAspectRatio) {
        let script = "window.jgenesisAPI.setGenesisAspectRatio('\(ratio.rawValue)');"
        webView.evaluateJavaScript(script)
    }
    
    /// 设置主 CPU 速度（7=100%, 6=117%, 5=140%, 4=175%, 3=233%）
    func setM68kDivider(_ divider: Int) {
        let script = "window.jgenesisAPI.setGenesisM68kDivider(\(divider));"
        webView.evaluateJavaScript(script)
    }
    
    /// 设置是否模拟非线性 VDP 颜色缩放
    func setNonLinearColorScale(_ enabled: Bool) {
        let script = "window.jgenesisAPI.setGenesisNonLinearColorScale(\(enabled));"
        webView.evaluateJavaScript(script)
    }
    
    /// 设置是否移除精灵限制
    func setRemoveSpriteLimits(_ enabled: Bool) {
        let script = "window.jgenesisAPI.setGenesisRemoveSpriteLimits(\(enabled));"
        webView.evaluateJavaScript(script)
    }
    
    /// 设置是否模拟 3.39 KHz 低通滤波器
    func setEmulateLowPass(_ enabled: Bool) {
        let script = "window.jgenesisAPI.setGenesisEmulateLowPass(\(enabled));"
        webView.evaluateJavaScript(script)
    }
    
    /// 设置是否渲染垂直边框
    func setRenderVerticalBorder(_ enabled: Bool) {
        let script = "window.jgenesisAPI.setGenesisRenderVerticalBorder(\(enabled));"
        webView.evaluateJavaScript(script)
    }
    
    /// 设置是否渲染水平边框
    func setRenderHorizontalBorder(_ enabled: Bool) {
        let script = "window.jgenesisAPI.setGenesisRenderHorizontalBorder(\(enabled));"
        webView.evaluateJavaScript(script)
    }
    
    // MARK: 通用配置
    
    /// 设置图像滤镜模式
    func setFilterMode(_ mode: JGenesisFilterMode) {
        let script = "window.jgenesisAPI.setFilterMode('\(mode.rawValue)');"
        webView.evaluateJavaScript(script)
    }
    
    /// 设置混合着色器
    func setBlendShader(_ shader: JGenesisBlendShader) {
        let script = "window.jgenesisAPI.setPreprocessShader('\(shader.rawValue)');"
        webView.evaluateJavaScript(script)
    }
    
    /// 设置预缩放因子（1-4）
    func setPrescaleFactor(_ factor: Int) {
        let script = "window.jgenesisAPI.setPrescaleFactor(\(factor));"
        webView.evaluateJavaScript(script)
    }
    
    /// 恢复默认配置
    func restoreDefaults() {
        let script = "window.jgenesisAPI.restoreDefaults();"
        webView.evaluateJavaScript(script)
    }
    
    // MARK: 输入控制
    
    // MARK: 直接输入（推荐，更低延迟）
    
    /// 直接设置按键状态（绕过 DOM 事件，更低延迟）
    /// - Parameters:
    ///   - button: Genesis/Sega CD/32X 按钮
    ///   - pressed: true 表示按下，false 表示释放
    ///   - player: 玩家编号（1 或 2），默认为 1
    func pressButton(_ button: JGenesisButton, pressed: Bool, player: Int = 1) {
        let script = "window.jgenesisAPI.setGenesisButton('\(button.buttonName)', \(player), \(pressed));"
        webView.evaluateJavaScript(script)
    }
    
    // MARK: 获取配置
    
    /// 获取当前纵横比设置
    func getAspectRatio(completion: @escaping (String?) -> Void) {
        let script = "window.jgenesisAPI.getGenesisAspectRatio();"
        webView.evaluateJavaScript(script) { result, error in
            completion(result as? String)
        }
    }
    
    /// 获取当前 M68k 分频器设置
    func getM68kDivider(completion: @escaping (Int?) -> Void) {
        let script = "window.jgenesisAPI.getGenesisM68kDivider();"
        webView.evaluateJavaScript(script) { result, error in
            completion(result as? Int)
        }
    }
    
    /// 设置是否静音
    /// - Note: 通过暂停/恢复 WebView 的 AudioContext 来实现静音
    func setMute(_ mute: Bool) {
        let script = "window.jgenesisAPI.setMute(\(mute));"
        webView.evaluateJavaScript(script)
    }
    
    /// 获取截图
    /// - Note: 通过 WebView 截图获取当前画面
    func snapShot() -> UIImage? {
        // 使用 WebView 的截图能力
        let renderer = UIGraphicsImageRenderer(bounds: webView.bounds)
        let image = renderer.image { _ in
            webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: true)
        }
        return image
    }
    
    /// 快进 - 设置模拟器运行速度
    /// - Parameter speed: 速度倍率 (1.0 = 正常速度, 2.0 = 2倍速, 等等)
    func fastForward(speed: Float) {
        let clampedSpeed = max(0.25, min(16.0, Double(speed)))
        let script = "window.jgenesisAPI.setSpeedMultiplier(\(clampedSpeed));"
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                Log.debug("❌ 设置快进速度失败: \(error)")
            }
        }
    }
    
    /// 开启快进（默认 2 倍速）
    func enableFastForward(multiplier: Float = 2.0) {
        fastForward(speed: multiplier)
    }
    
    /// 关闭快进，恢复正常速度
    func disableFastForward() {
        fastForward(speed: 1.0)
    }
    
    /// 重置金手指
    /// - Note: JGenesis 核心架构不支持运行时内存修改（Game Genie / Pro Action Replay 等金手指功能）
    ///         这是因为 jgenesis 的设计目标是精准模拟，不包含金手指等修改游戏内存的功能
    ///         如需使用金手指，建议使用其他支持此功能的模拟器核心
    func resetCheatCode() {
        // JGenesis 核心不支持金手指功能
        // EmulatorTrait 接口中没有提供金手指相关的方法
        Log.debug("⚠️ JGenesis 核心不支持金手指功能")
    }
    
    /// 添加金手指
    /// - Parameter code: 金手指代码（Game Genie 或 Pro Action Replay 格式）
    /// - Note: JGenesis 核心架构不支持运行时内存修改（Game Genie / Pro Action Replay 等金手指功能）
    ///         这是因为 jgenesis 的设计目标是精准模拟，不包含金手指等修改游戏内存的功能
    ///         如需使用金手指，建议使用其他支持此功能的模拟器核心
    func addCheatCode(code: String) {
        // JGenesis 核心不支持金手指功能
        // EmulatorTrait 接口中没有提供金手指相关的方法
        Log.debug("⚠️ JGenesis 核心不支持金手指功能: \(code)")
    }
    
    /// 暂停模拟器
    func pause() {
        let script = "window.jgenesisAPI.pause();"
        webView.evaluateJavaScript(script) { [weak self] _, error in
            guard let self else { return }
            if let error = error {
                print("❌ 暂停失败: \(error)")
            } else {
                print("⏸️ 模拟器已暂停")
                self.isPaused = true
            }
        }
    }
    
    /// 恢复模拟器
    func resume() {
        let script = "window.jgenesisAPI.resume();"
        webView.evaluateJavaScript(script) { [weak self] _, error in
            guard let self else { return }
            if let error = error {
                print("❌ 恢复失败: \(error)")
            } else {
                print("▶️ 模拟器已恢复")
                self.isPaused = false
            }
        }
    }
    
    /// 切换暂停状态
    func togglePause() {
        let script = "window.jgenesisAPI.togglePause();"
        webView.evaluateJavaScript(script)
        isPaused.toggle()
    }
    
    /// 获取当前暂停状态
//    func isPaused(completion: @escaping (Bool) -> Void) {
//        let script = "window.jgenesisAPI.isPaused();"
//        webView.evaluateJavaScript(script) { result, _ in
//            completion(result as? Bool ?? false)
//        }
//    }
    
}

// MARK: - WKScriptMessageHandler
extension JGenesisView: WKScriptMessageHandler {
    func decodeUnicodeString(_ str: String) -> String {
        let quoted = "\"\(str)\""
        let data = quoted.data(using: .utf8)!

        if let result = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? String {
            return result
        }

        return str
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "console" {
            if let body = message.body as? Dictionary<String, String> {
                Log.debug("JS: type=\(body["type"]!) message=\(decodeUnicodeString(body["message"]!))")
            }
        }
                
        
        guard message.name == "jgenesis",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            return
        }
        
        switch type {
//        case "saveData":
//            // 手动获取SRAM 存档数据回调
//            if let base64Data = body["data"] as? String,
//               let _ = Data(base64Encoded: base64Data) {
//                // 如果有待处理的保存请求，保存到文件
//            }
//            
//        case "saveNotFound":
//            Log.debug("手动获取存档数据失败 ⚠️ 无存档数据可保存")
            
        case "saveDataWritten":
            // 游戏自动写入 SRAM 存档通知
            if let romPath,
               let base64Data = body["data"] as? String,
               let data = Data(base64Encoded: base64Data) {
                let savePath = romPath.deletingPathExtension + ".srm"
                try? data.writeWithCompletePath(to: URL(fileURLWithPath: savePath))
                Log.debug("更新存档")
            }
            
        case "exportSaveStateComplete":
            // 即时存档导出完成
            let success = body["success"] as? Bool ?? false
            if success, let base64Data = body["data"] as? String, let data = Data(base64Encoded: base64Data) {
                let size = body["size"] as? Int ?? data.count
                Log.debug("📦 导出即时存档完成: 大小 \(size) bytes")
                onExportSaveStateComplete?(data, true)
            } else {
                Log.debug("❌ 导出即时存档失败")
                onExportSaveStateComplete?(nil, false)
            }
            
        case "importSaveStateComplete":
            // 即时存档导入完成
            let success = body["success"] as? Bool ?? false
            let error = body["error"] as? String
            if success {
                Log.debug("📦 导入即时存档完成")
            } else {
                Log.debug("❌ 导入即时存档失败: \(error ?? "未知错误")")
            }
            onImportSaveStateComplete?(success, error)
            
        default:
            break
        }
    }
}

// MARK: - WKNavigationDelegate
extension JGenesisView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Log.debug("✅ WebView 加载完成")
        checkInitStatus()
    }
    
    func checkInitStatus() {
        // 检查 jgenesisAPI 是否可用
        webView.evaluateJavaScript("typeof window.jgenesisAPI !== 'undefined'") { [weak self] result, error in
            guard let self else { return }
            if let isAvailable = result as? Bool, isAvailable {
                Log.debug("✅ jgenesisAPI 已就绪")
                self.didFinishedInit?()
            } else {
                Log.debug("⚠️ jgenesisAPI 尚未就绪，等待初始化...")
                DispatchQueue.main.asyncAfter(delay: 1) {
                    self.checkInitStatus()
                }
            }
        }
    }
}

// MARK: - WKUIDelegate
extension JGenesisView: WKUIDelegate {
    
}

