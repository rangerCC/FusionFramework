# Auth — 认证

公共请求头见 [00-conventions.md](00-conventions.md)。以下接口除标注外**无需** Authorization。

---

## POST /v1/auth/sms/send — 发送验证码

请求：
```json
{ "phone": "13800138000", "scene": "login" }
```
| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| phone | string | 是 | 11 位手机号 |
| scene | string | 是 | `login`（本期仅此） |

响应：
```json
{ "code": 0, "message": "ok",
  "data": { "expires_in": 300, "resend_after": 60 } }
```
- `expires_in`：验证码有效秒数。
- `resend_after`：多少秒后可再次发送（前端做倒计时）。

错误：`2002` 手机号格式、`2005` 发送频繁。

> 开发环境固定码 `1234`（配置开关），与客户端 `SSMockAccountService` 一致，便于联调。

---

## POST /v1/auth/login/sms — 验证码登录/注册

手机号不存在则**自动注册**新账户。

请求：
```json
{ "phone": "13800138000", "code": "1234", "device_id": "DEV-UUID" }
```

响应：
```json
{ "code": 0, "message": "ok",
  "data": {
    "access_token": "eyJhbGciOi...",
    "refresh_token": "rt_AbC123...",
    "expires_in": 7200,
    "is_new_user": false,
    "user": {
      "user_id": "u_01H8XK...",
      "nickname": "家长_8000",
      "avatar_url": null,
      "phone_masked": "138****8000",
      "app_account_token": "550e8400-e29b-41d4-a716-446655440000",
      "bindings": { "phone": true, "wechat": false, "apple": false }
    }
  }
}
```

**客户端映射（`SSUser`，AccountKit）**：
| 响应字段 | SSUser 属性 |
|---|---|
| `user.user_id` | `userID` |
| `user.phone_masked` | `phone`（展示用掩码） |
| `user.nickname` | `nickname` |
| `user.avatar_url` | `avatarURL` |
| `user.app_account_token` | `appAccountToken`（透传给 StoreKit） |

`access_token` / `refresh_token` 由 `SSRemoteAccountService` 自行保存（access 内存 + refresh Keychain）。

错误：`2002`、`2003` 验证码错、`2004` 过期、`2006` 错误次数过多。

---

## POST /v1/auth/login/wechat — 微信登录（预留，本期未实现）

请求：
```json
{ "code": "wx_oauth_code", "device_id": "DEV-UUID" }
```
后端用 code 换 `unionid`：命中 `auth_identities` 则登录该账户，否则建新账户。响应同 `login/sms`。

本期返回 `1004`（未启用）。

---

## POST /v1/auth/token/refresh — 刷新令牌

请求：
```json
{ "refresh_token": "rt_AbC123...", "device_id": "DEV-UUID" }
```

响应：
```json
{ "code": 0, "data": {
    "access_token": "eyJ...(new)",
    "refresh_token": "rt_New456...",
    "expires_in": 7200
  } }
```
- 旧 refresh_token 失效（轮换）。检测到已吊销 token 被重放 → `2008` 并吊销该用户全部令牌。

错误：`2007` 无效/过期、`2008` 重放。

---

## POST /v1/auth/logout — 登出

需 `Authorization`。请求：
```json
{ "refresh_token": "rt_AbC123..." }
```
吊销该 refresh token（及绑定 device 的会话）。

响应：`{ "code": 0, "message": "ok", "data": null }`

---

## 状态码补充

发码与登录均受限流（IP + 手机号双维度），触发返回 `1002` / `2005`，HTTP 429。
