//
//  PhotoSaver.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/5/16.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import Photos

struct PhotoSaver {
    static func save(photoPath: String) {
        if let image = UIImage(contentsOfFile: photoPath) {
            save(image: image)
        }
    }
    
    static func save(image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.9) {
            save(datas: [data])
        }
    }
    
    static func save(images: [UIImage]) {
        guard images.count > 0 else { return }
        save(datas: images.compactMap({ $0.jpegData(compressionQuality: 0.9) }))
    }
    
    static func save(datas: [Data]) {
        guard datas.count > 0 else { return }
        PermissionKit.requestPhoto {
            PHPhotoLibrary.shared().performChanges({
                for imageData in datas {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: imageData, options: nil)
                }
            }) { (success, error) in
                DispatchQueue.main.asyncAfter(delay: UserDefaults.standard.bool(forKey: R.DefaultKey.HadSavedSnapshot) ? 0 : 1) {
                    UserDefaults.standard.setValue(true, forKey: R.DefaultKey.HadSavedSnapshot)
                    UIView.makeToast(message: success ? R.string.localizable.toastSuccess() : R.string.localizable.toastFailed(), identifier: "PhotoSaver")
                }
            }
        }
    }
    
    
}
