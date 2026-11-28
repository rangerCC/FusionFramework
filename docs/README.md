# 文档导航

SocialStoryMate 全项目文档统一入口。

---

## 目录

### 架构
- [01-architecture.md](01-architecture.md) — 整体架构、FusionFramework 框架设计

### 接口文档（`api/`）

| 文件 | 内容 |
|---|---|
| [api/00-conventions.md](api/00-conventions.md) | 响应信封、分页、时间、鉴权头规范 |
| [api/01-auth.md](api/01-auth.md) | 认证（短信验证码、登录、刷新、登出） |
| [api/02-account.md](api/02-account.md) | 用户资料、头像上传、账户注销 |
| [api/03-children.md](api/03-children.md) | 子档案 CRUD |
| [api/04-subscription.md](api/04-subscription.md) | 订阅/买断查询、收据验证、Apple Webhook |
| [api/05-usage.md](api/05-usage.md) | 免费配额查询与消费 |
| [api/06-admin.md](api/06-admin.md) | 管理后台接口 |
| [api/07-featured-stories.md](api/07-featured-stories.md) | 精选故事（公开列表 + 管理员 CRUD） |
| [api/99-error-codes.md](api/99-error-codes.md) | 业务错误码表 |

### 数据库迁移（`migrations/`）

| 文件 | 内容 |
|---|---|
| [migrations/0001_init.sql](migrations/0001_init.sql) | users / auth_identities / children |
| [migrations/0002_subscription_session_admin.sql](migrations/0002_subscription_session_admin.sql) | subscriptions / usage / refresh_tokens / admin / audit_logs |
| [migrations/0003_seed.sql](migrations/0003_seed.sql) | 初始管理员种子数据 |
| [migrations/0004_children_default.sql](migrations/0004_children_default.sql) | 子档案默认值 |
| [migrations/0005_featured_stories.sql](migrations/0005_featured_stories.sql) | 精选故事表 |

> 这些文件是 `server/migrations/` 的副本，以 migration 文档为准。

### 服务端运维（`server/`）

| 文件 | 内容 |
|---|---|
| [server/local-deploy.md](server/local-deploy.md) | 本地开发环境搭建 |
| [server/environments.md](server/environments.md) | 测试 / 生产环境隔离机制 |
| [server/aliyun-deploy.md](server/aliyun-deploy.md) | 阿里云生产部署（ECS + RDS + Redis + OSS） |

### 产品需求（`product/`）

- [product/social_stories_gen_requirements_2.0.md](product/social_stories_gen_requirements_2.0.md) — 产品需求文档 V2.0

### 技术规划（`plans/`）

- [plans/2026-11-28-poc-plan.md](plans/2026-11-28-poc-plan.md) — PoC 验证方案 v2.0
