# Account — 账户

所有接口需 `Authorization: Bearer <access_token>`。

---

## GET /v1/account/profile — 获取个人资料

响应：
```json
{ "code": 0, "data": {
    "user_id": "u_01H8XK...",
    "nickname": "家长_8000",
    "avatar_url": "https://oss.../avatar/xxx.jpg",
    "phone_masked": "138****8000",
    "app_account_token": "550e8400-...",
    "bindings": { "phone": true, "wechat": false, "apple": false },
    "created_at": "2026-01-15T03:22:10Z"
  } }
```

---

## PUT /v1/account/profile — 修改资料

请求（部分更新，字段可选）：
```json
{ "nickname": "乐乐妈妈", "avatar_url": "https://oss.../avatar/new.jpg" }
```
| 字段 | 类型 | 说明 |
|---|---|---|
| nickname | string | 1–24 字，过敏感词 |
| avatar_url | string | 已上传到 OSS 的 URL（见下传图流程） |

响应：返回更新后的 profile（同 GET）。

错误：`3005` 昵称不合法。

---

## POST /v1/account/avatar/upload-url — 获取头像直传凭证

客户端直传 OSS，不经后端中转。

响应：
```json
{ "code": 0, "data": {
    "upload_url": "https://bucket.oss-cn-...aliyuncs.com",
    "object_key": "avatar/u_01H8XK/uuid.jpg",
    "form_fields": { "policy": "...", "signature": "...", "OSSAccessKeyId": "...", "key": "avatar/..." },
    "public_url": "https://cdn.../avatar/u_01H8XK/uuid.jpg",
    "expires_in": 600
  } }
```
流程：拿凭证 → 客户端 POST multipart 直传 OSS → 成功后把 `public_url` 作为 `avatar_url` 调 `PUT /account/profile`。

---

## GET /v1/account/bindings — 登录方式列表

响应：
```json
{ "code": 0, "data": {
    "bindings": [
      { "provider": "phone",  "bound": true,  "identifier_masked": "138****8000" },
      { "provider": "wechat", "bound": false, "identifier_masked": null },
      { "provider": "apple",  "bound": false, "identifier_masked": null }
    ]
  } }
```

---

## POST /v1/account/bind/wechat — 绑定微信（预留，本期未实现）

需登录。请求：
```json
{ "code": "wx_oauth_code" }
```
给当前账户追加一条 `auth_identities(provider=wechat)`。

冲突：该 unionid 已绑其他账户 → `3001`。已绑 → `3002`。

本期返回 `1004`。

---

## DELETE /v1/account/bind/{provider} — 解绑（预留）

`provider` ∈ `wechat|apple`。不可解绑唯一登录方式 → `3003`。本期返回 `1004`。

---

## POST /v1/account/deactivate — 注销账户

需登录 + 二次确认（请求带验证码增强安全）。

请求：
```json
{ "code": "1234" }
```
执行：`users.status = -1`（软注销），吊销全部 token，孩子档案软删，订阅记录保留（合规/对账）。30 天后物理清理（运维任务）。

响应：`{ "code": 0, "message": "账户已注销", "data": null }`
