//
//  FlexItemView.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/7/15.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import UIKit
import ZIPFoundation

class FlexItemView: UIView {
    static let resizeHandleHitSize: CGFloat = 30
    
    let item: ControllerSkin.Item
    let itemJSONIndex: Int
    
    /// mappingSize 坐标系下的摇杆头初始尺寸，保存时按 frame 缩放比例同步更新
    let initialKnobMappingSize: CGSize?
    
    let resizeHandle: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        
        let icon = IconView()
        icon.imageView.contentMode = .scaleAspectFit
        icon.image = UIImage(symbol: .chevronCompactRight,
                             font: R.Font.Footnote(emphasis: true),
                             color: R.Color.LabelPrimary.forceStyle(.dark))
        icon.transform = CGAffineTransform(rotationAngle: .pi / 4)
        view.addSubview(icon)
        icon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(14)
        }
        return view
    }()
    
    private let imageView = UIImageView()
    private let thumbstickKnobView = UIImageView()
    private let borderView: AuxiliaryLineView
    private let normalizedThumbstickKnobSize: CGSize?
    
    init(item: ControllerSkin.Item,
         itemJSONIndex: Int,
         frame: CGRect,
         controllerSkin: ControllerSkin,
         traits: ControllerSkin.Traits,
         preferredSize: ControllerSkin.Size) {
        self.item = item
        self.itemJSONIndex = itemJSONIndex
        
        if item.kind == .thumbstick,
           let mappingSize = controllerSkin.aspectRatio(for: traits),
           let (_, normalizedSize) = controllerSkin.thumbstick(for: item, traits: traits, preferredSize: preferredSize) {
            self.normalizedThumbstickKnobSize = normalizedSize
            self.initialKnobMappingSize = CGSize(
                width: normalizedSize.width * mappingSize.width,
                height: normalizedSize.height * mappingSize.height
            )
        } else {
            self.normalizedThumbstickKnobSize = nil
            self.initialKnobMappingSize = nil
        }
        
        self.borderView = AuxiliaryLineView(frame: .zero,
                                            enableCrosshair: false,
                                            enableBorder: true,
                                            enableEdgeHandles: false)
        
        super.init(frame: frame)
        
        clipsToBounds = false
        isUserInteractionEnabled = true
        
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)
        
        thumbstickKnobView.contentMode = .center
        thumbstickKnobView.isUserInteractionEnabled = false
        thumbstickKnobView.isHidden = item.kind != .thumbstick
        addSubview(thumbstickKnobView)
        
        borderView.isUserInteractionEnabled = false
        addSubview(borderView)
        
        addSubview(resizeHandle)
        
        loadImages(controllerSkin: controllerSkin, traits: traits)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView.frame = bounds
        borderView.frame = bounds
        
        let hitSize = Self.resizeHandleHitSize
        resizeHandle.frame = CGRect(x: bounds.width - hitSize * 0.65,
                                    y: bounds.height - hitSize * 0.65,
                                    width: hitSize,
                                    height: hitSize)
        
        guard item.kind == .thumbstick, let normalizedSize = normalizedThumbstickKnobSize else { return }
        
        // 摇杆头尺寸与 frame 成比例：JSON 中 width/height 是 mappingSize 下的绝对像素，
        // 归一化后乘以当前 bounds，缩放 frame 时摇杆头同步缩放，保持操作手感。
        let knobSize = CGSize(width: normalizedSize.width * bounds.width,
                              height: normalizedSize.height * bounds.height)
        thumbstickKnobView.bounds.size = knobSize
        thumbstickKnobView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if super.point(inside: point, with: event) {
            return true
        }
        let handlePoint = convert(point, to: resizeHandle)
        return resizeHandle.point(inside: handlePoint, with: event)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        
        let handlePoint = convert(point, to: resizeHandle)
        if resizeHandle.point(inside: handlePoint, with: event) {
            return resizeHandle
        }
        
        if self.point(inside: point, with: event) {
            return self
        }
        return nil
    }
    
    private func loadImages(controllerSkin: ControllerSkin,
                            traits: ControllerSkin.Traits) {
        switch item.kind {
        case .button, .dPad:
            guard let asset = item.asset else { return }
            let imageName: String?
            switch asset {
            case .button(let normal, let selected):
                imageName = normal ?? selected
            case .dpad(let normal):
                imageName = normal
            default:
                imageName = nil
            }
            if let imageName {
                imageView.image = Self.loadImage(from: controllerSkin.fileURL,
                                                 name: imageName,
                                                 targetSize: bounds.size)
            }
            
        case .thumbstick:
            if let (image, _) = controllerSkin.thumbstick(for: item, traits: traits, preferredSize: .medium) {
                thumbstickKnobView.image = image
            }
            
        case .switchButton:
            if let (onImage, offImage) = controllerSkin.switchView(for: item,
                                                                   traits: traits,
                                                                   onImageSize: bounds.size,
                                                                   offImageSize: bounds.size) {
                imageView.image = offImage ?? onImage
            }
            
        case .touchScreen:
            break
        }
    }
    
    func reloadImages(controllerSkin: ControllerSkin, traits: ControllerSkin.Traits) {
        loadImages(controllerSkin: controllerSkin, traits: traits)
    }
    
    private static func loadImage(from skinURL: URL, name: String, targetSize: CGSize) -> UIImage? {
        guard let archive = Archive(url: skinURL, accessMode: .read),
              let entry = archive[name] else { return nil }
        
        var data = Data()
        guard (try? archive.extract(entry) { data.append($0) }) != nil else { return nil }
        
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf":
            return UIImage.image(withPDFData: data, targetSize: targetSize)
        default:
            return UIImage(data: data, scale: 1.0)
        }
    }
}
