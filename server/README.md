# Social Story 账号后台服务

Go + Gin 实现的账号/订阅后台，落地 [`Doc/`](../Doc/) 中的 API 契约。模块化单体，单进程内分模块。

## 模块

```
cmd/server            启动与路由装配
internal/
  config              环境变量配置
  auth                发码 / 登录 / 刷新 / 登出
  account             资料 / 头像直传 / 绑定查询 / 注销
  children            孩子档案 CRUD
  subscription        权益查询 / 交易校验 / Apple 通知
  usage               免费额度（按账户按月，原子消费）
  admin               后台：用户 / 额度 / 封禁 / 看板
  platform/           httpx, jwtx, idgen, db(pgx), redisx, sms, oss, appstore
  util                手机号校验 / 掩码 / 哈希 / 随机码
migrations            建表脚本（启动时自动执行）
```

## 快速开始

```bash
docker compose up --build -d
curl http://localhost:8080/healthz
```

详见 [docs/local-deploy.md](docs/local-deploy.md) 与 [docs/aliyun-deploy.md](docs/aliyun-deploy.md)。

## 接口

全部接口契约见 [`Doc/api/`](../Doc/api/)。统一响应信封：
```json
{ "code": 0, "message": "ok", "data": {}, "request_id": "..." }
```

## 状态说明

核心账号能力（登录/账户/孩子/额度/后台）已实现。以下为**可编译脚手架**，接真实服务前不可用于生产（代码内 TODO 标注）：
- 阿里云短信实际发送（dev 模式用固定验证码联调）
- OSS 直传 policy 签名
- App Store JWS 验签 + Server API 调用

本期按产品决策：仅手机号登录；微信/Apple 登录接口已预留但返回「未开放」。
