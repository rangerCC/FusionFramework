# 环境隔离（测试 / 生产）

本服务通过 `APP_ENV`（取值 `dev|test|prod`）区分环境，并做**多层隔离**，确保测试与生产即使配置失误也不会串数据。

## 隔离层级

| 层 | 机制 | 效果 |
|---|---|---|
| 配置校验 | `APP_ENV` 非 `dev/test/prod` 直接启动 panic | 杜绝未设置/拼错时「默默当成某环境」 |
| 数据库归属 | 首次启动把 `APP_ENV` 写入 `app_meta` 表；之后启动若不一致**拒绝启动** | 测试服务误连生产库时无法启动，硬性兜底 |
| 数据库实例 | 测试/生产用**独立 DB**（不同实例或库名） | 物理隔离，最稳妥 |
| Redis 键前缀 | 所有 key 自动加 `REDIS_KEY_PREFIX`（默认 `ss:<env>:`） | 共用 Redis 实例也不会串验证码/限流计数 |
| Redis DB index | 建议测试用 `REDIS_DB=1`、生产 `0` | 双保险 |
| JWT 密钥 | 测试/生产用**不同 `JWT_SECRET`** | 测试签发的 token 在生产无效，反之亦然 |
| 内购环境 | `APPLE_ENVIRONMENT`（`Sandbox`/`Production`）+ `STRICT_APPLE_ENV` | Sandbox 交易无法在生产授予权益，反之亦然 |
| OSS | 测试/生产用**不同 bucket** | 头像等资源隔离 |

> `app_meta` 归属检查是最关键的一道：错误的 `DATABASE_URL`（哪怕密码对）也只会让「环境不匹配」的服务启动失败，而不是去改另一个环境的数据。错误信息示例：
> `environment mismatch: this database is stamped "prod" but APP_ENV="test" — refusing to start`

## 默认值（按 APP_ENV 自动推导，可显式覆盖）

| 变量 | dev | test | prod |
|---|---|---|---|
| `REDIS_KEY_PREFIX` | `ss:dev:` | `ss:test:` | `ss:prod:` |
| `APPLE_ENVIRONMENT` | Sandbox | Sandbox | Production |
| `STRICT_APPLE_ENV` | false | true | true |

## 配置文件

- 测试：[`config.test.env`](../config.test.env) → 复制为 `.env.test`
- 生产：[`config.prod.env`](../config.prod.env) → 复制为 `.env.prod`

两份都是模板，敏感值为 `CHANGE_ME`，**不要提交真实密钥**（`.gitignore` 已忽略 `.env.test`/`.env.prod`）。

## 本地起测试环境（与默认 dev 栈并存）

```bash
# 独立容器、独立端口（API :18080, PG :55432, Redis :56379），APP_ENV=test
docker compose -f docker-compose.test.yml up --build -d
curl http://localhost:18080/healthz
docker compose -f docker-compose.test.yml down        # 停止
docker compose -f docker-compose.test.yml down -v      # 连数据卷一起清
```

默认 dev 栈仍是 `docker compose up -d`（API :8080），两者端口/卷/容器名都不冲突，可同时运行。

## 生产部署

生产用独立 RDS/Redis/OSS + `.env.prod`，详见 [aliyun-deploy.md](aliyun-deploy.md)。务必：
- 生产与测试的 `JWT_SECRET` 不同且为强随机值；
- 生产 `APP_ENV=prod`（自动 `Production` + 严格内购校验）；
- 生产 `DATABASE_URL` 指向生产库（首次启动会被 `app_meta` 永久绑定为 `prod`）。
