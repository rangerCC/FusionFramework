# Admin — 管理后台

独立鉴权体系（`admin_users` + 角色），与 App 用户隔离。前缀 `/v1/admin`，需 `Authorization: Bearer <admin_access_token>`。

角色：`super`（全权）、`support`（客服：查/改额度）、`viewer`（只读）。

---

## POST /v1/admin/login — 管理员登录

用户名 + 密码（`bcrypt` 校验）。

请求：
```json
{ "username": "admin", "password": "******" }
```
响应：
```json
{ "code": 0, "data": { "access_token": "...", "expires_in": 7200, "role": "super" } }
```
错误：`9001`。

---

## GET /v1/admin/users — 用户列表/搜索

Query：`?keyword=138****&page=1&page_size=20&status=1`
响应：
```json
{ "code": 0, "data": {
    "items": [
      { "user_id": "u_...", "nickname": "家长_8000", "phone_masked": "138****8000",
        "status": 1, "is_subscribed": true, "children_count": 2,
        "created_at": "..." }
    ],
    "total": 1234, "page": 1, "page_size": 20
  } }
```

---

## GET /v1/admin/users/{user_id} — 用户详情

响应聚合：资料、绑定、孩子列表、订阅状态、当月额度。
```json
{ "code": 0, "data": {
    "profile": { ... },
    "children": [ ... ],
    "subscription": { "is_active": true, "product_id": "...", "expires_at": "..." },
    "usage": { "period": "2026-06", "used": 2, "quota": 3 }
  } }
```

---

## POST /v1/admin/users/{user_id}/quota — 客服调整额度

`support` 及以上。给用户当月额度发放补偿。

请求：
```json
{ "delta": 3, "reason": "客诉补偿" }
```
`delta` 可正可负，作用于当月 `used`（如 `delta=3` 等效少用 3 次）。写 `audit_logs`。

响应：`{ "code": 0, "data": { "period": "2026-06", "used": 0, "remaining": 6 } }`

---

## POST /v1/admin/users/{user_id}/status — 封禁/解封

`super`。请求：
```json
{ "status": 0, "reason": "违规" }
```
`status`：`1` 正常 / `0` 封禁。封禁即吊销该用户全部 token。写 `audit_logs`。

---

## GET /v1/admin/dashboard — 数据看板

响应：
```json
{ "code": 0, "data": {
    "total_users": 12345,
    "new_users_today": 56,
    "active_subscriptions": 789,
    "revenue_estimate_month": 0,
    "stories_generated_today": 234
  } }
```

---

## GET /v1/admin/subscriptions — 订阅流水

Query：`?status=active&page=1&page_size=20`
返回 `subscriptions` join 用户的分页列表，用于核对 Apple 通知处理情况。

---

## 审计

所有写操作（改额度、封禁、注销）写 `audit_logs(actor, action, target, detail, created_at)`，便于追责。
