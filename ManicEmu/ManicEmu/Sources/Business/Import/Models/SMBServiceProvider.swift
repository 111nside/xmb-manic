//
//  SMBServiceProvider.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import CloudServiceKit
import SMBClient

private let SMBFileTypeKey = "SMBFileTypeKey"

class SMBServiceProvider: CloudServiceProvider {
    var refreshAccessTokenHandler: CloudServiceKit.CloudRefreshAccessTokenHandler?
    
    var delegate: (any CloudServiceKit.CloudServiceProviderDelegate)?
    
    var name: String { "SMB" }
    
    var credential: URLCredential?
    
    //即使provider销毁 也要保活smbClient 因为smbClient可能在进行下载任务
    var smbClient: SMBClient?
    
    
    
    private enum SMBFileType: String {
        case initial, share, files
    }
    
    private let serviceID: Int
    
    var rootItem: CloudServiceKit.CloudItem {
        CloudItem(id: name,
                  name: name,
                  path: "",
                  isDirectory: false,
                  json: [SMBFileTypeKey: SMBFileType.initial])
    }
    
    required init(credential: URLCredential?) {
        fatalError("不用这个初始化方法")
    }
    
    init(service: ImportService) {
        self.serviceID = service.id
        //初始化smb客户端
        if let host = service.host {
            if let port = service.port {
                smbClient = SMBClient(host: host, port: port)
            } else {
                smbClient = SMBClient(host: host)
            }
            //暂时不支持path
        }
    }
    
    deinit {
        if let smbClient = smbClient {
            Task {
                try await smbClient.logoff()
            }
        }
    }
    
    func attributesOfItem(_ item: CloudServiceKit.CloudItem, completion: @escaping (Result<CloudServiceKit.CloudItem, any Error>) -> Void) {
        
    }
    
