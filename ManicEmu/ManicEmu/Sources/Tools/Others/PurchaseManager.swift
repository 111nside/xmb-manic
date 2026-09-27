//
//  PurchaseManager.swift
//  ManicEmu
//
//  Created by Aoshuang Lee on 2023/6/9.
//  Copyright © 2023 Aoshuang Lee. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import StoreKit
import WidgetKit
import SmartCodable
#if !SIDE_LOAD && !DEBUG
import KeychainAccess
#endif

enum PurchaseProductType: String, CaseIterable {
    case annual = "com.aoshuang.AnnualPlan"
    case monthly = "com.aoshuang.MonthlyPlan"
    case forever = "com.aoshuang.ForeverAccess"
}

struct PurchaseManager {
    
#if SIDE_LOAD || DEBUG
    static var isMember: Bool = true
#else
    private(set) static var isMember: Bool = {
        let keychain = Keychain(service: R.Config.AppIdentifier)
        if let isMemberString = keychain[R.Strings.MemberKeyChainKey], !isMemberString.isEmpty {
            return true
        }
        return false
    }() {
        didSet {
            //无变化不操作
            guard oldValue != isMember else { return }
            let userDefaults = UserDefaults(suiteName: R.DefaultKey.AppGroupName)
            userDefaults?.set(isMember, forKey: R.DefaultKey.AppGroupIsPremiumKey)
            userDefaults?.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
            //变更Keychain
            let keychain = Keychain(service: R.Config.AppIdentifier)
            keychain[R.Strings.MemberKeyChainKey] = isMember ? R.Strings.MemberKeyChainKey : ""
            NotificationCenter.default.post(name: R.NotificationName.MembershipChange, object: nil)
            if !isMember && Settings.defalut.iCloudSyncEnable {
                Settings.defalut.iCloudSyncEnable = false
            }
        }
    }
#endif
    
    
    
    private(set) static var isAnnualMember: Bool = false
    
    private(set) static var isMonthlyMember: Bool = false
    
    
#if SIDE_LOAD || DEBUG
    private(set) static var isForeverMember: Bool = true
#else
    private(set) static var isForeverMember: Bool = false
#endif
    
    private(set) static var maxFreeTrialDay: Int?
    
    private(set) static var hasFreeTrial: Bool = false
    
    private static var products: [Product]? = nil
    
    private static var lastFetchDate = Date()
    
