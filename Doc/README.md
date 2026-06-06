# Social Story 账号后台服务 — 设计文档

本目录是「社交故事生成器」App 的后端账号系统设计文档。后端是**孩子档案、订阅权益、免费额度的唯一真相源**；第三方仅用于登录身份。

## 本期范围（Phase 1）

- ✅ 手机号 + 短信验证码登录/注册（原生 App）
- ✅ 账户资料（昵称、头像）、登录方式查询、账户注销
- ✅ 孩子档案 CRUD（一个账户多个孩子）
- ✅ 订阅服务化：App Store Server Notifications V2 接收 + 交易校验 + 权益查询
- ✅ 免费额度服务化（按账户按月，替代客户端 UserDefaults）
- ⏸️ 微信登录/绑定：**本期不实现**（规避 App Store 4.8 强制 Sign in with Apple）。DB 与接口已预留扩展位。
- ⏸️ Apple 登录：本期不实现（纯国内）。

## 技术栈

| 层 | 选型 |
|---|---|
| 语言/框架 | Go + Gin |
| 数据库 | PostgreSQL 14+ |
| 缓存/限流/验证码 | Redis 7+ |
| 对象存储 | 阿里云 OSS（头像） |
| 短信 | 阿里云 SMS |
| 鉴权 | JWT access token + 不透明 refresh token（哈希入库、可吊销轮换） |
| 部署 | 阿里云 ECS/ACK，域名需 ICP 备案 |

## 架构

模块化单体（Modular Monolith）：单进程内分模块 `auth / account / children / subscription / usage / admin`，未来按模块拆分微服务。

## 文档索引

| 文件 | 内容 |
|---|---|
| [01-architecture.md](01-architecture.md) | 架构、鉴权、限流、部署 |
| [api/00-conventions.md](api/00-conventions.md) | 响应信封、分页、时间、鉴权头 |
| [api/01-auth.md](api/01-auth.md) | 验证码、登录、刷新、登出 |
| [api/02-account.md](api/02-account.md) | 资料、绑定查询、注销 |
| [api/03-children.md](api/03-children.md) | 孩子档案 CRUD |
| [api/04-subscription.md](api/04-subscription.md) | 订阅查询、交易校验、Apple Webhook |
| [api/05-usage.md](api/05-usage.md) | 免费额度查询/消费 |
| [api/06-admin.md](api/06-admin.md) | 管理后台接口 |
| [api/99-error-codes.md](api/99-error-codes.md) | 业务错误码表 |
| [migrations/0001_init.sql](migrations/0001_init.sql) | users / auth_identities / children |
| [migrations/0002_subscription_session_admin.sql](migrations/0002_subscription_session_admin.sql) | subscriptions / events / usage / tokens / devices / admin / audit |
| [migrations/0003_seed.sql](migrations/0003_seed.sql) | 初始管理员（占位口令，上线前替换） |

## 客户端对接

iOS 端已有 `SSAccountService` 协议（AccountKit pod）。接入本服务时新增 `SSRemoteAccountService` 实现该协议、替换 `SSMockAccountService`。关键映射见 [api/01-auth.md](api/01-auth.md) 登录响应 → `SSUser`。

⚠️ **`app_account_token` 改由后端签发**：登录响应下发，客户端透传给 StoreKit 购买，后端凭此对账。