    func contentsOfDirectory(_ directory: CloudServiceKit.CloudItem, completion: @escaping (Result<[CloudServiceKit.CloudItem], any Error>) -> Void) {
        //检查客户端
        guard let smbClient = smbClient, let type = directory.json[SMBFileTypeKey] as? SMBFileType else {
            completion(.failure(ImportError.lanServiceInitFailed(serviceName: name)))
            return
        }
        switch type {
        case .initial:
            //首次获取列表
            //尝试登录
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    let realm = Database.realm
                    let service = realm.object(ofType: ImportService.self, forPrimaryKey: self.serviceID)
                    try await smbClient.login(username: service?.user,
                                              password: service?.password)
                    //登录成功则返回share列表
                    do {
                        let shares = try await smbClient.listShares()
                        await MainActor.run {
                            var results: [CloudItem] = []
                            for share in shares {
                                if !share.type.contains(.device) && !share.type.contains(.printQueue) && !share.type.contains(.ipc) {
                                    results.append(CloudItem(id: share.name, name: share.name, path: share.name, json: [SMBFileTypeKey: SMBFileType.share]))
                                }
                            }
                            completion(.success(results))
                        }
                    } catch {
                        await MainActor.run {
                            completion(.failure(ImportError.smbListFilesFailed(reason: "\n" + error.localizedDescription)))
                        }
                    }
                } catch {
                    await MainActor.run {
                        completion(.failure(ImportError.smbLoginFailed(reason: "\n" + error.localizedDescription)))
                    }
                }
            }
        case .share:
            //当前的item是一个share 尝试连接share 并且列出share根目录下的文件
            Task {
                do {
                    try await smbClient.connectShare(directory.path)
                    let files = try await smbClient.listDirectory(path: "")
                    await MainActor.run {
                        completion(.success(filesToItems(currentPath: "", files: files)))
                    }
                } catch {
                    await MainActor.run {
                        completion(.failure(ImportError.smbListFilesFailed(reason: "\n" + error.localizedDescription)))
                    }
                }
            }
        case .files:
            guard directory.isDirectory else {
                completion(.failure(ImportError.smbListFilesFailed(reason: "\n" + R.string.localizable.smbListFilesTypeError())))
                return
            }
            Task {
                do {
                    let files = try await smbClient.listDirectory(path: directory.path)
                    await MainActor.run {
                        completion(.success(filesToItems(currentPath: directory.path, files: files)))
                    }
                } catch {
                    await MainActor.run {
                        completion(.failure(ImportError.smbListFilesFailed(reason: "\n" + error.localizedDescription)))
                    }
                }
            }
        }
    }
    
    func download(paths: [String], completion: ((_ urls: [URL], _ falures: [String])->Void)? = nil) {
        guard !paths.isEmpty else { return }
        //检查客户端
        guard let smbClient = smbClient else {
            completion?([], paths.map { $0.lastPathComponent })
            return
        }
        
        var urls: [URL] = []
        var falures: [String] = []
        let group = DispatchGroup()
        if !FileManager.default.fileExists(atPath: R.Path.SMBWorkSpace) {
            try? FileManager.default.createDirectory(atPath: R.Path.SMBWorkSpace, withIntermediateDirectories: true)
        }
        for path in paths {
            group.enter()
            Task {
                do {
                    let url = URL(fileURLWithPath: R.Path.SMBWorkSpace.appendingPathComponent(path.lastPathComponent))
                    Log.debug("开始下载:\(path.lastPathComponent)")
                    try await smbClient.download(path: path, localPath: url, overwrite: true)
                    urls.append(url)
                    group.leave()
                } catch {
                    falures.append(path.lastPathComponent)
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            completion?(urls, falures)
        }
    }
    
    private func filesToItems(currentPath: String, files: [File]) -> [CloudItem] {
        var results: [CloudItem] = []
        for file in files {
            if !file.name.hasPrefix(".") {
                let item = CloudItem(id: file.name,
                                     name: file.name,
                                     path: currentPath.isEmpty ? file.name : currentPath.appendingPathComponent(file.name),
                                     isDirectory: file.isDirectory,
                                     json: [SMBFileTypeKey: SMBFileType.files])
                item.creationDate = file.creationTime
                item.modificationDate = file.lastWriteTime
                item.size = Int64(file.size)
                results.append(item)
            }
        }
        return results
    }
    
    func copyItem(_ item: CloudServiceKit.CloudItem, to directory: CloudServiceKit.CloudItem, completion: @escaping CloudServiceKit.CloudCompletionHandler) {
        
    }
    
    func createFolder(_ folderName: String, at directory: CloudServiceKit.CloudItem, completion: @escaping CloudServiceKit.CloudCompletionHandler) {
        
    }
    
    func getCloudSpaceInformation(completion: @escaping (Result<CloudServiceKit.CloudSpaceInformation, any Error>) -> Void) {
        
    }
    
    func getCurrentUserInfo(completion: @escaping (Result<CloudServiceKit.CloudUser, any Error>) -> Void) {
        
    }
    
    func moveItem(_ item: CloudServiceKit.CloudItem, to directory: CloudServiceKit.CloudItem, completion: @escaping CloudServiceKit.CloudCompletionHandler) {
        
    }
    
    func removeItem(_ item: CloudServiceKit.CloudItem, completion: @escaping CloudServiceKit.CloudCompletionHandler) {
        
    }
    
    func renameItem(_ item: CloudServiceKit.CloudItem, newName: String, completion: @escaping CloudServiceKit.CloudCompletionHandler) {
        
    }
    
    func searchFiles(keyword: String, completion: @escaping (Result<[CloudServiceKit.CloudItem], any Error>) -> Void) {
        
    }
    
    func uploadData(_ data: Data, filename: String, to directory: CloudServiceKit.CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudServiceKit.CloudCompletionHandler) {
        
    }
    
    func uploadFile(_ fileURL: URL, to directory: CloudServiceKit.CloudItem, progressHandler: @escaping ((Progress) -> Void), completion: @escaping CloudServiceKit.CloudCompletionHandler) {
        
    }
    
    static func cloudItemFromJSON(_ json: [String : Any]) -> CloudServiceKit.CloudItem? {
        return nil
    }
}
