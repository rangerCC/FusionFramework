# 上线步骤：镜像、部署、SLB、验证

承接 [README.md](README.md) 和 [aliyun_resources.md](aliyun_resources.md)。资源开通、`.env.prod` 与 `.p8` 就位后，按此上线。

---

## 1. 构建并推送镜像到 ACR（本机执行）

```bash
# 登录 ACR（个人版用户名是阿里云账号，密码在 ACR 控制台“访问凭证”设置）
docker login --username=<阿里云账号> registry.cn-hangzhou.aliyuncs.com

# 构建 + 推送（脚本默认 linux/amd64，适配 x86 ECS）
ACR_NAMESPACE=<你的命名空间> \
IMAGE_TAG=v1.0.0 \
./deploy/build_and_push.sh
```

脚本结束会打印完整镜像地址，形如：
`registry.cn-hangzhou.aliyuncs.com/<ns>/socialstory-server:v1.0.0`

---

## 2. 在 ECS 上部署

```bash
# ECS 上也要先 docker login 到 ACR（同上）
# 把 deploy/deploy.sh 拷到 ECS，然后：
IMAGE=registry.cn-hangzhou.aliyuncs.com/<ns>/socialstory-server:v1.0.0 \
./deploy.sh
```

脚本会：拉镜像 → 删旧容器 → 用 `/etc/socialstory/.env.prod` 启新容器（挂载 `/etc/socialstory` 只读、带健康检查、`--restart=always`）→ 打印日志和本机 `/healthz` 结果。

首次启动应在日志看到：
```
[migrate] applied 0001_init.sql
...
listening on :8080 (env=prod, redis_prefix="ss:prod:", apple_env=Production, strict_apple=true)
```
若 panic 在 `env guard` 或 `migrate`，说明 DATABASE_URL 指错库或库被其他环境占用——核对 RDS 地址和 APP_ENV。

---

## 3. SLB/ALB 终止 HTTPS

1. 数字证书服务签发你域名的证书（或上传已有证书）。
2. 建 SLB（或 ALB）：
   - 监听 **HTTPS:443**，绑定证书。
   - 后端服务器组：加入 ECS，后端端口 **8080**。
   - 健康检查：HTTP，路径 `/healthz`，期望 200。
   - （可选）加 **HTTP:80 → 443 重定向**。
3. 域名解析：把 `api.<你的域名>` 的 A 记录指向 SLB 公网 IP。
4. App 端 base URL 切到 `https://api.<你的域名>/v1`。

---

## 4. 端到端验证

```bash
# 1) 健康检查（走 SLB HTTPS）
curl -fsS https://api.<域名>/healthz          # 期望 {"status":"ok"}

# 2) 短信 → 登录
curl -X POST https://api.<域名>/v1/auth/sms/send \
  -H 'Content-Type: application/json' -d '{"phone":"<真实手机号>"}'
# 真机收到验证码后：
curl -X POST https://api.<域名>/v1/auth/login/sms \
  -H 'Content-Type: application/json' \
  -d '{"phone":"<手机号>","code":"<验证码>"}'      # 期望返回 access/refresh token

# 3) OSS 头像直传（需要上一步拿到的 token）
curl -X POST https://api.<域名>/v1/account/avatar/upload-url \
  -H "Authorization: Bearer <access_token>"
# 用返回的 upload_url + form_fields 拼 multipart POST 一张图，期望 HTTP 200，
# 再访问 public_url 能看到图。
```

- **Apple 订阅**：用 sandbox 账号在 App 内购买 → App 调 `POST /v1/subscription/verify`，确认订阅状态写入；在 App Store Connect 发一条 Test 通知，确认 `/v1/webhook/appstore/notifications` 返回 200 且验签通过（日志无 `verify notification` 错误）。
- **数据**：RDS 里 `users`/`subscriptions` 有写入；Redis 里 key 带 `ss:prod:` 前缀（`redis-cli -h <内网> -a <密码> keys 'ss:prod:*'`）。

---

## 5. 回滚

```bash
# 用上一个可用 tag 重新部署即可（容器无状态，数据在 RDS/Redis）
IMAGE=registry.cn-hangzhou.aliyuncs.com/<ns>/socialstory-server:<上个tag> ./deploy.sh
```

---

## 6. 运维补充（可选但建议）

- **日志**：接阿里云 SLS（容器日志驱动或 Logtail），便于检索。
- **监控告警**：云监控给 ECS（CPU/内存）、RDS（连接数/慢查询）、Redis（内存/命中率）配告警。
- **备份**：RDS 开自动备份；确认备份保留周期符合预期。
- **数据迁移**：本地若有要保留的数据，`pg_dump` 本地库后导入 RDS；全新生产库则靠自动 migrations 建表，无需导数据。
- **SMC 不需要**：`run_smc_client.sh` 是整机物理迁移工具，容器化部署用不上，可忽略。
