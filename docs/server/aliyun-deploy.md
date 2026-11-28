# 阿里云部署

面向生产/预发。以单台 ECS + Docker 为最小可用方案，并给出托管数据库与扩展建议。

> ⚠️ 合规前置：国内对外提供服务的域名必须完成 **ICP 备案**；涉及账号短信需开通阿里云短信服务并报备签名/模板。提前办理，备案周期较长。

## 架构（最小可用）

```
用户 App ──HTTPS──> SLB/Nginx(443, 证书) ──> ECS: socialstory-server(:8080)
                                                  ├── RDS PostgreSQL
                                                  └── Redis (Tair/云数据库 Redis)
Apple  ──HTTPS──> 同域名 /v1/webhook/appstore/notifications
对象存储: OSS（头像直传）
短信:   阿里云 SMS
```

生产**不要**用 compose 里的 postgres/redis 容器存数据，改用 **RDS PostgreSQL** + **云数据库 Redis**（高可用、备份、免运维）。

## 一、准备云资源

1. **ECS**：2c4g 起，Ubuntu/Alibaba Cloud Linux，安装 Docker。
2. **RDS PostgreSQL 14+**：创建实例与库 `socialstory`，记下内网连接串，开白名单允许 ECS 访问。
3. **云数据库 Redis**：创建实例，记内网地址 + 密码。
4. **OSS**：创建 Bucket（头像），开启对应的 RAM 子账号 AK/SK（最小权限：PutObject）。
5. **短信服务**：申请签名 + 验证码模板（变量 `code`），拿到 AccessKey。
6. **域名 + 证书**：备案域名，申请 SSL 证书（可用 SLB/Nginx 终止 TLS）。

## 二、构建并上传镜像

方式 1：在 ECS 上直接构建
```bash
git clone <repo> && cd <repo>/server
docker build -t socialstory-server:latest .
```

方式 2：用阿里云容器镜像服务（ACR）
```bash
docker build -t registry.cn-hangzhou.aliyuncs.com/<ns>/socialstory-server:1.0.0 .
docker push  registry.cn-hangzhou.aliyuncs.com/<ns>/socialstory-server:1.0.0
# ECS 上 docker pull 同一标签
```

## 三、配置环境变量（生产值）

在 ECS 上创建 `/etc/socialstory/server.env`（**权限 600，不入仓**）：
```bash
APP_ENV=prod
PORT=8080
DATABASE_URL=postgres://<user>:<pass>@<rds-host>:5432/socialstory?sslmode=require
REDIS_ADDR=<redis-host>:6379
REDIS_PASSWORD=<redis-pass>
JWT_SECRET=<openssl rand -base64 48>
ACCESS_TTL_SEC=7200
REFRESH_TTL_SEC=2592000

SMS_DEV_MODE=false
ALIYUN_SMS_KEY=<ak>
ALIYUN_SMS_SECRET=<sk>
SMS_SIGN_NAME=<已审核签名>
SMS_TEMPLATE_CODE=<模板CODE>

OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_BUCKET=<bucket>
OSS_ACCESS_KEY=<oss-ak>
OSS_SECRET=<oss-sk>
OSS_PUBLIC_HOST=https://<cdn-or-bucket-domain>

APPLE_BUNDLE_ID=com.alitrip.socialstory
APPLE_ISSUER_ID=<issuer>
APPLE_KEY_ID=<keyid>
APPLE_PRIVATE_KEY_PATH=/etc/socialstory/AuthKey.p8
MONTHLY_FREE_QUOTA=3

MIGRATIONS_DIR=/app/migrations
ALLOWED_ORIGINS=https://<your-domain>
```

## 四、运行容器

```bash
docker run -d --name socialstory \
  --restart=always \
  -p 127.0.0.1:8080:8080 \
  --env-file /etc/socialstory/server.env \
  -v /etc/socialstory/AuthKey.p8:/etc/socialstory/AuthKey.p8:ro \
  socialstory-server:latest
```

服务启动时会自动执行 `migrations/`（按文件名顺序、记录到 `schema_migrations`，幂等可重复启动）。首次部署后记得用真实 bcrypt 哈希更新管理员密码（见本地文档）。

## 五、Nginx + TLS（终止 HTTPS）

`/etc/nginx/conf.d/socialstory.conf`：
```nginx
server {
    listen 443 ssl http2;
    server_name api.your-domain.com;
    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    client_max_body_size 2m;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
server {
    listen 80;
    server_name api.your-domain.com;
    return 301 https://$host$request_uri;
}
```
> Apple 通知地址须是公网 HTTPS，配置到 App Store Connect 的 Server Notifications（V2），生产/沙盒地址分别填。

## 六、上线前检查清单

- [ ] 域名已备案，证书有效，HTTPS 正常。
- [ ] `JWT_SECRET` 为强随机值；`.env` 权限 600，不入仓。
- [ ] RDS/Redis 仅内网可达，开启自动备份。
- [ ] 管理员密码已改为真实 bcrypt 哈希。
- [ ] `SMS_DEV_MODE=false`，短信签名/模板审核通过。
- [ ] OSS 子账号最小权限；`OSS_PUBLIC_HOST` 指向 CDN。
- [ ] App Store Server API 的 `.p8` / IssuerID / KeyID 配好；JWS 验签已实现（见代码 TODO）。
- [ ] App Store Connect 配好 Server Notifications V2 回调地址。
- [ ] 健康检查 `/healthz` 接入 SLB 探活。

## 七、可演进项

- 多实例水平扩展：给每个实例分配不同的 snowflake node（当前固定为 1，见 `idgen.NewSnowflake(1)`），并在 ECS 前置 SLB。
- 日志/监控：接入 SLS（日志服务）与云监控告警。
- 备份：RDS 自动备份 + 定期导出；OSS 跨区复制。
- 灰度：ACR 多标签 + 滚动替换容器。
