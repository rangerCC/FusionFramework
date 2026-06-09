//
//  SSRemoteAccountService.swift
//  AccountKit
//
//  Real backend implementation of SSAccountService, talking to the Go account
//  server (see Doc/api). Drop-in replacement for SSMockAccountService:
//
//      AccountManager.shared.service =
//          SSRemoteAccountService(baseURL: "http://localhost:8080")
//
//  Session tokens (access + refresh) are owned here, not by AccountManager:
//  refresh + device id persist in Keychain so login survives app restarts;
//  the access token is exposed for other authenticated API clients to use.
//

import Foundation

@objc public final class SSRemoteAccountService: NSObject, SSAccountService {

    private let baseURL: URL
    private let session: URLSession

    // Keychain keys (namespaced apart from AccountManager's user keys).
    private let kAccess = "account.accessToken"
    private let kRefresh = "account.refreshToken"
    private let kDeviceID = "account.deviceID"

    /// In-memory access token cache (also mirrored to Keychain on login).
    private var accessTokenCache: String?

    @objc public init(baseURL: String) {
        self.baseURL = URL(string: baseURL)!
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: cfg)
        super.init()
        self.accessTokenCache = SSKeychain.string(forKey: kAccess)
    }

    /// Build a service from the app's local config, falling back to a default.
    ///
    /// Reads `AccountBaseURL` from `LocalConfig.plist` in the main bundle (a
    /// gitignored, per-developer file). If the file or key is absent, uses
    /// `defaultBaseURL` so the app still launches with a sane value.
    @objc public static func fromLocalConfig(defaultBaseURL: String) -> SSRemoteAccountService {
        let url = localConfigString(forKey: "AccountBaseURL") ?? defaultBaseURL
        return SSRemoteAccountService(baseURL: url)
    }

    /// Reads a string value from LocalConfig.plist in the main bundle, if present.
    @objc public static func localConfigString(forKey key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "LocalConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let value = dict[key] as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    /// Current bearer access token, or nil if not logged in. Other API clients
    /// (profile, children, subscription...) read this for the Authorization header.
    @objc public var accessToken: String? {
        accessTokenCache ?? SSKeychain.string(forKey: kAccess)
    }

    /// Stable per-install device id; generated and persisted on first use.
    @objc public var deviceID: String {
        if let existing = SSKeychain.string(forKey: kDeviceID) { return existing }
        let id = "ios-" + UUID().uuidString
        SSKeychain.set(id, forKey: kDeviceID)
        return id
    }

    // MARK: - SSAccountService

    @objc public func requestSMSCode(phone: String,
                                     completion: @escaping (Bool, String?) -> Void) {
        post("/v1/auth/sms/send", body: ["phone": phone, "scene": "login"], auth: false) { _, errMsg in
            completion(errMsg == nil, errMsg)
        }
    }

    @objc public func login(phone: String,
                            code: String,
                            completion: @escaping (SSUser?, String?) -> Void) {
        let body: [String: Any] = ["phone": phone, "code": code, "device_id": deviceID]
        post("/v1/auth/login/sms", body: body, auth: false) { [weak self] data, errMsg in
            guard let self = self else { return }
            if let errMsg = errMsg {
                completion(nil, errMsg)
                return
            }
            guard let data = data,
                  let access = data["access_token"] as? String,
                  let refresh = data["refresh_token"] as? String,
                  let userDict = data["user"] as? [String: Any],
                  let userID = userDict["user_id"] as? String,
                  let token = userDict["app_account_token"] as? String else {
                completion(nil, "登录响应解析失败")
                return
            }
            // Persist tokens (owned by this service).
            self.accessTokenCache = access
            SSKeychain.set(access, forKey: self.kAccess)
            SSKeychain.set(refresh, forKey: self.kRefresh)

            // Build SSUser. Use the raw phone the user entered (response only
            // carries a masked phone) so local display has the full number.
            let nickname = (userDict["nickname"] as? String) ?? ("家长_" + String(phone.suffix(4)))
            let avatar = userDict["avatar_url"] as? String
            let user = SSUser(userID: userID,
                              phone: phone,
                              nickname: nickname,
                              avatarURL: avatar,
                              appAccountToken: token)
            completion(user, nil)
        }
    }

    @objc public func logout() {
        // Best-effort server-side revoke; local clear happens regardless.
        if let refresh = SSKeychain.string(forKey: kRefresh) {
            post("/v1/auth/logout", body: ["refresh_token": refresh], auth: true) { _, _ in }
        }
        accessTokenCache = nil
        SSKeychain.delete(forKey: kAccess)
        SSKeychain.delete(forKey: kRefresh)
    }

    /// Rotate tokens via the refresh endpoint. Call when an authed request 401s.
    @objc public func refreshTokens(completion: @escaping (Bool) -> Void) {
        guard let refresh = SSKeychain.string(forKey: kRefresh) else {
            completion(false)
            return
        }
        let body: [String: Any] = ["refresh_token": refresh, "device_id": deviceID]
        post("/v1/auth/token/refresh", body: body, auth: false) { [weak self] data, errMsg in
            guard let self = self else { return }
            if let data = data, errMsg == nil,
               let access = data["access_token"] as? String,
               let newRefresh = data["refresh_token"] as? String {
                self.accessTokenCache = access
                SSKeychain.set(access, forKey: self.kAccess)
                SSKeychain.set(newRefresh, forKey: self.kRefresh)
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    // MARK: - HTTP (envelope: { code, message, data, request_id })

    /// POST JSON and unwrap the response envelope. completion(data, errorMessage)
    /// is always called on the main thread; errorMessage is nil on success.
    private func post(_ path: String,
                      body: [String: Any],
                      auth: Bool,
                      completion: @escaping ([String: Any]?, String?) -> Void) {
        let done: ([String: Any]?, String?) -> Void = { d, e in
            DispatchQueue.main.async { completion(d, e) }
        }
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios", forHTTPHeaderField: "X-Platform")
        req.setValue(deviceID, forHTTPHeaderField: "X-Device-Id")
        if auth, let tok = accessToken {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            done(nil, "请求构造失败")
            return
        }
        session.dataTask(with: req) { data, _, err in
            if let err = err {
                done(nil, "网络异常：\(err.localizedDescription)")
                return
            }
            guard let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                done(nil, "服务器响应异常")
                return
            }
            let code = (obj["code"] as? Int) ?? -1
            let message = obj["message"] as? String
            if code != 0 {
                done(nil, message ?? "请求失败（\(code)）")
                return
            }
            done(obj["data"] as? [String: Any], nil)
        }.resume()
    }
}
