# 阿里云资源配置：RAM、短信、密钥落盘

承接 [README.md](README.md)，这里是访问控制、短信开通、以及在 ECS 上安全落盘配置的细节。

---

## RAM 子账号与 AccessKey（重要：不要用主账号 AK）

服务要用 AK/SK 调短信和（理论上）OSS。给一个**最小权限**的 RAM 用户：

1. RAM 控制台 → 创建用户（编程访问），拿到 AccessKey ID / Secret。
2. 授权（按需最小化）：
   - 短信：`AliyunDysmsFullAccess`（或自定义只含 `dysms:SendSms` 的策略）。
   - OSS：本服务端只签 PostObject policy、**不直接调 OSS API**，理论上不需要 OSS 权限；用同一对 AK/SK 给客户端签名即可。若你日后要服务端直传，再加 `oss:PutObject` 限定到 `socialstory-prod/avatar/*`。
3. 这对 AK/SK 同时填到 `ALIYUN_SMS_KEY/SECRET` 和 `OSS_ACCESS_KEY/SECRET`（可复用，也可拆成两对更细）。

> 进阶：敏感值建议托管到**阿里云 KMS / 凭据管家**，启动时拉取，而不是明文写 `.env.prod`。起步阶段至少保证 `.env.prod` 权限 600 且不入库。

---

## 短信服务

1. 短信服务控制台 → 申请**签名**（如「社交故事」），需审核（数小时到 1 天）。
2. 申请**模板**，类型「验证码」，内容形如：
   ```
   您的验证码是 ${code}，5 分钟内有效。
   ```
   模板变量名必须是 `code`（与代码里 `TemplateParam={"code": ...}` 对应）。
3. 审核通过后记下 **签名名称** 和 **模板 CODE**（形如 `SMS_123456789`）。
4. 填入 `.env.prod`：`SMS_SIGN_NAME`、`SMS_TEMPLATE_CODE`，并设 `SMS_DEV_MODE=false`。

> 代码里 endpoint 用全国通用 `dysmsapi.aliyuncs.com`，无需配置地域。

---

## Apple App Store（订阅验证）

1. App Store Connect → 用户和访问 → 集成 → App Store Server API → 生成密钥，下载 `.p8`。
2. 记下 **Key ID**、**Issuer ID**、Bundle ID（`com.alitrip.socialstory`）。
3. `.p8` 上传到 ECS 的 `/etc/socialstory/AuthKey.p8`，权限 600。
4. `.env.prod`：`APPLE_KEY_ID` / `APPLE_ISSUER_ID` / `APPLE_PRIVATE_KEY_PATH=/etc/socialstory/AuthKey.p8`，`APPLE_ENVIRONMENT=Production`、`STRICT_APPLE_ENV=true`。
5. App Store Connect 里把**服务器通知 V2 URL** 配成 `https://<你的域名>/v1/webhook/appstore/notifications`（Production 与 Sandbox 各配一次）。

> 代码已对 Server API 做 Production→Sandbox 自动回退，所以 TestFlight/审核期的沙盒交易也能查到，无需改配置。

---

## 在 ECS 上落盘配置与密钥

```bash
sudo mkdir -p /etc/socialstory
sudo chmod 700 /etc/socialstory

# 1) 上传 .p8（从本机 scp）
#    scp AuthKey.p8 ecs-user@<ECS公网IP>:/tmp/
sudo mv /tmp/AuthKey.p8 /etc/socialstory/AuthKey.p8
sudo chmod 600 /etc/socialstory/AuthKey.p8

# 2) 生成 .env.prod：用仓库里的 config.prod.env 作模板
#    把所有 CHANGE_ME 换成真实值（RDS/Redis 地址、AK/SK、短信、Apple 等）
sudo cp config.prod.env /etc/socialstory/.env.prod
sudo chmod 600 /etc/socialstory/.env.prod
sudo vi /etc/socialstory/.env.prod   # 填值

# 3) 生成强随机 JWT 密钥填进去
openssl rand -base64 48
```

`.env.prod` 必填项核对（对照 [env_checklist.md](env_checklist.md)）：
- `APP_ENV=prod`
- `DATABASE_URL`（RDS 内网 + `sslmode=require`）
- `REDIS_ADDR` / `REDIS_PASSWORD`
- `JWT_SECRET`（openssl 随机，且与测试环境不同）
- `SMS_DEV_MODE=false` + 短信四项
- `OSS_*` 五项
- `APPLE_*` + `STRICT_APPLE_ENV=true`
- `ALLOWED_ORIGINS`（收紧到生产域名，别留 `*`）
