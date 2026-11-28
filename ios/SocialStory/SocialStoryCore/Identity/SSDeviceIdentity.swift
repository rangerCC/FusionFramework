//
//  SSDeviceIdentity.swift
//  SocialStoryCore
//
//  稳定的设备级身份：生成一次，永久存 UserDefaults。
//  替代 AccountKit/AccountManager，PoC 阶段不需要登录。
//
//  注意：SSKeychain 定义在 AccountKit 模块中，SocialStoryCore 的 PoC 改造
//  去除了对 AccountKit 的依赖，因此使用 UserDefaults 持久化。
//  安全性略低于 Keychain，但对 PoC 阶段足够使用。
//

import Foundation

@objc public final class SSDeviceIdentity: NSObject {

    private static let deviceIDKey = "ss_device_id"

    /// 稳定的设备 UUID，首次调用时生成并持久化到 UserDefaults。
    @objc public static var deviceID: String {
        let key = deviceIDKey
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let id = "ios-" + UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    /// 透传给 StoreKit appAccountToken。与 deviceID 值相同。
    @objc public static var appAccountToken: String { deviceID }
}
