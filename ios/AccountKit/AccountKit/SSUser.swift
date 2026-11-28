//
//  SSUser.swift
//  AccountKit
//
//  Plain account model. `appAccountToken` is a stable per-account UUID that is
//  passed to StoreKit purchases so subscriptions can later be reconciled to this
//  account server-side (App Store Server Notifications).
//

import Foundation

@objc public final class SSUser: NSObject {
    @objc public let userID: String
    @objc public let phone: String
    @objc public var nickname: String
    @objc public var avatarURL: String?
    /// Stable UUID string used as StoreKit appAccountToken.
    @objc public let appAccountToken: String

    @objc public init(userID: String,
                      phone: String,
                      nickname: String,
                      avatarURL: String?,
                      appAccountToken: String) {
        self.userID = userID
        self.phone = phone
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.appAccountToken = appAccountToken
        super.init()
    }
}
