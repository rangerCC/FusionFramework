//
//  AccountManager.swift
//  AccountKit
//
//  Singleton facade for account state. Persists the logged-in user to Keychain
//  so login survives app restarts. UI observes SSAccountDidChangeNotification.
//
//  Backend swap: assign a different SSAccountService to `service` at launch.
//  Everything above this class is implementation-agnostic.
//

import Foundation

@objc public final class AccountManager: NSObject {

    @objc public static let shared = AccountManager()

    /// Notification name string. Posted on login, logout, and profile updates.
    /// ObjC observers use this via NSNotificationCenter.
    @objc public static let didChangeNotificationName = "SSAccountDidChangeNotification"

    /// Swift-typed name for internal posting.
    private static var didChangeNotification: Notification.Name {
        Notification.Name(didChangeNotificationName)
    }

    /// The active account service. Defaults to the local mock; replace at launch
    /// with a remote implementation once the backend exists.
    @objc public var service: SSAccountService = SSMockAccountService()

    // Keychain keys.
    private let kUserID = "account.userID"
    private let kPhone = "account.phone"
    private let kNickname = "account.nickname"
    private let kAvatar = "account.avatarURL"
    private let kAppAccountToken = "account.appAccountToken"
    // Device-level fallback token (for purchases made while logged out).
    private let kDeviceToken = "account.deviceAppAccountToken"

    @objc public private(set) var currentUser: SSUser?

    private override init() {
        super.init()
        currentUser = loadUser()
    }

    // MARK: - State

    @objc public var isLoggedIn: Bool { currentUser != nil }

    /// Token to attach to StoreKit purchases. Returns the logged-in user's token,
    /// or a stable device-level token when logged out, so a purchase made before
    /// login can still be reconciled later.
    @objc public var appAccountToken: String {
        if let user = currentUser { return user.appAccountToken }
        if let existing = SSKeychain.string(forKey: kDeviceToken) { return existing }
        let token = UUID().uuidString
        SSKeychain.set(token, forKey: kDeviceToken)
        return token
    }

    // MARK: - Auth flow (delegates to service)

    @objc public func requestSMSCode(phone: String,
                                     completion: @escaping (Bool, String?) -> Void) {
        service.requestSMSCode(phone: phone, completion: completion)
    }

    @objc public func login(phone: String,
                            code: String,
                            completion: @escaping (Bool, String?) -> Void) {
        service.login(phone: phone, code: code) { [weak self] user, error in
            guard let self = self else { return }
            if let user = user {
                self.persist(user)
                self.currentUser = user
                self.postChange()
                completion(true, nil)
            } else {
                completion(false, error ?? "登录失败")
            }
        }
    }

    @objc public func logout() {
        service.logout()
        clearPersisted()
        currentUser = nil
        postChange()
    }

    /// Update mutable profile fields (nickname / avatar) and persist.
    @objc public func updateProfile(nickname: String?, avatarURL: String?) {
        guard let user = currentUser else { return }
        if let nickname = nickname { user.nickname = nickname }
        if let avatarURL = avatarURL { user.avatarURL = avatarURL }
        persist(user)
        postChange()
    }

    // MARK: - Persistence (Keychain)

    private func persist(_ user: SSUser) {
        SSKeychain.set(user.userID, forKey: kUserID)
        SSKeychain.set(user.phone, forKey: kPhone)
        SSKeychain.set(user.nickname, forKey: kNickname)
        SSKeychain.set(user.avatarURL, forKey: kAvatar)
        SSKeychain.set(user.appAccountToken, forKey: kAppAccountToken)
    }

    private func loadUser() -> SSUser? {
        guard let userID = SSKeychain.string(forKey: kUserID),
              let phone = SSKeychain.string(forKey: kPhone),
              let token = SSKeychain.string(forKey: kAppAccountToken) else {
            return nil
        }
        let nickname = SSKeychain.string(forKey: kNickname) ?? phone
        let avatar = SSKeychain.string(forKey: kAvatar)
        return SSUser(userID: userID,
                      phone: phone,
                      nickname: nickname,
                      avatarURL: avatar,
                      appAccountToken: token)
    }

    private func clearPersisted() {
        SSKeychain.delete(forKey: kUserID)
        SSKeychain.delete(forKey: kPhone)
        SSKeychain.delete(forKey: kNickname)
        SSKeychain.delete(forKey: kAvatar)
        SSKeychain.delete(forKey: kAppAccountToken)
        // Keep the device-level token so prior purchases remain reconcilable.
    }

    private func postChange() {
        NotificationCenter.default.post(name: AccountManager.didChangeNotification, object: self)
    }
}
