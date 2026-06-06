# 架构与横切设计

## 1. 进程结构（模块化单体）

```
cmd/server/main.go            # 启动、依赖注入、路由注册
internal/
  auth/        # 验证码、登录、token 签发/校验
  account/     # 资料、登录身份、注销
  children/    # 孩子档案
  subscription/# 交易校验、Apple 通知处理、权益
  usage/       # 免费额度
  admin/       # 后台
  platform/
    db/        # pgx 连接池、迁移
    redis/     # 客户端
    sms/       # 阿里云 SMS 封装
    oss/       # 阿里云 OSS 封装
    appstore/  # App Store Server API + JWS 验签
    jwt/       # 签发/校验
    httpx/     # 响应信封、中间件、错误映射
```

每个模块对外暴露 `Service` 接口 + HTTP handler；模块间通过接口调用，不直接访问彼此的表。

## 2. 鉴权

### Access Token（JWT, RS256 或 HS256）
- 有效期 **2h**，无状态。
- Payload：`{ "sub": "<user_id>", "iat": ..., "exp": ..., "jti": "..." }`
- 客户端置于 `Authorization: Bearer <token>`。

### Refresh Token（不透明随机串）
- 有效期 **30 天**，`crypto/rand` 32 字节 base64url，前缀 `rt_`。
- **仅存哈希**（SHA-256）于 `refresh_tokens.token_hash`，明文只回客户端一次。
- 每次刷新**轮换**：旧 token 置 `revoked=true`，发新 token（检测重放）。
- 绑定 `device_id`。登出 = 吊销当前；风控/改密 = 吊销用户全部。

### 刷新流程
```
POST /v1/auth/token/refresh { refresh_token, device_id }
→ 校验哈希、未吊销、未过期、device 匹配 → 轮换 → 返回新 access+refresh
```

## 3. 短信验证码（Redis）

- Key：`sms:{scene}:{phone}` → 存验证码 **SHA-256 哈希** + 尝试次数，TTL **300s**。
- 校验失败计数，**≥5 次锁定**该 key（删除，需重发）。
- 发送限流：
  - 同号 **60s** 一条：`sms:cd:{phone}`，TTL 60。
  - 同号每日 **≤10 条**：`sms:daily:{phone}`，TTL 当日剩余秒数。
  - 同 IP 每日 **≤50 条**。
- 开发环境固定码 `1234`（与客户端 mock 一致），由配置开关控制。

## 4. 接口限流（Redis 令牌桶/计数）

- 全局按 IP：默认 **60 req/min**。
- 敏感接口（登录、发码）额外按手机号/设备限流。
- 超限返回 HTTP 429 + `code=429`。

## 5. 订阅对账闭环

```
登录 → 后端下发 app_account_token
购买 → 客户端 StoreKit 带 .appAccountToken(token)
  ① 客户端 POST /subscription/verify { transaction_id }  （即时生效）
  ② Apple → POST /webhook/appstore/notifications (JWS)    （续费/退款/过期真相源）
后端验签 → 取 appAccountToken → 定位 user → upsert subscriptions
客户端 GET /subscription 以后端为准
```

- Webhook **必须幂等**：`subscription_events.notification_uuid UNIQUE`，重复直接 200。
- Webhook 处理要快速返回 200，重活进队列/异步；失败靠 Apple 重试。
- JWS 验签：用 Apple 根证书校验 x5c 证书链，再验签名。

## 6. 免费额度（服务化）

- 按 `user_id` + 月份（`YYYY-MM`）记录已用次数，见 `usage_quota` 表。
- 生成故事前客户端调 `GET /usage`，服务端返回剩余次数 + 是否可生成（订阅则无限）。
- 生成成功后客户端调 `POST /usage/consume`（服务端原子自增，防并发超额）。
- 订阅用户 `can_generate=true` 且不消耗额度。

## 7. 安全要点

- 全站 HTTPS；HSTS。
- 手机号等 PII 入库可考虑加密列或至少访问审计；日志脱敏（手机号掩码）。
- 所有写接口校验 `user_id` 归属（孩子、订阅只能操作自己的）。
- 管理后台独立鉴权（`admin_users` + 角色），与 App 用户体系隔离。
- App Store 共享密钥、阿里云 AK/SK、JWT 私钥走环境变量/密钥管理，不入库不入仓。

## 8. ID 策略

- `users.id` 等用 **雪花 ID（int64）** 或 ULID。对外暴露字符串 `user_id`（如 `u_<base32>`），不暴露自增规律。
- `app_account_token` 用 **UUID v4**，全局唯一，对应 StoreKit `appAccountToken`（必须是合法 UUID）。
