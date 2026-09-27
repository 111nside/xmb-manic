//
//  LandscapeBackgroundView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/22.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Kingfisher
import VisualEffectView
import BlurUIKit

///横屏模式的动态背景视图
///无背景图时自动播放ShaderToy动态背景 有背景图时展示静态图片并支持暗角/模糊/压暗等效果处理
class LandscapeBackgroundView: BaseView {
    
    ///静态图片背景的效果配置
    struct ImageEffects {
        ///高斯模糊半径 0表示不模糊
        var blurRadius: CGFloat = 0
        ///压暗遮罩透明度 0表示不压暗
        var dimAlpha: CGFloat = 0.35
        ///是否开启暗角
        var vignette: Bool = true
        ///底部向上渐变模糊 用于凸显前景信息
        var bottomFade: Bool = true
        
        static var `default`: ImageEffects { ImageEffects() }
    }
    
    ///背景模式
    enum Background {
        ///ShaderToy动态背景 reload=true 会重新读取配置
        case shader(reload: Bool)
        ///静态图片背景
        case image(UIImage, effects: ImageEffects = .default)
        ///在线图片背景
        case imageUrl(URL, effects: ImageEffects = .default)
    }
    
    ///当前背景 nil表示默认Shader背景
    private var background: Background? = nil
    
    private var metalToyView: MetalToyView? = nil
    var currentShaderToy: ShaderToy? = nil
    
