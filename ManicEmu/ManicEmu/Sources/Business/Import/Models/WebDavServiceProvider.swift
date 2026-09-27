//
//  WebDavServiceProvider.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/2/27.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import CloudServiceKit
import WebDavKit

class WebDavServiceProvider: CloudServiceProvider {
    var refreshAccessTokenHandler: CloudServiceKit.CloudRefreshAccessTokenHandler?
    
    var delegate: (any CloudServiceKit.CloudServiceProviderDelegate)?
    
    var name: String { "WebDAV" }
    
    var credential: URLCredential?
    
    private let serviceID: Int
    
    private var webDavClient: WebDAV? = nil
    
    var rootItem: CloudServiceKit.CloudItem {
        CloudItem(id: name,
                  name: name,
                  path: "/",
                  isDirectory: true)
    }
    
    required init(credential: URLCredential?) {
        fatalError("不用这个初始化方法")
    }
    
    init(service: ImportService) {
        self.serviceID = service.id
        if let host = service.host, let scheme = service.scheme {
            webDavClient = WebDAV(baseURL: scheme + "://" + host, port: service.port ?? (scheme == "http" ? 80 : 443), username: service.user, password: service.password, path: service.path)
        }
    }
    
    func attributesOfItem(_ item: CloudServiceKit.CloudItem, completion: @escaping (Result<CloudServiceKit.CloudItem, any Error>) -> Void) {
        
    }
    
    func contentsOfDirectory(_ directory: CloudServiceKit.CloudItem, completion: @escaping (Result<[CloudServiceKit.CloudItem], any Error>) -> Void) {
        //检查客户端
        guard let webDavClient = webDavClient else {
            completion(.failure(ImportError.lanServiceInitFailed(serviceName: name)))
            return
        }
        Task {
            do {
                let files = try await webDavClient.listFiles(atPath: directory.path)
                await MainActor.run {
                    var results: [CloudItem] = []
                    for file in files {
                        if !file.fileName.hasPrefix(".")  {
                            let item = CloudItem(id: file.url.absoluteString, name: file.fileName, path: file.path, isDirectory: file.isDirectory)
                            item.creationDate = file.lastModified
                            item.modificationDate = file.lastModified
                            item.size = file.size
                            results.append(item)
                        }
                    }
                    completion(.success(results))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func downloadableRequest(of item: CloudItem) -> URLRequest? {
        if item.isDirectory {
            return nil
        }
        return webDavClient?.authorizedRequest(path: item.path, method: .get)
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
