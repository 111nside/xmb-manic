//
//  BonjourKit.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/2/9.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

import Foundation

/// 作为服务端发布一个服务，这个服务可以让客户端获取到当前设备的IP地址和端口
/// 作为客户端查找服务时，获取服务端的IP地址和端口
final class BonjourKit: NSObject {
    static let shared = BonjourKit()
    
    /// 服务类型
    private let serviceType = "_manicemu._tcp."
    private let serviceDomain = "local."
    
    /// 获取当前设备的IP地址（线程安全，懒加载缓存）
    var currentIPAddress: String? {
        return Self.fetchCurrentIPAddress()
    }
    
    // MARK: - 作为服务端发布服务
    private var publishedService: NetService?
    private var isPublishing = false
    
    /// 在局域网中发布服务
    /// - Parameter port: 服务端口
    func publishService(port: Int32, delay: Double = 0.0) {
        let port = port == 0 ? Int32.random(in: 1000...65000) : port
        // 确保在主线程操作
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.publishService(port: port)
            }
            return
        }
        
        // 停止已有服务
        stopService()
        
        // 创建并发布新服务
        let service = NetService(
            domain: serviceDomain,
            type: serviceType,
            name: UIDevice.current.name,
            port: port
        )
        service.delegate = self
        DispatchQueue.main.asyncAfter(delay: delay) {
            service.publish()
        }
        
        publishedService = service
        isPublishing = true
        Log.debug("[BonjourKit] 开始发布服务")
    }
    
    /// 停止发布服务
    func stopService() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.stopService()
            }
            return
        }
        
        publishedService?.stop()
        publishedService?.delegate = nil
        publishedService = nil
        isPublishing = false
        Log.debug("[BonjourKit] 停止发布服务")
    }
    
    // MARK: - 作为客户端搜索服务
    private var serviceBrowser: NetServiceBrowser?
    /// 使用服务唯一标识（domain + type + name）作为 key 存储服务对象
    private var discoveredServices: [String: NetService] = [:]
    /// 使用服务唯一标识作为 key 存储解析后的地址
    private var serviceAddresses: [String: [String]] = [:]
    
    /// 服务搜索结果 返回服务端IP列表 如["192.168.1.1:1234"]
    var didSearchServiceList: (([String]) -> Void)?
    
    /// 开始搜索服务，除非调用停止搜索服务，否则不设超时时间
    func startSearchService() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.startSearchService()
            }
            return
        }
        
        // 停止已有搜索
        stopSearchService()
        
        // 清空之前的数据
        discoveredServices.removeAll()
        serviceAddresses.removeAll()
        
        // 创建并启动浏览器
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: serviceType, inDomain: serviceDomain)
        
        serviceBrowser = browser
        Log.debug("[BonjourKit] 开始搜索服务")
    }
    
    /// 停止搜索服务
    func stopSearchService() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.stopSearchService()
            }
            return
        }
        
        serviceBrowser?.stop()
        serviceBrowser?.delegate = nil
        serviceBrowser = nil
        
        // 停止所有正在解析的服务
        for (_, service) in discoveredServices {
            service.stop()
            service.delegate = nil
        }
        discoveredServices.removeAll()
        serviceAddresses.removeAll()
        Log.debug("[BonjourKit] 停止搜索服务")
    }
    
    /// 生成服务的唯一标识
    private func serviceKey(for service: NetService) -> String {
        return "\(service.domain).\(service.type).\(service.name)"
    }
    
    // MARK: - Private Methods
    
    /// 获取当前设备的IP地址
    private static func fetchCurrentIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        
        defer {
            freeifaddrs(ifaddr)
        }
        
        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            // 只处理 IPv4 地址
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                // en0 是 WiFi，pdp_ip0 是蜂窝网络
                if name == "en0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    if result == 0 {
                        address = String(cString: hostname)
                        // 优先使用 WiFi 地址
                        if name == "en0" {
                            break
                        }
                    }
                }
            }
            
            guard let next = interface.ifa_next else {
                break
            }
            ptr = next
        }
        
        return address
    }
    
    /// 从 NetService 解析 IP 地址和端口
    private func extractAddresses(from service: NetService) -> [String] {
        guard let addresses = service.addresses else { return [] }
        
        var results: [String] = []
        let port = service.port
        
        for addressData in addresses {
            addressData.withUnsafeBytes { rawBufferPointer in
                guard let baseAddress = rawBufferPointer.baseAddress else { return }
                let sockaddrPtr = baseAddress.assumingMemoryBound(to: sockaddr.self)
                
                // 只处理 IPv4
                if sockaddrPtr.pointee.sa_family == sa_family_t(AF_INET) {
                    let sockaddrInPtr = baseAddress.assumingMemoryBound(to: sockaddr_in.self)
                    var addr = sockaddrInPtr.pointee.sin_addr
                    var hostname = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    
                    if inet_ntop(AF_INET, &addr, &hostname, socklen_t(INET_ADDRSTRLEN)) != nil {
                        let ipString = String(cString: hostname)
                        // 过滤掉本地回环地址
                        if !ipString.hasPrefix("127.") {
                            let fullAddress = "\(ipString):\(port)"
                            results.append(fullAddress)
                        }
                    }
                }
            }
        }
        
        return results
    }
    
    /// 通知回调（去重后的地址列表）
    private func notifyServiceListUpdate() {
        // 收集所有服务的地址并去重
        var allAddresses: Set<String> = []
        for (_, addresses) in serviceAddresses {
            allAddresses.formUnion(addresses)
        }
        didSearchServiceList?(Array(allAddresses))
    }
    
    // MARK: - Deinit
    
    deinit {
        stopService()
        stopSearchService()
    }
    
    private override init() {
        super.init()
    }
}