    ///图片背景容器
    private let imageContainerView = UIView()
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    ///高斯模糊层
    private let blurView: VisualEffectView = {
        let view = VisualEffectView()
        view.colorTint = .clear
        view.colorTintAlpha = 0
        return view
    }()
    ///暗角层
    private let vignetteView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleToFill
        return view
    }()
    ///压暗层
    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }()
    ///底部向上渐变模糊层
    private let bottomFadeView: BlurUIKit.VariableBlurView = {
        let view = BlurUIKit.VariableBlurView()
        view.direction = .up
        view.maximumBlurRadius = 1
        view.dimmingAlpha = .constant(alpha: 0.1)
        view.dimmingTintColor = R.Color.BackgroundPrimary
        return view
    }()
    
    private var vignetteSize: CGSize = .zero
    ///在线图片加载令牌 防止快速切换时旧图覆盖新图
    private var imageLoadToken = UUID()
    
    ///暂停原因可叠加 全部清除且处于Shader模式才恢复播放
    private enum PauseReason: Hashable {
        case hidden
        case appInactive
        case homeInvisible
        case fullscreenSheet
    }
    private var pauseReasons: Set<PauseReason> = []
    private var fullscreenSheetCount = 0
    
    private var notificationTokens = [Any]()
    
    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = R.Color.BackgroundPrimary
        clipsToBounds = true
        
        currentShaderToy = ShaderToy.getUsingShaderToy()
        if let currentShaderToy,
            let script = currentShaderToy.script {
            let view = MetalToyView(glslSource: script)
            view.renderScale = currentShaderToy.preferredRenderScale
            view.preferredFramesPerSecond = 30
            addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            view.start()
            metalToyView = view
        }

        addSubview(imageContainerView)
        imageContainerView.alpha = 0
        imageContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageContainerView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageContainerView.addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageContainerView.addSubview(vignetteView)
        vignetteView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageContainerView.addSubview(dimView)
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageContainerView.addSubview(bottomFadeView)
        bottomFadeView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.45)
        }
        
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: R.NotificationName.GradientColorChange, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if let currentShaderToy = self.currentShaderToy,
                currentShaderToy.style == .gradientFlow,
                self.isShaderMode {
                self.showShader(forceReload: true, animated: false)
            }
        })
        
        notificationTokens.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.setPaused(true, reason: .appInactive)
        })
        notificationTokens.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.setPaused(false, reason: .appInactive)
        })
        
        notificationTokens.append(center.addObserver(forName: R.NotificationName.LandscapeBackgroundFullscreenSheet, object: nil, queue: .main) { [weak self] notification in
            guard let self, let visible = notification.object as? Bool else { return }
            if visible {
                self.fullscreenSheetCount += 1
            } else {
                self.fullscreenSheetCount = max(0, self.fullscreenSheetCount - 1)
            }
            self.setPaused(self.fullscreenSheetCount > 0, reason: .fullscreenSheet)
        })
        
        notificationTokens.append(center.addObserver(forName: R.NotificationName.ViewAlongsideTransition, object: nil, queue: .main) { [weak self] _ in
            self?.applyPlaybackState()
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateVignetteIfNeeded()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            if let currentShaderToy {
                switch currentShaderToy.style {
                case .floatingPlaystationShapes, .harmonicSineWave, .pS3HomeBackground, .pSPXMB:
                    //需跟随主题色一起变更
                    if isShaderMode {
                        showShader(forceReload: true, animated: false)
                    }
                default:
                    break
                }
            }
        }
    }
    
    //MARK: - Public
    
    ///设置背景 nil表示回落到默认Shader动态背景
    func setBackground(_ background: Background, animated: Bool = true) {
        self.background = background
        //使旧的在线图片加载失效
        imageLoadToken = UUID()
        
        switch background {
        case .shader(let reload):
            if reload {
                currentShaderToy = ShaderToy.getUsingShaderToy()
            }
            showShader(forceReload: reload, animated: animated)
            
        case .image(let image, let effects):
            showImage(image, effects: effects, animated: animated)
            
        case .imageUrl(let url, let effects):
            let token = imageLoadToken
            KingfisherManager.shared.retrieveImage(with: url) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self, self.imageLoadToken == token else { return }
                    switch result {
                    case .success(let value):
                        self.showImage(value.image, effects: effects, animated: animated)
                    case .failure:
                        //加载失败回落Shader
                        self.showShader(forceReload: false, animated: animated)
                    }
                }
            }
        }
    }
    
    ///暂停渲染 视图隐藏或离开当前tab时调用以节省功耗
    func pauseRendering() {
        setPaused(true, reason: .hidden)
    }
    
    ///恢复渲染 仅当前处于Shader背景且无其他暂停原因时会重新启动
    func resumeRendering() {
        setPaused(false, reason: .hidden)
    }
    
    ///HomeViewController 可见性 进入游戏等会触发 viewWillDisappear
    func setHomeVisible(_ visible: Bool) {
        setPaused(!visible, reason: .homeInvisible)
    }
    
    var isShaderMode: Bool {
        switch background {
        case .none, .shader:
            return true
        default:
            return false
        }
    }
    
    //MARK: - Private
    private func showShader(forceReload: Bool, animated: Bool) {
        if let currentShaderToy,
            let script = currentShaderToy.script {
            if forceReload || metalToyView == nil {
                let newMetalToyView = MetalToyView(glslSource: script)
                newMetalToyView.renderScale = currentShaderToy.preferredRenderScale
                newMetalToyView.preferredFramesPerSecond = 30
                insertSubview(newMetalToyView, belowSubview: imageContainerView)
                newMetalToyView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                metalToyView?.stop()
                metalToyView?.removeFromSuperview()
                metalToyView = newMetalToyView
            }
        } else {
            metalToyView?.stop()
            metalToyView?.removeFromSuperview()
        }
        
        applyPlaybackState()
        
        let animations = {
            self.imageContainerView.alpha = 0
        }
        if animated {
            UIView.animate(withDuration: 0.35, animations: animations) { _ in
                self.clearImageIfNeeded()
            }
        } else {
            animations()
            clearImageIfNeeded()
        }
    }
    
    private func clearImageIfNeeded() {
        if isShaderMode {
            imageView.image = nil
        }
    }
    
    private func showImage(_ image: UIImage, effects: ImageEffects, animated: Bool) {
        imageView.image = image
        applyEffects(effects)
        
        let animations = {
            self.imageContainerView.alpha = 1
        }
        let completion = {
            //图片完全展示后暂停Shader渲染以节省功耗
            self.metalToyView?.pause()
        }
        if animated {
            UIView.animate(withDuration: 0.35, animations: animations) { _ in
                completion()
            }
        } else {
            animations()
            completion()
        }
    }
    
    private func applyEffects(_ effects: ImageEffects) {
        blurView.blurRadius = effects.blurRadius
        blurView.isHidden = effects.blurRadius <= 0
        dimView.alpha = effects.dimAlpha
        dimView.isHidden = effects.dimAlpha <= 0
        vignetteView.isHidden = !effects.vignette
        bottomFadeView.isHidden = !effects.bottomFade
        updateVignetteIfNeeded()
    }
    
    private func setPaused(_ paused: Bool, reason: PauseReason) {
        if paused {
            pauseReasons.insert(reason)
        } else {
            pauseReasons.remove(reason)
        }
        applyPlaybackState()
    }
    
    private var isRenderingSuspended: Bool {
        !pauseReasons.isEmpty
    }
    
    private func applyPlaybackState() {
        if isRenderingSuspended || !isShaderMode {
            metalToyView?.pause()
        } else {
            metalToyView?.start()
        }
    }
    
    private func updateVignetteIfNeeded() {
        guard !vignetteView.isHidden, bounds.size != .zero, vignetteSize != bounds.size else { return }
        vignetteSize = bounds.size
        let size = bounds.size
        UIImage.radialGradientImage(size: size,
                                    colors: [.clear, UIColor.black.withAlphaComponent(0.6)],
                                    startCenter: CGPoint(x: 0.5, y: 0.5),
                                    startRadius: size.minDimension * 0.35,
                                    endRadius: size.maxDimension * 0.75) { [weak self] image in
            guard let self, let image else { return }
            self.vignetteView.image = image
        }
    }
}
