//
//  SubscriptionManager.swift
//  SocialStoryCore
//
//  StoreKit 2 subscription manager (买断型), exposed to Objective-C via @objc.
//  PoC 改造：去除 AccountKit 依赖，改用 SSDeviceIdentity 作为账号标识。
//  产品类型由订阅改为买断（Non-Consumable）。
//

import Foundation
import StoreKit

@objc public class SubscriptionManager: NSObject {

    @objc public static let shared = SubscriptionManager()

    /// 买断产品 ID（Non-Consumable）。
    @objc public static let unlockProductID = "com.alitrip.socialstory.unlock"

    // 买断状态的本地缓存 key（设备级，无账号后缀）。
    private let unlockedKey = "ss_is_unlocked"

    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>? = nil

    private override init() {
        super.init()
        listenForTransactions()
        // PoC：去除账号变化监听（AccountManager.didChangeNotificationName）。
    }

    // MARK: - Unlock status

    /// 本地缓存的买断标志（同步读取，用于 UI 判断）。
    @objc public var isUnlocked: Bool {
        UserDefaults.standard.bool(forKey: unlockedKey)
    }

    /// 兼容旧调用方：isSubscribed == isUnlocked。
    @objc public var isSubscribed: Bool { isUnlocked }

    @objc public func refreshSubscriptionStatus(completion: ((Bool) -> Void)? = nil) {
        Task {
            let active = await self.currentlyEntitled()
            UserDefaults.standard.set(active, forKey: self.unlockedKey)
            await MainActor.run { completion?(active) }
        }
    }

    private func currentlyEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // 买断型产品无 expirationDate，只需确认未撤销。
                if transaction.revocationDate == nil {
                    return true
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

    /// 加载买断产品；completion 在主线程回调。
    @objc public func loadProducts(completion: @escaping ([SSProductInfo]) -> Void) {
        Task {
            do {
                let ids = [SubscriptionManager.unlockProductID]
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

    /// 购买买断产品。completion(success, errorMessage) 在主线程回调。
    @objc public func purchase(productID: String,
                               completion: @escaping (Bool, String?) -> Void) {
        Task {
            guard let product = self.products[productID] else {
                await MainActor.run { completion(false, "产品未加载，请稍后重试") }
                return
            }
            do {
                // 用设备 ID 作为 appAccountToken，便于服务端对账。
                var options: Set<Product.PurchaseOption> = []
                if let uuid = UUID(uuidString: SSDeviceIdentity.appAccountToken) {
                    options.insert(.appAccountToken(uuid))
                }
                let result = try await product.purchase(options: options)
                switch result {
                case .success(let verification):
                    if case .verified(let transaction) = verification {
                        await transaction.finish()
                        UserDefaults.standard.set(true, forKey: self.unlockedKey)
                        self.verifyWithServer(transactionID: String(transaction.id))
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
                UserDefaults.standard.set(active, forKey: self.unlockedKey)
                // 恢复购买时也同步服务端
                if active {
                    for await result in Transaction.currentEntitlements {
                        if case .verified(let tx) = result {
                            self.verifyWithServer(transactionID: String(tx.id))
                            break
                        }
                    }
                }
                await MainActor.run { completion(active, active ? nil : "未找到可恢复的购买") }
            } catch {
                await MainActor.run { completion(false, error.localizedDescription) }
            }
        }
    }

    // MARK: - Story generation gate

    /// PoC：已买断返回 true，否则返回 false。
    /// TODO: PoC 期间如需全部放开，改为直接 return true。
    @objc public var canGenerateStory: Bool {
        return isUnlocked
    }

    // MARK: - Server verification

    /// 买断成功后异步通知服务端，写入 subscriptions 表。
    /// 失败不影响本地解锁状态——下次启动时 restorePurchases 会再次触发。
    nonisolated private func verifyWithServer(transactionID: String) {
        let baseURL = localBaseURL()
        guard let url = URL(string: baseURL + "/v1/purchase/verify") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SSDeviceIdentity.deviceID, forHTTPHeaderField: "X-Device-Id")
        req.timeoutInterval = 15
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["transaction_id": transactionID])

        URLSession.shared.dataTask(with: req) { _, resp, err in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if let err = err {
                print("[SubscriptionManager] 服务端验证失败: \(err.localizedDescription)")
            } else {
                print("[SubscriptionManager] 服务端验证完成, status=\(status)")
            }
        }.resume()
    }

    nonisolated private func localBaseURL() -> String {
        guard let path = Bundle.main.path(forResource: "LocalConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let url = dict["AccountBaseURL"] as? String,
              !url.isEmpty else {
            return "http://localhost:8080"
        }
        return url
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
