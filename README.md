# SocialStoryMate（社交故事伴侣）

面向 ASD/ADHD 儿童家长的家庭行为干预辅助工具。通过 AI 生成个性化社交故事，帮助家长在自然情境中支持儿童的社交技能发展。

---

## 仓库结构

```
SocialStories/
├── ios/                        ← iOS App 工程根
│   ├── Workspace/              ← Xcode Workspace 入口（开发从这里打开）
│   ├── TestApp/                ← App 主工程（AppDelegate、图标、配置）
│   ├── SocialStory/            ← 业务功能模块
│   │   ├── SocialStoryCore/    ← 共享核心（数据模型、API 客户端、本地存储）
│   │   ├── StoryGeneration/    ← 故事生成页
│   │   ├── StoryLibrary/       ← 故事库页
│   │   ├── StoryReader/        ← 故事阅读页
│   │   ├── StoryProfile/       ← 子档案 + 个人主页
│   │   ├── StorySubscription/  ← 买断/订阅页
│   │   ├── StoryTemplates/     ← 模板选择页
│   │   └── StorySettings/      ← 设置/帮助页
│   ├── AccountKit/             ← 账号体系（手机号登录，PoC 阶段暂停用）
│   ├── FusionBase/             ← 框架基础层
│   ├── FusionCore/             ← Actor 模型消息调度引擎
│   ├── FusionUI/               ← 页面导航系统
│   ├── CoreService/            ← 网络引擎（基于 libcurl）
│   ├── Utility/                ← 加密、文件、Zip、Lua
│   ├── Enviroment/             ← 环境配置
│   ├── Podfile                 ← CocoaPods 依赖
│   └── *.podspec               ← 各模块 podspec
│
├── server/                     ← Go 后端服务
│   ├── cmd/server/             ← 程序入口（main.go）
│   ├── internal/               ← 业务模块
│   │   ├── auth/               ← 认证（SMS + JWT）
│   │   ├── account/            ← 用户资料
│   │   ├── children/           ← 子档案
│   │   ├── subscription/       ← 订阅/买断（StoreKit 2）
│   │   ├── usage/              ← 配额管理
│   │   ├── stories/            ← 精选故事
│   │   ├── admin/              ← 管理后台 API
│   │   └── platform/           ← 基础设施（db/redis/jwt/sms/oss/appstore）
│   ├── migrations/             ← SQL 数据库迁移文件
│   ├── deploy/                 ← 部署脚本（Docker + 阿里云）
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── Makefile
│
├── admin-web/                  ← 管理后台前端（React + Ant Design）
│   ├── src/
│   │   ├── pages/              ← Dashboard / Users / Featured / Subscriptions / AuditLogs
│   │   └── components/
│   └── package.json
│
└── docs/                       ← 全项目文档（统一入口）
    ├── README.md               ← 文档导航
    ├── 01-architecture.md      ← 整体架构设计
    ├── api/                    ← 服务端接口文档（按模块编号）
    ├── migrations/             ← SQL 迁移文件副本（同 server/migrations/）
    ├── server/                 ← 服务端运维（部署、环境隔离、阿里云）
    ├── product/                ← 产品需求文档
    └── plans/                  ← 技术规划（PoC 方案等）
```

---

## 快速开始

### iOS App

```bash
cd ios
pod install
open Workspace/FusionWorkspace.xcworkspace
```

> 首次运行需配置 `ios/TestApp/TestApp/LocalConfig.plist`（参考同目录的 `LocalConfig.example.plist`），填入后端 base URL。

### 服务端

```bash
cd server
make dev        # 启动本地 Docker 环境（PostgreSQL + Redis + 服务）
make test       # 运行测试套件
```

### 管理后台

```bash
cd admin-web
npm install
npm run dev     # 启动开发服务器
```

---

## 文档导航

| 文档 | 路径 |
|---|---|
| 整体架构 | [docs/01-architecture.md](docs/01-architecture.md) |
| 接口规范 | [docs/api/00-conventions.md](docs/api/00-conventions.md) |
| 产品需求 | [docs/product/](docs/product/) |
| 服务端部署 | [docs/server/](docs/server/) |
| PoC 规划 | [docs/plans/](docs/plans/) |
