# 本地开发环境搭建

---

## 前置条件

- **Go 1.22+**（`go version`）
- **Docker Desktop**（本地 Docker daemon，非远程 context）

> **重要：Docker context 检查**
> 如果你的机器上配置过远程 ECS context，务必先切换回本地：
> ```bash
> docker context ls                    # 查看所有 context
> docker context use desktop-linux     # macOS Docker Desktop
> # 或
> docker context use default           # Linux / 其他
> ```
> 使用远程 context 执行 `make infra` 会操作生产机器。

---

## 推荐工作流（infra in Docker + server on host）

```
make infra          # 起 Postgres + Redis（Docker）
make run            # 在宿主机直接 go run server
```

server 运行在宿主机，改代码保存后 Ctrl-C 重新 `make run` 即可，无需重建镜像。

### 1. 配置（可选）

```bash
cp config.example.env .env   # 复制模板
# 编辑 .env，本地开发默认值已可用，无需改动
```

`.env` 已被 `.gitignore` 排除，不会入库。不创建 `.env` 时 `make run` 会使用内置默认值直接启动。

### 2. 启动基础设施

```bash
make infra
# → 启动 postgres:5432 + redis:6379
# → 等待 postgres 就绪后提示 "Run: make run"
```

### 3. 启动 server

```bash
make run
# → 自动执行 migrations/
# → 监听 http://localhost:8080
```

期望输出（最后一行）：
```
listening on :8080 (env=dev, redis_prefix="ss:dev:", apple_env=Sandbox, strict_apple=false)
```

### 4. 冒烟测试

```bash
# 健康检查
curl http://localhost:8080/healthz
# → {"status":"ok"}

# 发验证码（dev 模式固定返回 1234，不调用阿里云）
curl -X POST http://localhost:8080/v1/auth/sms/send \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000","scene":"login"}'

# 登录
curl -X POST http://localhost:8080/v1/auth/login/sms \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000","code":"1234","device_id":"dev-1"}'
# → 返回 access_token / refresh_token / user

# 受保护接口
TOKEN=<上一步的 access_token>
curl http://localhost:8080/v1/account/profile \
  -H "Authorization: Bearer $TOKEN"
```

### 5. 停止

```bash
make infra-down          # 停止容器，保留数据卷
docker compose down -v   # 停止并清空数据库（重置）
```

---

## 一键命令速查

```bash
make dev             # = make infra + make run（连续执行）
make build           # 编译二进制到 bin/server
make test            # 运行所有测试
make fmt && make vet # 格式化 + 静态检查
make help            # 完整命令说明
```

---

## 测试环境（隔离端口）

测试栈使用独立端口（API :18080, PG :55432, Redis :56379），与 dev 完全隔离：

```bash
make test-infra      # 起测试用 Postgres + Redis
make test            # 运行 Go 测试
make test-infra-down # 停止
```

---

## 管理后台账号

`migrations/0003_seed.sql` 插入了 `admin` 账号，但密码哈希是占位串，需手动替换后才能登录：

```bash
# 生成 bcrypt 哈希
htpasswd -bnBC 12 "" 'your-strong-password' | tr -d ':\n' | sed 's/^$2y/$2a/'

# 更新数据库
psql "postgres://postgres:postgres@localhost:5432/socialstory" \
  -c "UPDATE admin_users SET password_hash='<上面生成的哈希>' WHERE username='admin';"
```

---

## 注意事项

- `SMS_DEV_MODE=true`（默认开启）时验证码固定为 `1234`，不调用阿里云，日志也会打印。
- OSS 头像上传、Apple 收据验证在本地是脚手架状态，不配置也能跑通核心流程（登录/档案/配额）。
- **生产环境**需要完整配置，参见 [aliyun-deploy.md](aliyun-deploy.md)。
