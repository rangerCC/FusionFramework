//
//  SubscriptionManager.swift
//  SocialStoryCore
//
//  StoreKit 2 subscription manager, exposed to Objective-C via @objc.
//

import Foundation
import StoreKit
import AccountKit

@objc public class SubscriptionManager: NSObject {

    @objc public static let shared = SubscriptionManager()

    @objc public static let monthlyProductID = "com.alitrip.socialstory.monthly"
    @objc public static let yearlyProductID  = "com.alitrip.socialstory.yearly"

    @objc public static let monthlyFreeQuota = 3

    private let subscribedKey = "ss_is_subscribed"
    private let usedCountKey  = "ss_free_used_count"
    private let usedMonthKey  = "ss_free_used_month"

    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>? = nil

    private override init() {
        super.init()
        // Cache the last known status synchronously for isSubscribed.
        listenForTransactions()
        // Re-check entitlements when the account changes (login / logout).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountDidChange),
            name: Notification.Name(AccountManager.didChangeNotificationName),
            object: nil)
    }

    @objc private func accountDidChange() {
        refreshSubscriptionStatus(completion: nil)
    }

    // MARK: - Free-quota storage keys (namespaced per account)

    /// Free quota is tracked per logged-in account so switching accounts (or a
    /// fresh install + login) doesn't inherit another account's used count.
    /// Logged-out users fall back to a device-local bucket.
    private var accountSuffix: String {
        if let user = AccountManager.shared.currentUser { return "_" + user.userID }
        return "_device"
    }
    private var scopedUsedCountKey: String { usedCountKey + accountSuffix }
    private var scopedUsedMonthKey: String { usedMonthKey + accountSuffix }

    // MARK: - Subscription status

    /// Cached subscription flag (synchronous, for gating UI).
    @objc public var isSubscribed: Bool {
        UserDefaults.standard.bool(forKey: subscribedKey)
    }

    @objc public func refreshSubscriptionStatus(completion: ((Bool) -> Void)? = nil) {
        Task {
            let active = await self.currentlyEntitled()
            UserDefaults.standard.set(active, forKey: self.subscribedKey)
            await MainActor.run { completion?(active) }
        }
    }

    private func currentlyEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    if let exp = transaction.expirationDate {
                        if exp > Date() { return true }
                    } else {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func listenForTransactions() {
        updatesTask = Task.detached { [weak self] in
            guard let self = self else { return }
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    self.refreshSubscriptionStatus(completion: nil)
                }
            }
        }
    }

    // MARK: - Products

    /// Loads products; completion returns localized display info on the main thread.
    @objc public func loadProducts(completion: @escaping ([SSProductInfo]) -> Void) {
        Task {
            do {
                let ids = [SubscriptionManager.monthlyProductID, SubscriptionManager.yearlyProductID]
                let loaded = try await Product.products(for: ids)
                var infos: [SSProductInfo] = []
                for p in loaded {
                    self.products[p.id] = p
                    let info = SSProductInfo(identifier: p.id,
                                             displayName: p.displayName,
                                             displayPrice: p.displayPrice)
                    infos.append(info)
                }
                let result = infos
                await MainActor.run { completion(result) }
            } catch {
                await MainActor.run { completion([]) }
            }
        }
    }

    /// Purchase a product. completion(success, errorMessage) on the main thread.
    @objc public func purchase(productID: String,
                               completion: @escaping (Bool, String?) -> Void) {
        Task {
            guard let product = self.products[productID] else {
                await MainActor.run { completion(false, "产品未加载，请稍后重试") }
                return
            }
            do {
                // Attach the account token so this purchase can be reconciled to
                // the current account server-side (App Store Server Notifications).
                var options: Set<Product.PurchaseOption> = []
                if let uuid = UUID(uuidString: AccountManager.shared.appAccountToken) {
                    options.insert(.appAccountToken(uuid))
                }
                let result = try await product.purchase(options: options)
                switch result {
                case .success(let verification):
                    if case .verified(let transaction) = verification {
                        await transaction.finish()
                        UserDefaults.standard.set(true, forKey: self.subscribedKey)
                        await MainActor.run { completion(true, nil) }
                    } else {
                        await MainActor.run { completion(false, "交易验证失败") }
                    }
                case .userCancelled:
                    await MainActor.run { completion(false, nil) }
                case .pending:
                    await MainActor.run { completion(false, "购买待处理") }
                @unknown default:
                    await MainActor.run { completion(false, "未知错误") }
                }
            } catch {
                await MainActor.run { completion(false, error.localizedDescription) }
            }
        }
    }

    @objc public func restorePurchases(completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                try await AppStore.sync()
                let active = await self.currentlyEntitled()
                UserDefaults.standard.set(active, forKey: self.subscribedKey)
                await MainActor.run { completion(active, active ? nil : "未找到可恢复的订阅") }
            } catch {
                await MainActor.run { completion(false, error.localizedDescription) }
            }
        }
    }

    // MARK: - Free quota

    private func resetQuotaIfNeeded() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        let month = fmt.string(from: Date())
        let stored = UserDefaults.standard.string(forKey: scopedUsedMonthKey)
        if stored != month {
            UserDefaults.standard.set(month, forKey: scopedUsedMonthKey)
            UserDefaults.standard.set(0, forKey: scopedUsedCountKey)
        }
    }

    @objc public var remainingFreeCount: Int {
        resetQuotaIfNeeded()
        let used = UserDefaults.standard.integer(forKey: scopedUsedCountKey)
        return max(0, SubscriptionManager.monthlyFreeQuota - used)
    }

    @objc public var canGenerateStory: Bool {
        if isSubscribed { return true }
        return remainingFreeCount > 0
    }

    @objc public func consumeFreeQuota() {
        if isSubscribed { return }
        resetQuotaIfNeeded()
        let used = UserDefaults.standard.integer(forKey: scopedUsedCountKey)
        UserDefaults.standard.set(used + 1, forKey: scopedUsedCountKey)
    }
}

/// Plain product info passed back to Objective-C.
@objc public class SSProductInfo: NSObject {
    @objc public let identifier: String
    @objc public let displayName: String
    @objc public let displayPrice: String

    @objc public init(identifier: String, displayName: String, displayPrice: String) {
        self.identifier = identifier
        self.displayName = displayName
        self.displayPrice = displayPrice
        super.init()
    }
}
