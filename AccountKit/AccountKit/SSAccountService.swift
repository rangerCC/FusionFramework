//
//  SSAccountService.swift
//  AccountKit
//
//  Backend integration point. Swap SSMockAccountService for a remote
//  implementation (e.g. SSRemoteAccountService) once the server is ready —
//  AccountManager and all UI talk only to this protocol.
//

import Foundation

@objc public protocol SSAccountService: NSObjectProtocol {

    /// Request an SMS verification code for the given phone number.
    /// completion(success, errorMessage) on the main thread.
    @objc func requestSMSCode(phone: String,
                              completion: @escaping (Bool, String?) -> Void)

    /// Verify phone + code and return the logged-in user.
    /// completion(user, errorMessage) on the main thread; user is nil on failure.
    @objc func login(phone: String,
                     code: String,
                     completion: @escaping (SSUser?, String?) -> Void)

    /// Invalidate the server session, if any. Local state is cleared by AccountManager.
    @objc func logout()
}
