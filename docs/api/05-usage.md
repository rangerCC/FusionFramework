# Usage — 免费额度

替代客户端 UserDefaults 的设备本地计数，改为**按账户按月**服务端记账，解决卸载重装/换设备重置额度漏洞。

规则：
- 免费用户每月 `monthly_free_quota`（默认 **3**）次。
- 订阅用户无限，不消耗额度。
- 按自然月重置（`YYYY-MM`，服务器时区 Asia/Shanghai）。

所有接口需 `Authorization`。

---

## GET /v1/usage — 查询额度

响应：
```json
{ "code": 0, "data": {
    "can_generate": true,
    "is_subscribed": false,
    "monthly_quota": 3,
    "used": 1,
    "remaining": 2,
    "period": "2026-06"
  } }
```
订阅用户：
```json
{ "code": 0, "data": {
    "can_generate": true, "is_subscribed": true,
    "monthly_quota": null, "used": 0, "remaining": null, "period": "2026-06"
  } }
```
`null` 表示无限。客户端生成前调用此接口做 gating（替代 `SubscriptionManager.canGenerateStory`）。

---

## POST /v1/usage/consume — 消费一次额度

故事生成**成功后**调用。服务端原子自增，防并发超额。

请求：
```json
{ "story_id": "user-uuid", "child_id": "c_01H9..." }
```
| 字段 | 必填 | 说明 |
|---|---|---|
| story_id | 否 | 客户端故事 ID，便于审计 |
| child_id | 否 | 关联孩子，便于统计 |

响应（成功）：
```json
{ "code": 0, "data": { "remaining": 1, "used": 2 } }
```
响应（额度耗尽，订阅用户不会触发）：
```json
{ "code": 6001, "message": "本月免费次数已用完", "data": null }
```

实现：`INSERT ... ON CONFLICT (user_id, period) DO UPDATE SET used = usage_quota.used + 1 WHERE usage_quota.used < quota` —— 原子校验+自增；影响行数 0 表示已超额，返回 `6001`。订阅用户跳过校验直接记录（用于统计，不限制）。

---

## 客户端迁移说明

iOS `SubscriptionManager` 现用 `ss_free_used_count_<userID>`（UserDefaults）。接入后：
- 改为登录后以服务端 `GET /usage` 为准。
- 离线兜底可保留本地缓存，但联网后以服务端覆盖。
