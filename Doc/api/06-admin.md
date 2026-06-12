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

## GET /v1/admin/users/{user_id} — 用户详情（聚合）

响应聚合：资料、登录绑定、孩子列表、最新订阅、当月额度。
```json
{ "code": 0, "data": {
    "profile": { "user_id": "u_...", "nickname": "家长_8000", "avatar_url": null,
                 "status": 1, "app_account_token": "uuid", "created_at": "..." },
    "bindings": [ { "provider": "phone", "identifier": "138****8000" } ],
    "children": [ { "child_id": "c_...", "name": "乐乐", "gender": "boy",
                    "birthday": "2019-05-01", "diagnosis_type": "asd",
                    "language_level": "simple", "is_default": true } ],
    "subscription": { "product_id": "...", "status": "active", "expires_at": "...",
                      "auto_renew": true, "environment": "Production" },
    "usage": { "period": "2026-06", "used": 2, "quota": 3 }
  } }
```
- `subscription` 为 `null` 表示无订阅记录；`usage.quota` 为 `null` 表示当月尚无额度行（视为默认配额）。
- 错误：`1004`（用户不存在）。

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

## GET /v1/admin/subscriptions — 订阅列表

`subscriptions` join 用户的分页列表，用于核对 Apple 通知处理情况。

Query：`?status=active&environment=Production&keyword=138****&page=1&page_size=20`
（`status` / `environment` / `keyword` 均可选；keyword 匹配昵称或手机号）

响应：
```json
{ "code": 0, "data": {
    "items": [
      { "user_id": "u_...", "nickname": "家长_8000", "product_id": "com.alitrip.socialstory.yearly",
        "status": "active", "expires_at": "...", "auto_renew": true,
        "environment": "Production", "updated_at": "..." }
    ],
    "total": 12, "page": 1, "page_size": 20
  } }
```

---

## GET /v1/admin/audit-logs — 审计日志

所有写操作（改额度、封禁等）的流水，倒序。

Query：`?actor=admin&action=quota&target=u_xxx&page=1&page_size=20`（均可选，模糊匹配）

响应：
```json
{ "code": 0, "data": {
    "items": [
      { "actor": "admin", "action": "quota.adjust", "target": "u_...",
        "detail": { "delta": 3, "reason": "客诉补偿" }, "created_at": "..." }
    ],
    "total": 34, "page": 1, "page_size": 20
  } }
```

---

## GET /v1/admin/featured-stories — 精选故事管理列表

管理用全量列表（不走 ETag/304，含 `sort`）。增删见 [07-featured-stories.md](07-featured-stories.md)。

响应：
```json
{ "code": 0, "data": {
    "items": [
      { "story_id": "feat_...", "title": "我和爸爸妈妈去聚餐", "image_url": "https://...",
        "word_count": 75, "sort": 1, "created_at": "..." }
    ],
    "total": 3
  } }
```

---

## 审计

所有写操作（改额度、封禁、注销）写 `audit_logs(actor, action, target, detail, created_at)`，便于追责。可经 `GET /v1/admin/audit-logs` 查询。
