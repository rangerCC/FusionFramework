# 生产环境变量核对表（.env.prod）

逐项核对，所有 `CHANGE_ME` 必须替换。模板来自仓库根的 `config.prod.env`。落盘到 ECS 的 `/etc/socialstory/.env.prod`，权限 600，**绝不入库**（已在 `.gitignore`）。

| 变量 | 必填 | 生产取值 | 来源 / 说明 |
|------|:---:|---------|------------|
| `APP_ENV` | ✅ | `prod` | 触发 Production 默认值 + 严格校验；填错会 panic |
| `PORT` | | `8080` | 容器内端口，SLB 后端指这里 |
| `DATABASE_URL` | ✅ | `postgres://ss_prod:<pwd>@<rds内网>:5432/socialstory?sslmode=require` | RDS；生产必须 `sslmode=require` |
| `REDIS_ADDR` | ✅ | `<redis内网>:6379` | 云数据库 Redis |
| `REDIS_PASSWORD` | ✅ | `<redis密码>` | Redis 实例密码 |
| `REDIS_DB` | | `0` | |
| `REDIS_KEY_PREFIX` | | `ss:prod:` | 默认按 env 生成，一般不用改 |
| `JWT_SECRET` | ✅ | `openssl rand -base64 48` 的输出 | 强随机，且与测试环境不同 |
| `ACCESS_TTL_SEC` | | `7200` | access token 2h |
| `REFRESH_TTL_SEC` | | `2592000` | refresh token 30d |
| `SMS_DEV_MODE` | ✅ | `false` | **必须 false**，否则验证码只打日志不真发 |
| `ALIYUN_SMS_KEY` | ✅ | RAM AccessKey ID | 见 aliyun_resources.md |
| `ALIYUN_SMS_SECRET` | ✅ | RAM AccessKey Secret | |
| `SMS_SIGN_NAME` | ✅ | 审核通过的签名名 | 短信控制台 |
| `SMS_TEMPLATE_CODE` | ✅ | `SMS_xxxxxxxxx` | 模板，变量名须为 `code` |
| `OSS_ENDPOINT` | ✅ | `oss-cn-hangzhou.aliyuncs.com` | **不带 https://** |
| `OSS_BUCKET` | ✅ | `socialstory-prod` | |
| `OSS_ACCESS_KEY` | ✅ | RAM AccessKey ID | 可与短信复用 |
| `OSS_SECRET` | ✅ | RAM AccessKey Secret | |
| `OSS_PUBLIC_HOST` | | `https://cdn.<域名>` | 配了 CDN 才填；否则留空走默认拼接 |
| `APPLE_BUNDLE_ID` | ✅ | `com.alitrip.socialstory` | |
| `APPLE_ENVIRONMENT` | ✅ | `Production` | |
| `STRICT_APPLE_ENV` | ✅ | `true` | 拒绝沙盒交易冒充生产 |
| `APPLE_ISSUER_ID` | ✅ | App Store Connect Issuer ID | |
| `APPLE_KEY_ID` | ✅ | App Store Server API Key ID | |
| `APPLE_PRIVATE_KEY_PATH` | ✅ | `/etc/socialstory/AuthKey.p8` | 容器挂载只读 |
| `MONTHLY_FREE_QUOTA` | | `3` | 未订阅用户月免费次数 |
| `MIGRATIONS_DIR` | | `/app/migrations` | 镜像内已设，一般不用动 |
| `ALLOWED_ORIGINS` | ✅ | `https://api.<域名>` | **收紧，别留 `*`** |

## 上线前最后检查
- [ ] 所有 `CHANGE_ME` 已替换，无残留
- [ ] `SMS_DEV_MODE=false`
- [ ] `DATABASE_URL` 用内网地址且 `sslmode=require`
- [ ] `JWT_SECRET` 是随机值，非默认 `dev-insecure-change-me`
- [ ] `STRICT_APPLE_ENV=true`、`APPLE_ENVIRONMENT=Production`
- [ ] `ALLOWED_ORIGINS` 已收紧
- [ ] `/etc/socialstory/.env.prod` 与 `AuthKey.p8` 权限均为 600
- [ ] RDS/Redis 白名单只放 ECS，未开公网
- [ ] ECS 安全组 8080 仅对 SLB 开放
