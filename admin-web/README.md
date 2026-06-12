# 社交故事 · 管理后台（admin-web）

React + Ant Design + Vite + TypeScript 实现的运营后台，调用 Go 服务端的 `/v1/admin/*` 接口。

## 功能
- 登录（管理员账号，JWT）
- 数据看板（用户/订阅/今日生成）
- 用户管理：搜索、分页、详情（资料/绑定/孩子/订阅/额度）、封禁/解封、调整额度
- 订阅管理：状态/环境/关键字过滤（只读）
- 精选故事：列表、新增（粘贴整段 coze JSON）、删除
- 审计日志：操作流水查询

角色（后端 `admin_users.role`）：
- `super`：全部（含封禁）
- `support`：可调额度、管精选
- `viewer`：只读（写操作按钮隐藏；后端 `requireRole` 同时兜底）

## 环境要求
- Node 18+

## 快速开始
```bash
cd admin-web
cp .env.example .env.local      # 按需改 VITE_API_BASE
npm install
npm run dev                     # http://localhost:5173
```

`.env.local` 里 `VITE_API_BASE` 指向后端地址（默认 `http://localhost:8080`）。

## 与后端联调
1. 起后端：`cd ../server && docker compose up -d`。
2. 设管理员密码（首次，库里口令是占位 bcrypt）：
   ```bash
   # 生成 bcrypt 后更新 admin_users，或用已知账号登录
   docker exec server-postgres-1 psql -U postgres -d socialstory \
     -c "UPDATE admin_users SET password_hash='<bcrypt>' WHERE username='admin';"
   ```
3. `npm run dev`，浏览器打开 5173，用该账号登录。
4. CORS：后端 `ALLOWED_ORIGINS` 默认 `*`（dev 放行）；生产应收敛为后台域名。

## 构建部署
```bash
npm run build      # 产物在 dist/
```
`dist/` 是纯静态文件，托管到任意静态服务 / CDN / 对象存储即可。生产环境把 `VITE_API_BASE` 设为线上 API 域名后再 build。前后端分离，后端无需托管这些静态文件。

## 目录
```
src/
  api/        http 封装（axios + 信封解包 + 鉴权）、接口函数与类型
  auth.ts     token/role 本地存储与角色判断
  components/ AppLayout 布局
  pages/      登录 / 看板 / 用户 / 订阅 / 精选 / 审计
  main.tsx    入口 + 路由 + 鉴权守卫
```
