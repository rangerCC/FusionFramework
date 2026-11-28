# 本地部署

面向开发联调，最快路径用 Docker Compose 一键拉起 Postgres + Redis + 服务。

## 方式 A：Docker Compose（推荐）

前置：Docker Desktop。

```bash
cd server
docker compose up --build -d      # 启动 postgres / redis / server
docker compose logs -f server     # 看日志（含 dev 验证码）
```

服务监听 `http://localhost:8080`。首次启动会自动执行 `migrations/` 下的建表脚本（`MIGRATIONS_DIR` 已在 compose 中设置）。

冒烟测试：
```bash
# 健康检查
curl http://localhost:8080/healthz

# 发验证码（dev 模式固定 1234，日志里也会打印）
curl -X POST http://localhost:8080/v1/auth/sms/send \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000","scene":"login"}'

# 登录（dev 验证码 1234）
curl -X POST http://localhost:8080/v1/auth/login/sms \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000","code":"1234","device_id":"dev-1"}'
# → 返回 access_token / refresh_token / user

# 用 access_token 访问受保护接口
TOKEN=<上一步的 access_token>
curl http://localhost:8080/v1/account/profile -H "Authorization: Bearer $TOKEN"
```

停止 / 清库：
```bash
docker compose down          # 停止
docker compose down -v       # 停止并删除数据卷（清空数据库）
```

## 方式 B：本地裸跑（需本机装 Go 1.22+）

前置：本机有可用的 Postgres 与 Redis。

```bash
cd server
cp config.example.env .env          # 按需修改
set -a && source .env && set +a     # 导出环境变量
make tidy                           # 拉依赖、生成 go.sum
make run                            # 自动迁移 + 启动
```

仅编译 / 跑测试：
```bash
make build      # 产出 bin/server
make test
make vet
```

## 验证码与外部服务

- `SMS_DEV_MODE=true` 时不调用阿里云，验证码固定为 `SMS_DEV_CODE`（默认 `1234`），并打印到日志，方便联调。
- OSS / Apple 校验在本地默认是「脚手架」状态（见下「未完成项」），不配置也能跑通登录/账户/孩子档案/额度等核心流程。

## 管理后台账号

`migrations/0003_seed.sql` 插入了用户名 `admin`，但密码哈希是**占位串**，无法登录。生成真实 bcrypt 哈希后替换：
```bash
# 任选其一生成 bcrypt：
htpasswd -bnBC 12 "" 'your-strong-password' | tr -d ':\n' | sed 's/^$2y/$2a/'
# 然后 UPDATE admin_users SET password_hash='...' WHERE username='admin';
```

## 未完成项（需接入真实服务后补全）

代码中以下处为**可编译的脚手架**，注释标注了 TODO：
- `internal/platform/sms`：阿里云 Dysmsapi 实际调用。
- `internal/platform/oss`：OSS PostObject policy 的签名计算。
- `internal/platform/appstore`：JWS 验签（x5c 证书链校验）与 App Store Server API 调用。

在接通这些之前，订阅 `verify` / `webhook` 能跑流程但不做真实签名校验，**切勿用于生产**。
