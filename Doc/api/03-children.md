# Children — 孩子档案

所有接口需 `Authorization`。字段对齐故事生成入参（见 iOS `SSStoryGenerationRequest`），便于「选孩子→自动带出生成参数」。

## 枚举

| 字段 | 取值 |
|---|---|
| gender | `boy` \| `girl` |
| diagnosis_type | `asd`（自闭症）\| `adhd`（多动症）\| `social_anxiety`（社交焦虑）\| `other` |
| language_level | `simple`（简单句）\| `moderate`（复合句）\| `advanced`（复杂句） |

孩子对象：
```json
{
  "child_id": "c_01H9...",
  "name": "乐乐",
  "gender": "boy",
  "birthday": "2019-05-01",
  "age": 6,
  "diagnosis_type": "asd",
  "language_level": "simple",
  "interests": ["恐龙", "火车"],
  "avatar_url": null,
  "created_at": "2026-01-15T03:30:00Z",
  "updated_at": "2026-01-15T03:30:00Z"
}
```
> `age` 由后端依 `birthday` 实时计算返回，客户端只读。

---

## GET /v1/children — 列表

响应：
```json
{ "code": 0, "data": { "children": [ { ...child... } ] } }
```
按 `created_at` 升序。无孩子返回空数组。

---

## POST /v1/children — 新增

请求：
```json
{
  "name": "乐乐",
  "gender": "boy",
  "birthday": "2019-05-01",
  "diagnosis_type": "asd",
  "language_level": "simple",
  "interests": ["恐龙", "火车"]
}
```
| 字段 | 必填 | 校验 |
|---|---|---|
| name | 是 | 1–24 字 |
| gender | 是 | 枚举 |
| birthday | 是 | 过去日期，年龄 2–16 |
| diagnosis_type | 是 | 枚举 |
| language_level | 是 | 枚举 |
| interests | 否 | 字符串数组，≤10 项，每项 ≤16 字 |

响应：`{ "code": 0, "data": { "child": { ...child... } } }`

错误：`4003` 信息不完整、`4004` 超出数量上限（默认 10）。

---

## PUT /v1/children/{child_id} — 修改

请求：同 POST，字段均可选（部分更新）。
响应：返回更新后的 child。
错误：`4001` 不存在、`4002` 非本人。

---

## DELETE /v1/children/{child_id} — 删除（软删）

响应：`{ "code": 0, "message": "ok", "data": null }`
执行 `children.deleted_at = now()`。错误：`4001`、`4002`。
