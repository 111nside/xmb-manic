//
//  FileManagerExtensions.swift
//  ManicEmu
//
//  Created by Max on 2025/1/20.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension FileManager {
    static func safeMoveItem(at srcURL: URL, to dstURL: URL, shouldReplace: Bool = false) throws {
        do {
            try completePath(url: dstURL)
            if shouldReplace {
                try safeRemoveItem(at: dstURL)
            }
            try FileManager.default.moveItem(at: srcURL, to: dstURL)
        } catch {
            throw error
        }
    }
    
    static func safeCopyItem(at srcURL: URL, to dstURL: URL, shouldReplace: Bool = false) throws {
        do {
            try completePath(url: dstURL)
            if shouldReplace {
                try safeRemoveItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch {
            throw error
        }
    }
    
    static func safeReplaceDirectory(at srcURL: URL, to dstURL: URL) throws {
        guard isDirectory(at: srcURL) else { return }
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: srcURL.path)
            try completePath(url: dstURL)
            for content in contents {
                let contentDstURL = dstURL.appendingPathComponent(content)
                try completePath(url: contentDstURL)
                try safeCopyItem(at: srcURL.appendingPathComponent(content), to: contentDstURL, shouldReplace: true)
            }
        } catch {
            throw error
        }
    }
    
    static func safeRemoveItem(at url: URL) throws {
        do {
            let manager = FileManager.default
            if manager.fileExists(atPath: url.path) {
                try manager.removeItem(at: url)
            }
        } catch {
            throw error
        }
    }
    
    static func safeMergeDirectories(srcURL: URL, dstURL: URL) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: srcURL.path) else {
            throw NSError(domain: "MergeError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source not exists"])
        }
        
        try completePath(url: dstURL)
        
        let items = try fileManager.contentsOfDirectory(at: srcURL, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        
        for item in items {
            let destItem = dstURL.appendingPathComponent(item.lastPathComponent)
            
            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false
            
            if isDirectory {
                // Recursively merge folders (without overwriting entire folders)
                try safeMergeDirectories(srcURL: item, dstURL: destItem)
            } else {
                // File: Overwrite if exists
                try safeCopyItem(at: item, to: destItem, shouldReplace: true)
            }
        }
    }
    
    static func completePath(url: URL) throws {
        do {
            let manager = FileManager.default
            if manager.fileExists(atPath: url.path) {
                return
            } else {
                if isDirectory(at: url) {
                    try manager.createDirectory(at: url, withIntermediateDirectories: true)
                } else {
                    try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                }
            }
        } catch {
            throw error
        }
    }
    
    static func isDirectory(at url: URL) -> Bool {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValues.isDirectory == true
        } catch {
            return false
        }
    }
}
