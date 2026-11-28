# Featured Stories — 精选故事

服务端托管的精选故事，运营可随时增删。App 启动 / 下拉刷新时拉取，**仅当列表变更时才返回数据**（ETag / 304），否则用本地缓存。

- 列表获取 `GET /v1/featured-stories`：**公开**，无需鉴权。
- 插入 / 删除：需 **管理员 token**（`Authorization: Bearer <admin_access_token>`，见 [06-admin.md](06-admin.md) 的 `/v1/admin/login`）。

每条精选故事完整保存一段 coze 故事 JSON（`raw`，无损），另抽出 `title / image_url / word_count` 供列表展示与索引。

---

## 变更检测（ETag / 304）

列表的 `ETag` 由服务端按「记录数 + 最新更新时间」派生：任意插入/删除都会改变它。

流程：
1. App 首次 `GET /v1/featured-stories` → `200` + 响应头 `ETag` + 完整列表；App 把列表落本地、把 ETag 存起来。
2. 之后每次请求带上 `If-None-Match: <上次的ETag>`：
   - 列表**无变更** → `304 Not Modified`，**无响应体**，App 继续用本地缓存。
   - 列表**有变更** → `200` + 新 `ETag` + 新列表，App 全量替换本地并刷新页面。

> ETag 形如 `"a1b2c3..."`（带双引号，符合 HTTP 规范）。`If-None-Match` 原样回传即可。

---

## GET /v1/featured-stories — 获取精选故事列表

**公开接口。**

请求头（可选）：
| 头 | 说明 |
|---|---|
| If-None-Match | 上次拿到的 ETag；命中则返回 304 |

响应 `200`：
```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "etag": "\"a1b2c3d4...\"",
    "stories": [
      {
        "story_id": "feat_osns3m6r2c5j9sa8",
        "title": "我和爸爸妈妈去聚餐",
        "image_url": "https://.../img1.jpg",
        "word_count": 75,
        "created_at": "2026-06-11T13:13:22Z",
        "raw": { "story_title": "我和爸爸妈妈去聚餐", "pages": [ ... ], "parent_guide": { ... }, "voice_params": { ... }, "...": "完整 coze JSON" }
      }
    ]
  }
}
```
响应头同时带 `ETag`。

| data 字段 | 类型 | 说明 |
|---|---|---|
| etag | string | 当前列表指纹；App 存下，下次放入 If-None-Match |
| stories[].story_id | string | 精选故事 ID（`feat_` 前缀） |
| stories[].title | string | 标题（从 raw.story_title 抽取） |
| stories[].image_url | string | 首页插图（raw.pages[0].illustration_url） |
| stories[].word_count | int | 各页 content 字数之和 |
| stories[].created_at | string | 入库时间 (RFC3339) |
| stories[].raw | object | **完整 coze 故事 JSON**，App 落 raw_json 无损保存 |

响应 `304`：无响应体（列表未变）。

错误：通用 5xx（服务端异常）。本接口无业务错误码。

---

## POST /v1/admin/featured-stories — 新增精选故事

**需管理员 token。**

请求：
```json
{
  "sort": 1,
  "raw": { "story_title": "我和爸爸妈妈去聚餐", "pages": [ { "page_number": 1, "content": "...", "illustration_url": "https://..." } ], "...": "完整 coze JSON" }
}
```
| 字段 | 必填 | 说明 |
|---|---|---|
| raw | 是 | 完整 coze 故事 JSON 对象；至少含 `story_title` 和非空 `pages` |
| sort | 否 | 展示排序（升序，默认 0） |

服务端从 `raw` 抽取 `title=raw.story_title`、`image_url=raw.pages[0].illustration_url`、`word_count=Σ len(pages[].content)`，并原样保存 `raw`。

响应 `200`：
```json
{ "code": 0, "message": "ok", "data": { "story_id": "feat_osns3m6r2c5j9sa8", "title": "我和爸爸妈妈去聚餐" } }
```

错误：
| code | HTTP | 说明 |
|---|---|---|
| 7001 | 400 | 故事数据格式错误（raw 缺失 / 无 story_title / pages 为空 / JSON 非法） |
| 9001 | 401 | 管理员未登录 |
| 1001 | 400 | 请求体 JSON 解析失败 |

---

## DELETE /v1/admin/featured-stories/{story_id} — 删除精选故事

**需管理员 token。**

路径参数：`story_id`（`feat_` 开头的精选故事 ID）。

响应 `200`：`{ "code": 0, "message": "ok", "data": null }`

错误：
| code | HTTP | 说明 |
|---|---|---|
| 7002 | 404 | 故事不存在 |
| 9001 | 401 | 管理员未登录 |

---

## 测试调用示例（curl）

```bash
BASE=http://localhost:8080

# 0) 取管理员 token
TOKEN=$(curl -s -X POST $BASE/v1/admin/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"<your-password>"}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])")

# 1) 新增一条精选故事（raw 为完整 coze JSON，此处简化）
curl -s -X POST $BASE/v1/admin/featured-stories \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"sort":1,"raw":{"story_title":"我和爸爸妈妈去聚餐","pages":[{"page_number":1,"content":"今天我和爸爸妈妈去餐厅吃饭","illustration_url":"https://x/img1.jpg"}]}}'

# 2) 获取列表（记下响应头 ETag）
curl -i $BASE/v1/featured-stories

# 3) 带 If-None-Match 再次请求 —— 列表没变会返回 304
curl -i -H 'If-None-Match: "<上一步的ETag>"' $BASE/v1/featured-stories

# 4) 删除（story_id 为列表里的 feat_xxx）
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" \
  $BASE/v1/admin/featured-stories/feat_osns3m6r2c5j9sa8

# 5) 删除后 ETag 变化，第 3 步的 If-None-Match 将不再命中，返回 200 + 新列表
```