// MARK: - NetServiceDelegate

extension BonjourKit: NetServiceDelegate {
    
    func netServiceDidPublish(_ sender: NetService) {
        Log.debug("[BonjourKit] 服务发布成功: \(sender.name) on port \(sender.port)")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        Log.debug("[BonjourKit] 服务发布失败: \(errorDict)")
        isPublishing = false
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        let key = serviceKey(for: sender)
        // 解析完成，提取地址并更新映射
        let addresses = extractAddresses(from: sender)
        serviceAddresses[key] = addresses
        
        // 立即通知回调
        notifyServiceListUpdate()
        
        Log.debug("[BonjourKit] 服务解析成功: \(sender.name), 地址: \(addresses)")
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Log.debug("[BonjourKit] 服务解析失败: \(sender.name), 错误: \(errorDict)")
    }
    
    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        // TXT 记录更新时重新解析服务
        let key = serviceKey(for: sender)
        Log.debug("[BonjourKit] 服务TXT记录更新: \(sender.name), 重新解析")
        
        // 重新解析以获取最新地址
        sender.resolve(withTimeout: 5.0)
        
        // 如果端口变化了，提取新地址
        let addresses = extractAddresses(from: sender)
        if !addresses.isEmpty {
            serviceAddresses[key] = addresses
            notifyServiceListUpdate()
        }
    }
}

// MARK: - NetServiceBrowserDelegate

extension BonjourKit: NetServiceBrowserDelegate {
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let key = serviceKey(for: service)
        
        // 如果是同名服务重新上线，先清理旧的
        if let oldService = discoveredServices[key] {
            oldService.stop()
            oldService.delegate = nil
        }
        
        // 添加到发现列表
        discoveredServices[key] = service
        
        // 设置代理并开始解析
        service.delegate = self
        // 监听 TXT 记录变化
        service.startMonitoring()
        service.resolve(withTimeout: 5.0)
        
        Log.debug("[BonjourKit] 发现服务: \(service.name), 还有更多: \(moreComing)")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let key = serviceKey(for: service)
        
        // 停止监听并从列表中移除
        if let existingService = discoveredServices[key] {
            existingService.stopMonitoring()
            existingService.stop()
            existingService.delegate = nil
            discoveredServices.removeValue(forKey: key)
        }
        
        // 移除对应的地址
        serviceAddresses.removeValue(forKey: key)
        
        // 通知更新
        notifyServiceListUpdate()
        
        Log.debug("[BonjourKit] 服务移除: \(service.name), 还有更多: \(moreComing)")
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Log.debug("[BonjourKit] 搜索已停止")
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Log.debug("[BonjourKit] 搜索失败: \(errorDict)")
    }
}

