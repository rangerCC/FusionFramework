# 阿里云部署清单（Runbook）

把 SocialStory Go 服务迁移到阿里云的完整操作步骤。代码侧（短信/OSS/Apple 验证）已补全，本文档是**基础设施 + 上线**部分，需要你登录阿里云账号操作。

部署形态：**ECS + Docker**，前置 **SLB/ALB** 终止 HTTPS；数据用**全托管** RDS for PostgreSQL + 云数据库 Redis 版。

> 约定地域为 `cn-hangzhou`（与 `config.prod.env` 里的 OSS endpoint 一致）。换地域时记得同步所有 endpoint。

---

## 0. 准备清单（开通前先想清楚）

| 资源 | 规格建议（起步） | 备注 |
|------|----------------|------|
| VPC | 1 个，含 1 个交换机/vSwitch | 所有资源放同一 VPC，内网互通 |
| ECS | 2核4G，按量或包年包月 | 装 Docker；公网仅留给运维，业务流量走 SLB |
| RDS PostgreSQL | 14+，2核4G | 与本地版本对齐；内网访问 |
| 云数据库 Redis | 1G 标准版 | 设密码；内网访问 |
| OSS Bucket | 标准存储，私有读写 | 头像直传 + 公网/CDN 读 |
| SLB/ALB | 1 个，公网 | 443 终止 HTTPS |
| ACR | 个人版即可 | 存镜像 |
| 短信服务 | 签名 + 模板 | 需审核，提前申请 |
| 域名 + SSL 证书 | 1 个 | 数字证书服务签发 |

---

## 1. 网络与 ECS

1. 建 VPC + vSwitch（如已有可复用）。
2. 创建 ECS，选上面 VPC，操作系统 Alibaba Cloud Linux / Ubuntu。
3. 安全组：
   - 入方向只放 22（SSH，限你的运维 IP）和 8080（仅对 SLB 后端网段开放，**不要对 0.0.0.0/0**）。
   - 业务 443 由 SLB 持有，ECS 不直接暴露。
4. ECS 上装 Docker：
   ```bash
   # Alibaba Cloud Linux / CentOS 系
   sudo yum install -y docker && sudo systemctl enable --now docker
   # Ubuntu 系
   # sudo apt-get update && sudo apt-get install -y docker.io && sudo systemctl enable --now docker
   ```

---

## 2. RDS for PostgreSQL（托管）

1. 创建 RDS PostgreSQL 14+，与 ECS 同 VPC、同地域。
2. 白名单：只加 ECS 所在 vSwitch 网段（或 ECS 内网 IP），**不开公网**。
3. 创建数据库 `socialstory`、账号 `ss_prod`（设强密码）。
4. 记下**内网**连接地址，拼成：
   ```
   postgres://ss_prod:<密码>@<rds内网地址>:5432/socialstory?sslmode=require
   ```
   生产强制 `sslmode=require`。
5. 建表无需手动操作：容器首次启动会自动跑 `migrations/`（见 `db.RunMigrations`），并用 `db.GuardEnvironment` 把库打上 `prod` 标记，防止 test/prod 串库。

---

## 3. 云数据库 Redis（托管）

1. 创建 Redis 实例，与 ECS 同 VPC。
2. 设置实例密码，白名单加 ECS 网段。
3. 记下**内网**地址和端口，填到 `REDIS_ADDR` / `REDIS_PASSWORD`。
4. Key 前缀 `ss:prod:` 由服务自动加（`REDIS_KEY_PREFIX`），可与其他环境共享实例而不串数据。

---

## 4. OSS（头像直传）

1. 建 Bucket `socialstory-prod`，地域 `cn-hangzhou`，读写权限**私有**。
2. **CORS 规则**（让 App 能直接 POST 上传）：
   - 来源：App 的请求来源（移动端可用 `*`，或指定域名）
   - 方法：`POST`
   - 允许 Headers：`*`
3. 公网读：头像要可被 App 展示，给 `avatar/` 前缀配只读，或挂 CDN 后把域名填到 `OSS_PUBLIC_HOST`。
4. `OSS_ENDPOINT` 填 `oss-cn-hangzhou.aliyuncs.com`（**不带 `https://`**）。

详见 [aliyun_resources.md](aliyun_resources.md) 的 RAM 与短信小节。

---

## 5. 后续步骤

- RAM 子账号、短信签名/模板申请 → 见 [aliyun_resources.md](aliyun_resources.md)
- 生成 `.env.prod` 与密钥落盘 → 见 [aliyun_resources.md](aliyun_resources.md)
- 构建推镜像、ECS 部署、SLB 配置、验证 → 见 [release_steps.md](release_steps.md)
