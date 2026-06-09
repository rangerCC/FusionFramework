//
//  SSMockAccountService.swift
//  AccountKit
//
//  Local stand-in for a real backend. Any phone number with code "1234" logs in.
//  Generates a stable userID + appAccountToken per phone so repeated logins on
//  the same device map to the same account.
//

import Foundation

@objc public final class SSMockAccountService: NSObject, SSAccountService {

    /// The fixed code the mock accepts.
    @objc public static let acceptedCode = "1234"

    /// The mock has no real session token.
    @objc public var accessToken: String? { nil }

    private let tokenStorePrefix = "ss_mock_appacct_"

    @objc public func requestSMSCode(phone: String,
                                     completion: @escaping (Bool, String?) -> Void) {
        let ok = Self.isValidPhone(phone)
        // Simulate network latency.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            completion(ok, ok ? nil : "请输入有效的手机号")
        }
    }

    @objc public func login(phone: String,
                            code: String,
                            completion: @escaping (SSUser?, String?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard Self.isValidPhone(phone) else {
                completion(nil, "请输入有效的手机号"); return
            }
            guard code == Self.acceptedCode else {
                completion(nil, "验证码错误（测试请输入 \(Self.acceptedCode)）"); return
            }
            // Deterministic userID from phone; stable appAccountToken persisted per phone.
            let userID = "u_" + phone
            let token = self.stableToken(for: phone)
            let tail = phone.count >= 4 ? String(phone.suffix(4)) : phone
            let user = SSUser(userID: userID,
                              phone: phone,
                              nickname: "家长_" + tail,
                              avatarURL: nil,
                              appAccountToken: token)
            completion(user, nil)
        }
    }

    @objc public func logout() {
        // No server session in the mock.
    }

    // MARK: - Helpers

    private func stableToken(for phone: String) -> String {
        let key = tokenStorePrefix + phone
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: key)
        return token
    }

    private static func isValidPhone(_ phone: String) -> Bool {
        // Simple CN mobile check: 11 digits starting with 1.
        let digits = phone.filter { $0.isNumber }
        return digits.count == 11 && digits.hasPrefix("1")
    }
}
