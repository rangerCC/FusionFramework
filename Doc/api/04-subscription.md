# Subscription — 订阅

后端是权益真相源，StoreKit `currentEntitlements` 仅客户端离线兜底。

## 闭环

```
登录 → 后端下发 app_account_token（user 表已有）
购买 → 客户端 StoreKit 带 .appAccountToken(token)
  ① 客户端 POST /v1/subscription/verify { transaction_id }   即时生效
  ② Apple → POST /v1/webhook/appstore/notifications (JWS)     续费/退款/过期真相源
后端验签 → 取 appAccountToken → 定位 user → upsert subscriptions
客户端 GET /v1/subscription 以后端为准
```

---

## GET /v1/subscription — 查询当前权益

需 `Authorization`。

响应（有订阅）：
```json
{ "code": 0, "data": {
    "is_active": true,
    "product_id": "com.alitrip.socialstory.yearly",
    "expires_at": "2026-12-01T00:00:00Z",
    "auto_renew": true,
    "status": "active",
    "environment": "Production",
    "source": "app_store"
  } }
```
响应（无订阅）：
```json
{ "code": 0, "data": { "is_active": false, "status": "none" } }
```
`status` ∈ `active | expired | grace | billing_retry | revoked | none`。

---

## POST /v1/subscription/verify — 上报并校验交易

客户端购买成功后调用，让权益**即时生效**（不必等 Apple 异步通知）。

需 `Authorization`。请求：
```json
{ "transaction_id": "2000000123456789" }
```

后端流程：
1. 调 App Store Server API `GET /inApps/v1/transactions/{transactionId}` 拿签名交易。
2. 验签 JWS，解析得 `originalTransactionId / productId / expiresDate / appAccountToken`。
3. 校验 `appAccountToken` == 当前 user 的 token；不符 → `5002`。
4. `upsert subscriptions`（按 `original_transaction_id`）。
5. 返回最新权益（同 GET）。

错误：`5001` 查无交易、`5002` 不属于当前账户、`5003` 同步失败。

---

## POST /v1/webhook/appstore/notifications — Apple 服务器通知

**Apple → 后端**，无 App 鉴权（靠 JWS 验签）。App Store Connect 配置此 URL。

请求体（Apple 格式）：
```json
{ "signedPayload": "<JWS>" }
```

后端流程：
1. 验签 `signedPayload`（Apple 根证书校验 x5c 链）。
2. 解析 `notificationType / subtype / data.signedTransactionInfo / data.signedRenewalInfo`。
3. 幂等：`notification_uuid` 已存在 → 直接 200。
4. 落 `subscription_events`（原文存 `raw_payload`）。
5. 依 `appAccountToken` 定位 user，按交易 upsert `subscriptions`，更新 `status / expires_at / auto_renew`。
6. **快速返回 200**（重活异步）。失败不返回 2xx，靠 Apple 重试。

处理的 `notificationType`（V2）：
`SUBSCRIBED / DID_RENEW / DID_CHANGE_RENEWAL_STATUS / EXPIRED / GRACE_PERIOD_EXPIRED / REVOKE / REFUND`。

响应：HTTP 200，body 可空。

---

## 注意

- 沙盒与生产通知地址不同，`environment` 字段区分，分别落库（避免沙盒污染生产权益）。
- App 内购买的免费额度逻辑见 [05-usage.md](05-usage.md)：订阅用户 `can_generate=true` 且不消耗额度。
