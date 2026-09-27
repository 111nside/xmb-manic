//
//  TriggerButton.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/10/22.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

class TriggerButton: BaseView {
    // MARK: - Properties
    var style: TriggerItem.Style = .classic {
        didSet {
            reload()
        }
    }
    var image: UIImage? {
        didSet {
            if style == .custom {
                reload()
            }
        }
    }
    var title: String? {
        didSet {
            if style != .custom {
                reload()
            }
        }
    }
    var buttonSize: CGSize {
        didSet {
            frame.size = buttonSize
            reload()
        }
    }
    var buttonCornerRadius: CGFloat {
        didSet {
            if style == .custom {
                reload()
            }
        }
    }
    var buttonOpacity: CGFloat {
        didSet {
            reload()
        }
    }
    
    // MARK: - UI Components
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()
    
    private let shadowLabel: ShadowLabel = {
        let label = ShadowLabel()
        label.innerShadowBlur = 2.5
        label.innerShadowColor = .black.withAlphaComponent(0.3)
        label.innerShadowOffset = .init(width: 0, height: 1.25*UIScreen.main.scale)
        label.shadowBlur = 2.5
        label.shadowColor = .black.withAlphaComponent(0.3)
        label.shadowOffset = .init(width: 0, height: 0)
        label.textAlignment = .center
        label.textColor = UIColor(hexString: "#cccccc")
        label.isHidden = true
        return label
    }()
    
    private let normalLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    // MARK: - Initialization
    init(style: TriggerItem.Style, image: UIImage? = nil, title: String?, buttonSize: CGSize, buttonCornerRadius: CGFloat, buttonOpacity: CGFloat, isEditMode: Bool) {
        self.style = style
        self.image = image
        self.title = title
        self.buttonSize = buttonSize
        self.buttonCornerRadius = buttonCornerRadius
        self.buttonOpacity = buttonOpacity
        super.init(frame: CGRect(origin: .zero, size: buttonSize))
        setupViews()
        if isEditMode {
            enablePressEffect = true
            isUserInteractionEnabled = false
        }
        reload()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        addSubview(backgroundImageView)
        addSubview(normalLabel)
        normalLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        addSubview(shadowLabel)
        shadowLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        backgroundImageView.frame = bounds
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageView.frame = bounds
    }
    
    // MARK: - Configuration
    private func reload() {
        switch style {
        case .classic:
            layerCornerRadius = 0
            backgroundImageView.image = R.image.triggerPro_classic_button()?.scaled(toWidth: buttonSize.width)
            backgroundImageView.contentMode = .scaleAspectFit
            backgroundImageView.backgroundColor = .clear
            
            shadowLabel.text = title
            shadowLabel.font = style.getFont(buttonSize: buttonSize)
            shadowLabel.isHidden = false
            normalLabel.isHidden = true
            
        case .flat:
            layerCornerRadius = 0
            backgroundImageView.image = R.image.triggerPro_flat_button()?.scaled(toWidth: buttonSize.width)
            backgroundImageView.contentMode = .scaleAspectFit
            backgroundImageView.backgroundColor = .clear
            
            normalLabel.text = title
            normalLabel.font = style.getFont(buttonSize: buttonSize)
            shadowLabel.isHidden = true
            normalLabel.isHidden = false
            
        case .custom:
            layerCornerRadius = buttonCornerRadius
            let defaultImage = R.image.customPhotoBadgePlusFill()!.applySymbolConfig(font: UIFont.systemFont(ofSize: buttonSize.height*0.46, weight: .medium))
            backgroundImageView.image = image?.scaled(toWidth: buttonSize.width) ?? defaultImage
            if let _ = image {
                backgroundImageView.contentMode = .scaleAspectFill
                backgroundImageView.backgroundColor = .clear
            } else {
                backgroundImageView.contentMode = .center
                backgroundImageView.backgroundColor = R.Color.BackgroundTertiary
            }
            
            shadowLabel.isHidden = true
            normalLabel.isHidden = true
        }
        alpha = buttonOpacity
    }
    
    func pressEffect() {
        performButtonTransformation(CGAffineTransform(scaleX: 0.9, y: 0.9), isSelected: false)
    }
    
    func releaseEffect() {
        performButtonTransformation(CGAffineTransform(scaleX: 1, y: 1), isSelected: true)
    }
    
    private func performButtonTransformation(_ transformation: CGAffineTransform, isSelected: Bool) {
        let timingParameters = UISpringTimingParameters(dampingRatio: 1.0, initialVelocity: CGVector(dx: 0.2, dy: 0.2))
        let animator = UIViewPropertyAnimator(duration: 0.65, timingParameters: timingParameters)
        animator.addAnimations { [weak self] in
            guard let self = self else { return }
            self.transform = transformation
        }
        animator.isInterruptible = true
        animator.startAnimation()
    }
}
