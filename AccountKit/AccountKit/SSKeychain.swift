//
//  SSKeychain.swift
//  AccountKit
//
//  Minimal Keychain wrapper for storing the session token and user id.
//  Generic-password items, scoped to this app. No external dependencies.
//

import Foundation
import Security

@objc public final class SSKeychain: NSObject {

    private static let service = "com.alitrip.socialstory.account"

    /// Store a string value for `key`. Passing nil deletes the item.
    @objc @discardableResult
    public static func set(_ value: String?, forKey key: String) -> Bool {
        guard let value = value, let data = value.data(using: .utf8) else {
            return delete(forKey: key)
        }
        var query = baseQuery(forKey: key)
        // Upsert: try update first, then add.
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return true
        }
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    @objc public static func string(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @objc @discardableResult
    public static func delete(forKey key: String) -> Bool {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func baseQuery(forKey key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
