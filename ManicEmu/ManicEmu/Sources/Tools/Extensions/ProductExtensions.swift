//
//  ProductExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import StoreKit

extension Product {
    var freeTrialDay: Int? {
        guard PurchaseManager.hasFreeTrial else { return nil }
        if self.type == .autoRenewable,
           let subscription = self.subscription,
           let promotion = subscription.introductoryOffer,
           promotion.paymentMode == .freeTrial {
            switch promotion.period.unit {
            case .day:
                return promotion.period.value
            case .week:
                return promotion.period.value * 7
            case .month:
                return promotion.period.value * 30
            case .year:
                return promotion.period.value * 365
            default:
                return nil
            }
        }
        return nil
    }
    
    var freeTrialDesc: String? {
        if let freeTrialDay = freeTrialDay {
            return R.string.localizable.subscriptionPromotional(freeTrialDay)
        }
        return nil
    }
    
    var purchaseDisplayInfo: (title: String, detail: String, enable: Bool) {
        var title = R.string.localizable.buyNowTitle()
        var detail = R.string.localizable.foreverPlanDesc()
        var enable = true
        if let type = PurchaseProductType(rawValue: self.id) {
            switch type {
            case .annual:
                detail = R.string.localizable.trialDesc()
                if PurchaseManager.isForeverMember {
                    title = R.string.localizable.foreverSubscriptionDisableDesc()
                    enable = false
                } else if PurchaseManager.isAnnualMember {
                    title = R.string.localizable.yearSubscriptionDisableDesc()
                    enable = false
                } else if PurchaseManager.isMonthlyMember {
                    title = R.string.localizable.changeSubscription()
                    enable = true
                } else if let freeTrialDay = self.freeTrialDay {
                    title = R.string.localizable.subscriptionPurchaseButtonTitle(freeTrialDay)
                    enable = true
                }
            case .monthly:
                detail = R.string.localizable.trialDesc()
                if PurchaseManager.isForeverMember {
                    title = R.string.localizable.foreverSubscriptionDisableDesc()
                    enable = false
                } else if PurchaseManager.isMonthlyMember {
                    title = R.string.localizable.monthSubscriptionDisableDesc()
                    enable = false
                } else if PurchaseManager.isAnnualMember {
                    title = R.string.localizable.changeSubscription()
                    enable = true
                } else if let freeTrialDay = self.freeTrialDay {
                    title = R.string.localizable.subscriptionPurchaseButtonTitle(freeTrialDay)
                    enable = true
                }
            case .forever:
                if PurchaseManager.isForeverMember {
                    title = R.string.localizable.foreverSubscriptionDisableDesc()
                    enable = false
                } else if PurchaseManager.isAnnualMember || PurchaseManager.isMonthlyMember {
                    title = R.string.localizable.upgradePurchase()
                    enable = true
                }
            }
        }
        return (title, detail, enable)
    }
}
