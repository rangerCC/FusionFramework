# 通用约定

## Base URL

```
https://api.<your-domain>.com
```

所有接口前缀 `/v1`。

## 响应信封

所有响应统一结构：

```json
{
  "code": 0,
  "message": "ok",
  "data": { },
  "request_id": "req_01H..."
}
```

| 字段 | 说明 |
|---|---|
| `code` | 业务码，`0` = 成功，非 0 见 [99-error-codes.md](99-error-codes.md) |
| `message` | 人类可读信息，可直接弹给用户（已做中文文案） |
| `data` | 业务数据，失败时为 `null` |
| `request_id` | 链路追踪 ID，排障用 |

HTTP 状态码同时使用：
- `200` 成功
- `400` 参数错误
- `401` 未认证 / token 失效
- `403` 无权限
- `404` 资源不存在
- `409` 冲突（如身份已绑定）
- `429` 限流
- `500` 服务端错误

## 鉴权头

需要登录的接口：

```
Authorization: Bearer <access_token>
```

缺失或失效 → HTTP 401 + `code=2001`。客户端据此用 refresh token 刷新；刷新也失败则跳登录。

## 公共请求头

| 头 | 必填 | 说明 |
|---|---|---|
| `Authorization` | 视接口 | Bearer access token |
| `X-Device-Id` | 是 | 设备唯一标识（客户端生成持久化） |
| `X-App-Version` | 是 | 如 `1.0.0` |
| `X-Platform` | 是 | `ios`（预留 `android`） |
| `Content-Type` | 写接口 | `application/json` |

## 时间格式

所有时间用 **RFC3339 / ISO8601 UTC**：`2026-12-01T00:00:00Z`。客户端按本地时区展示。

## 分页

列表接口用游标分页：

```
?limit=20&cursor=<opaque>
→ data: { "items": [...], "next_cursor": "...", "has_more": true }
```

`next_cursor` 为 `null` 表示到底。本期孩子列表数据量小，可不传游标返回全量。

## 手机号

- 入参：11 位中国大陆手机号（`^1[3-9]\d{9}$`）。
- 出参展示用掩码：`phone_masked`（`138****8000`），不回传明文手机号给非本人。

## 幂等

- 写接口可带 `X-Idempotency-Key`（可选），服务端对相同 key 在 24h 内返回首次结果。
- Apple Webhook 用 `notification_uuid` 强制幂等。

## 字段命名

JSON 全部 **snake_case**。枚举值用小写字符串常量（见各接口）。
