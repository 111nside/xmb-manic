//
//  PermissionKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/21.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import Permission

struct PermissionKit {
    static func requestPhoto(authorized: (()->Void)? = nil) {
        let permission: Permission = .photos
        permission.presentPrePermissionAlert = true
        
        let prePhoto = permission.prePermissionAlert
        prePhoto.title   = R.string.localizable.prePermissionPhotoTitle()
        prePhoto.message = R.string.localizable.prePermissionPhotoMessage()
        prePhoto.cancel  = R.string.localizable.prePermissionPhotoCancel()
        prePhoto.confirm = R.string.localizable.prePermissionPhotoConfirm()
        
        let deniedPhoto = permission.deniedAlert
        deniedPhoto.title   = R.string.localizable.deniedPermissionPhotoTitle()
        deniedPhoto.message = R.string.localizable.deniedPermissionPhotoMessage()
        deniedPhoto.cancel  = R.string.localizable.deniedPermissionPhotoCancel()
        deniedPhoto.settings = R.string.localizable.deniedPermissionPhotoConfirm()

        permission.request { status in
            switch status {
            case .authorized:
                authorized?()
            default:
                break
            }
        }
    }
    
    static func requestCamera(authorized: (()->Void)? = nil) {
        let permission: Permission = .camera
        permission.presentPrePermissionAlert = true
        
        let prePhoto = permission.prePermissionAlert
        prePhoto.title   = R.string.localizable.prePermissionCameraTitle()
        prePhoto.message = R.string.localizable.prePermissionCameraMessage()
        prePhoto.cancel  = R.string.localizable.prePermissionCameraCancel()
        prePhoto.confirm = R.string.localizable.prePermissionCameraConfirm()
        
        let deniedPhoto = permission.deniedAlert
        deniedPhoto.title   = R.string.localizable.deniedPermissionCameraTitle()
        deniedPhoto.message = R.string.localizable.deniedPermissionCameraMessage()
        deniedPhoto.cancel  = R.string.localizable.deniedPermissionCameraCancel()
        deniedPhoto.settings = R.string.localizable.deniedPermissionCameraConfirm()

        permission.request { status in
            switch status {
            case .authorized:
                authorized?()
            default:
                break
            }
        }
    }
    
    static func requestMicrophont(authorized: (()->Void)? = nil, denied: (()->Void)? = nil) {
        let permission: Permission = .microphone
        permission.presentPrePermissionAlert = false

        let deniedPhoto = permission.deniedAlert
        deniedPhoto.title   = R.string.localizable.deniedPermissionMicTitle()
        deniedPhoto.message = R.string.localizable.deniedPermissionMicMessage()
        deniedPhoto.cancel  = R.string.localizable.deniedPermissionMicCancel()
        deniedPhoto.settings = R.string.localizable.deniedPermissionMicConfirm()

        permission.request { status in
            switch status {
            case .authorized:
                authorized?()
            case .denied:
                denied?()
            default:
                break
            }
        }
    }
}
