//
//  CacheManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import Tiercel

struct CacheManager {
    static func clear(completion: (()->Void)? = nil) {
        DispatchQueue.global().async {
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.PasteWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.UploadWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.ShareWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.SMBWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.SaveStateWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.ZipWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.DropWorkSpace))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.ThreeDSStateLoad))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Screenshot))
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Temp))
            try? FileManager.default.createDirectory(atPath: R.Path.Temp, withIntermediateDirectories: true)
            try? FileManager.safeRemoveItem(at: URL(fileURLWithPath: R.Path.Document.appendingPathComponent("wpkdata")))
            try? FileManager.default.createDirectory(atPath: R.Path.Screenshot, withIntermediateDirectories: true)
            let manager = DownloadManager.shared.sessionManager
            manager.tasks.filter({ $0.status == .succeeded }).forEach { manager.remove($0.url) }
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    static var totleSize: String? {
        let size = folderSize(atPath: R.Path.PasteWorkSpace) +
        folderSize(atPath: R.Path.UploadWorkSpace) +
        folderSize(atPath: R.Path.ShareWorkSpace) +
        folderSize(atPath: R.Path.DownloadWorkSpace) +
        folderSize(atPath: R.Path.SMBWorkSpace) +
        folderSize(atPath: R.Path.SaveStateWorkSpace) +
        folderSize(atPath: R.Path.ZipWorkSpace) +
        folderSize(atPath: R.Path.ThreeDSStateLoad)
        return FileType.humanReadableFileSize(size)
    }
    
    static func folderSize(atPath path: String) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0
        
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return totalSize
        }
        
        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 递归获取子文件夹的大小
                    totalSize += folderSize(atPath: itemPath)
                } else {
                    // 获取文件的大小
                    if let attributes = try? fileManager.attributesOfItem(atPath: itemPath),
                       let fileSize = attributes[.size] as? UInt64 {
                        totalSize += fileSize
                    }
                }
            }
        }
        return totalSize
    }
}
