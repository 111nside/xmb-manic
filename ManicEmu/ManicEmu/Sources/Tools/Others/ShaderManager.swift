//
//  ShaderManager.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/8.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

struct ShaderManager {
    
    static func getShaders(source: ShaderListView.ShaderSource? = nil,
                           isGlsl: Bool,
                           includeOriginal: Bool) -> ShaderListData {
        var result = ShaderListData()
        let sourceCase = {
            if let source {
                return [source]
            } else {
                return ShaderListView.ShaderSource.allCases
            }
        }()
        for source in sourceCase {
            if source == .imported {
                if FileManager.default.fileExists(atPath: R.Path.ShaderImportedInDocument) {
                    //复制到shader的工作区
                    try? FileManager.safeCopyItem(at: URL(fileURLWithPath: R.Path.ShaderImportedInDocument), to: URL(fileURLWithPath: R.Path.ShaderImported), shouldReplace: true)
                } else {
                    try? FileManager.default.createDirectory(atPath: R.Path.ShaderImportedInDocument, withIntermediateDirectories: true)
                }
            }
            let isRecursive = source != .custom
            let shadersRelativePathes = findShaderFiles(in: source.searchUrl, isGlsl: isGlsl, isRecursive: isRecursive)
            switch source {
            case .default, .custom:
                var shaders = shadersRelativePathes.map({
                    Shader(title: $0.deletingPathExtension.lastPathComponent,
                           relativePath: $0)
                })
                if source == .default, includeOriginal {
                    shaders.insert(ShaderManager.genOriginalShader(), at: 0)
                }
                result[source] = shaders.count > 0 ? [("", shaders)] : []
                
            case .retroarch, .imported:
                var subResult = [String: [Shader]]()
                for path in shadersRelativePathes {
                    let sectionTitleIndex = source == .retroarch ? 2 : 1
                    let components = path.pathComponents
                    if components.count > sectionTitleIndex + 1 {
                        let sectionTitle = components[sectionTitleIndex]
                        let shader = Shader(title: path.deletingPathExtension.lastPathComponent,
                                            relativePath: path)
                        if var shaderArray = subResult[sectionTitle] {
                            shaderArray.append(shader)
                            subResult[sectionTitle] = shaderArray.sorted(by: {
                                $0.title.lowercased() < $1.title.lowercased()
                            })
                        } else {
                            subResult[sectionTitle] = [shader]
                        }
                    }
                }
                result[source] = subResult.sorted(by: \.key).map({ ($0, $1) })
            }
        }
        return result
    }
    
    private static func findShaderFiles(in directory: URL, isGlsl: Bool, isRecursive: Bool) -> [String] {
        var result: [String] = []
        let fileManager = FileManager.default
        let pathExtension = isGlsl ? "glslp" : "slangp"
        if isRecursive {
            let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension.lowercased() == pathExtension && fileURL.lastPathComponent.deletingPathExtension.lowercased() != "retroarch",
                    let relativePath = getRelativePath(fileURL.path) {
                    result.append(relativePath)
                }
            }
        } else {
            if let fileUrls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) {
                for fileUrl in fileUrls {
                    let isDirectory = (try? fileUrl.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if !isDirectory,
                       fileUrl.pathExtension.lowercased() == pathExtension,
                       fileUrl.lastPathComponent.deletingPathExtension.lowercased() != "retroarch",
                       let relativePath = getRelativePath(fileUrl.path) {
                        result.append(relativePath)
                    }
                }
            }
        }
        return result.sorted(by: { $0 < $1 })
    }
    
    private static func getRelativePath(_ path: String) -> String? {
        if let range = path.range(of: "/Libretro/shaders/") {
            return String(path[range.upperBound...])
        }
        return nil
    }
    
    static func genOriginalShader() -> Shader {
        return Shader(title: R.string.localizable.filterOriginTitle(), relativePath: "")
    }
    
}