    static func getProducts(completion: (([Product])->Void)? = nil) {
        if let products = products, products.count > 0, Date().minutesSince(lastFetchDate) <= 30 { //超过30分钟刷新一次
            DispatchQueue.main.asyncAfter(delay: 0.35) {
                completion?(products)
            }
            return
        }
        Task {
            do {
                Log.info("开始获取商品")
                let ids = PurchaseProductType.allCases.map { $0.rawValue }
                var products = try await Product.products(for: ids)
                products = products.sorted {
                    if let firstIndex = ids.firstIndex(of: $0.id), let secondIndex = ids.firstIndex(of: $1.id) , firstIndex < secondIndex {
                        return true
                    }
                    return false
                }
                Log.info("获取商品成功:\(products.map({ $0.id }))")
                PurchaseManager.products = products
                lastFetchDate = Date()
                for product in products {
                    let statuses = try await product.subscription?.status
                    for status in statuses ?? [] {
                        if status.state == .subscribed || status.state == .expired {
                            // 用户已经订阅或使用过订阅
                            maxFreeTrialDay = nil
                            hasFreeTrial = false
                            break
                        }
                    }
                    
                    if let day = product.freeTrialDay {
                        maxFreeTrialDay = day
                        hasFreeTrial = true
                        break
                    }
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: R.NotificationName.ProductsUpdate, object: nil)
                    completion?(products)
                }
            } catch {
                Log.info("获取内购商品失败：\(error)")
                DispatchQueue.main.async {
                    completion?([])
                }
            }
        }
    }
    
    static func purchase(product: Product, completion: ((_ message: String?)->Void)? = nil) {
        Task {
            do {
                Log.info("开始购买:\(product.id)")
                let result = try await product.purchase()
                switch result {
                case .success(let verification)://支付成功
                    Log.info("购买:\(product.id)成功，开始校验...")
                    //校验支付凭证
                    switch verification {
                    case .unverified(_, let verificationError):
                        //校验失败
                        Log.info("校验:\(product.id)失败 \(verificationError)")
                        await MainActor.run {
                            completion?(R.string.localizable.purchaseVerifiedFailed())
                        }
                    case .verified(let signedType):
                        //校验成功
                        Log.info("校验:\(product.id)成功!")
                        await handlePurchaseSuccess(transaction: signedType)
                        Log.info("购买:\(product.id)成功!")
                        Log.info("开始上报购买信息:\(product.id)")
                        if let productType = PurchaseProductType(rawValue: product.id) {
                            switch productType {
                            case .annual:
                                PurchaseManager.isAnnualMember = true
                            case .monthly:
                                PurchaseManager.isMonthlyMember = true
                            case .forever:
                                PurchaseManager.isForeverMember = true
                            }
                        }
                        await MainActor.run {
                            completion?(nil)
                        }
                    }
                case .userCancelled:
                    //支付取消
                    await MainActor.run {
                        completion?(R.string.localizable.purchaseCancel())
                    }
                case .pending:
                    //支付挂起
                    await MainActor.run {
                        completion?(R.string.localizable.purchasePending())
                    }
                default:
                    await MainActor.run {
                        completion?(R.string.localizable.purchaseUnknown())
                    }
                }
            } catch {
                await MainActor.run {
                    completion?(R.string.localizable.purchaseErrorDesc())
                }
            }
        }
    }
    
    static func restore(completion: ((Bool)->Void)? = nil) {
        Task {
            Log.info("开始恢复商品")
            do {
                try await AppStore.sync()
                await refreshPurchase()
                await MainActor.run {
                    if PurchaseManager.isMember {
                        completion?(true)
                    } else {
                        completion?(false)
                    }
                }
            } catch {
                await MainActor.run {
                    Log.error("恢复失败 AppStore.sync:\(error)")
                    completion?(false)
                }
            }
        }
    }
    
    @available(iOS 16.0, *)
    static func redeemOfferCode(completion: ((_ isCompleted: Bool, _ isMember: Bool)->Void)? = nil) {
        if let scene = ApplicationSceneDelegate.applicationScene {
            Task {
                do {
                    try await AppStore.presentOfferCodeRedeemSheet(in: scene)
                    await refreshPurchase()
                    await MainActor.run {
                        if PurchaseManager.isMember {
                            completion?(true, true)
                        } else {
                            completion?(true, false)
                        }
                    }
                } catch {
                    await MainActor.run {
                        completion?(false, PurchaseManager.isMember)
                        Log.error("兑换优惠代码失败:\(error)")
                    }
                }
            }
        }
    }
    
    private static func handlePurchaseSuccess(transaction: Transaction) async {
        await transaction.finish()
        if PurchaseManager.isMember {
            return
        }
        PurchaseManager.isMember = true
        NotificationCenter.default.post(name: R.NotificationName.PurchaseSuccess, object: nil)
    }
    
    static func setup() {
#if !SIDE_LOAD
        Log.info("初始化内购")
        //获取商品
        getProducts(completion: nil)
        //检查内购
        Task {
            await refreshPurchase()
            for await verificationResult in Transaction.updates {
                guard case .verified(let transaction) = verificationResult else { return }
                Log.info("内购有更新!!")
                await refreshPurchase(transaction: transaction)
                await transaction.finish()
            }
            //阻塞 下面就不会执行了
        }
#endif
    }
    
    static func refreshPurchase(transaction: Transaction? = nil) async {
#if SIDE_LOAD || DEBUG
        return
#endif
        //遍历当前有效的内购项目
        Log.info("开始刷新内购")
        var isMember = false
        
        func handleTransaction(innerTransaction: Transaction) async {
            //验证通过的项目
            if let productType = PurchaseProductType(rawValue: innerTransaction.productID) {
                switch productType {
                case .annual:
                    //年度会员
                    if let expirationDate = innerTransaction.expirationDate, expirationDate >= Date.now {
                        Log.info("年度会员内购合法")
                        isMember = true
                        PurchaseManager.isAnnualMember = true
                        await PurchaseManager.handlePurchaseSuccess(transaction: innerTransaction)
                    } else {
                        let tran = innerTransaction
                        Log.debug("\n过期时间判断失败 当前时间:\(Date.now.dateTimeString()) 校验成功的收据id:\(tran.productID) purchaseDate:\(tran.purchaseDate.dateTimeString()) originalPurchaseDate:\(tran.originalPurchaseDate.dateTimeString()) expirationDate:\(tran.expirationDate?.dateTimeString() ?? "无") revocationDate:\(tran.revocationDate?.dateTimeString() ?? "无")")
                    }
                case .monthly:
                    //月度会员
                    if let expirationDate = innerTransaction.expirationDate, expirationDate >= Date.now {
                        Log.info("月度会员内购合法")
                        isMember = true
                        PurchaseManager.isMonthlyMember = true
                        await PurchaseManager.handlePurchaseSuccess(transaction: innerTransaction)
                    } else {
                        let tran = innerTransaction
                        Log.debug("\n过期时间判断失败 当前时间:\(Date.now.dateTimeString()) 校验成功的收据id:\(tran.productID) purchaseDate:\(tran.purchaseDate.dateTimeString()) originalPurchaseDate:\(tran.originalPurchaseDate.dateTimeString()) expirationDate:\(tran.expirationDate?.dateTimeString() ?? "无") revocationDate:\(tran.revocationDate?.dateTimeString() ?? "无")")
                    }
                case .forever:
                    //永久会员
                    Log.info("永久会员合法")
                    isMember = true
                    PurchaseManager.isForeverMember = true
                    await PurchaseManager.handlePurchaseSuccess(transaction: innerTransaction)
                }
            } else {
                //内购不合法异常
                Log.info("内购不合法:\(innerTransaction.productID)")
            }
        }
        
        if let transaction = transaction {
            await handleTransaction(innerTransaction: transaction)
        } else {
            for await trans in Transaction.all {
                switch trans {
                case .unverified(let tran, let error):
                    Log.debug("\n所有订单 校验失败的收据id:\(tran.productID) error:\(error)")
                case .verified(let tran):
                    Log.debug("\n所有订单 校验成功的收据id:\(tran.productID) purchaseDate:\(tran.purchaseDate.dateTimeString()) originalPurchaseDate:\(tran.originalPurchaseDate.dateTimeString()) expirationDate:\(tran.expirationDate?.dateTimeString() ?? "无") revocationDate:\(tran.revocationDate?.dateTimeString() ?? "无")")
                }
            }
            
            for await verificationResult in Transaction.currentEntitlements {
                switch verificationResult {
                case .unverified(let tran, let error):
                    Log.debug("\n活跃订单 校验失败的收据id:\(tran.productID) error:\(error)")
                case .verified(let tran):
                    await handleTransaction(innerTransaction: tran)
                    Log.debug("\n活跃订单 校验成功的收据id:\(tran.productID) purchaseDate:\(tran.purchaseDate.dateTimeString()) originalPurchaseDate:\(tran.originalPurchaseDate.dateTimeString()) expirationDate:\(tran.expirationDate?.dateTimeString() ?? "无") revocationDate:\(tran.revocationDate?.dateTimeString() ?? "无")")
                }
            }
        }
        
        PurchaseManager.isMember = isMember
    }

}
