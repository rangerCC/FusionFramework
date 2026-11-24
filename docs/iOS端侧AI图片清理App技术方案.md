# iOS 端侧 AI 图片清理 App 产品技术方案

| 项目 | 内容 |
| --- | --- |
| 文档版本 | v1.0 |
| 依据 | `docs/技术方案.txt`（原方案） |
| 技术栈 | Objective-C 为主，iOS 15.0+，基于 FusionFramework（Actor 消息模型）+ CocoaPods |
| 适用读者 | iOS 研发、测试、产品、审核与合规负责人 |

> 本文在原方案基础上补全了产品范围、模块设计、数据结构、接口与测试计划，并修正了原方案中若干与 iOS 实际 API 行为不符的表述。所有修正集中列在[第 13 章](#13-对原方案的修订说明)，正文直接采用修正后的做法。

---

## 目录

1. [产品概述](#1-产品概述)
2. [功能范围](#2-功能范围)
3. [总体架构](#3-总体架构)
4. [识别管线](#4-识别管线)
5. [数据存储](#5-数据存储)
6. [扫描调度与增量更新](#6-扫描调度与增量更新)
7. [界面与交互](#7-界面与交互)
8. [删除流程与安全](#8-删除流程与安全)
9. [权限、隐私与合规](#9-权限隐私与合规)
10. [商业化与内购工程](#10-商业化与内购工程)
11. [性能基线与设备分级](#11-性能基线与设备分级)
12. [测试与质量保障](#12-测试与质量保障)
13. [对原方案的修订说明](#13-对原方案的修订说明)
14. [明确不做的事项](#14-明确不做的事项)
15. [风险清单](#15-风险清单)
16. [里程碑](#16-里程碑)
17. [附录：关键代码](#17-附录关键代码)

---

## 1. 产品概述

### 1.1 定位

基于端侧视觉识别的相册清理工具。产品主张是 **"AI 帮你找到该删的，你来决定删什么"**：

- 所有识别在本机完成，照片不出设备；
- 所有删除由用户在前台确认，删除后进入系统"最近删除"，30 天内可恢复。

### 1.2 目标用户与场景

| 用户 | 典型场景 | 核心诉求 |
| --- | --- | --- |
| 存储告急用户 | 系统提示"iPhone 储存空间已满"，无法拍照或更新系统 | 快速释放大量空间 |
| 重度拍照用户 | 连拍、同一场景拍十几张 | 每组只留最好的一张 |
| 截图/聊天存图用户 | 截图、微信保存图大量堆积，同一张图存了多次 | 找出重复项和过期截图 |
| 换机/备份前整理 | 迁移前想先瘦身 | 一次性大扫除 |

### 1.3 成功标准

| 维度 | 指标 | v1 目标 |
| --- | --- | --- |
| 识别 | 相似组精确率（组内照片确实相似的比例） | ≥ 95% |
| 识别 | 相似组召回率（标注集中的相似对被找出的比例） | ≥ 85% |
| 体验 | 10K 张相册首次扫描出结果（Stage 1） | ≤ 30 秒（A13 及以上） |
| 安全 | 用户反馈"误删"的比例 | 0 起非用户确认的删除 |
| 商业 | 首次扫描完成 → 看到付费页的比例 | ≥ 70% |

精确率优先于召回率。漏掉一组相似照片只是少省一点空间；把不相似的照片分进一组，用户就会怀疑整个产品。

---

## 2. 功能范围

### 2.1 v1 功能清单

| 优先级 | 功能 | 说明 |
| --- | --- | --- |
| P0 | 权限引导 | 价值说明页 → 系统授权弹窗；支持"受限访问" |
| P0 | 全库扫描 + 进度展示 | 首次全量，之后增量 |
| P0 | 重复照片 | 几乎完全相同（含微信多次保存、同图多次导入） |
| P0 | 相似照片 | 连拍、同一场景多张 |
| P0 | 截图 | 系统截图分类，按时间排序 |
| P0 | 组内推荐保留 + 用户确认删除 | 见 4.6、7.4 |
| P0 | 可释放空间预估 | 见 8.4 |
| P0 | 订阅与付费墙 | 首次扫描后展示 |
| P1 | 模糊照片 | 基于清晰度评分 |
| P1 | 大视频 | 按体积排序，不做相似识别 |
| P1 | 后台扫描 | 充电时用 `BGProcessingTask` 预扫描 |
| P2 | 实况照片转静态、视频压缩 | 需要写入新资源，v1 不做 |

### 2.2 v1 不做

- 自动删除、定时清理；
- 云端推理、账号体系、照片上传；
- 以图搜图、全库语义搜索；
- 视频相似度识别。

---

## 3. 总体架构

### 3.1 分层与数据流

```text
┌────────────────────────────────────────────────────────────────┐
│ UI 层（FusionUI 页面，主线程）                                   │
│  首页/授权 → 扫描进度 → 分类列表 → 组详情 → 删除确认 → 付费墙     │
└───────────────▲───────────────────────────────┬────────────────┘
                │ FusionNativeMessageNotification│ FusionNativeMessage
                │ + 扫描进度通知                  ▼
┌────────────────────────────────────────────────────────────────┐
│ 业务层（FusionCore Service / Actor）                            │
│  photoLibService：授权、资产拉取、变更追踪、删除                  │
│  scanService：扫描调度、哈希、特征提取、聚类、推荐保留             │
└───────────────▲───────────────────────────────┬────────────────┘
                │                               │
┌───────────────┴────────────┐   ┌──────────────▼─────────────────┐
│ PhotoKit（唯一事实源）       │   │ 本地索引（SQLite / FMDB）       │
│ PHAsset / PHChange /        │   │ 只存哈希、特征、分组、删除日志    │
│ PHPersistentChange          │   │ 不存原图、不存缩略图文件          │
└────────────────────────────┘   └────────────────────────────────┘
```

贯穿全局的原则：

1. **PhotoKit 是唯一事实源。** 所有缓存以 `PHAsset.localIdentifier` 为键，读取前都可能过期，使用前必须用 PhotoKit 重新校验。
2. **App 只读不写。** 唯一的写操作是用户确认后的 `deleteAssets:`，通过 `PHPhotoLibrary performChanges:` 执行。
3. **单向数据流。** UI 只发消息、只订阅结果，不直接调用 PhotoKit 或数据库。

### 3.2 与 FusionFramework 的映射

新增本地 Pod `PhotoClean`（依赖 FusionBase、FusionCore、Utility、FMDB），页面放在 App target，通过 Lua 注册。

| Service | thread_type | Actor | 职责 |
| --- | --- | --- | --- |
| `photoLibService` | 0（工作线程池） | `authActor` | 查询/请求授权，返回 `PHAuthorizationStatus` |
| | | `syncActor` | 读取 PhotoKit 变更，更新索引中的资产表 |
| | | `deleteActor` | 执行删除、写删除日志 |
| | | `sizeActor` | 计算可释放空间 |
| `scanService` | 0 | `scanActor` | 扫描调度（父消息），拆分批次子消息 |
| | | `hashActor` | Stage 1：取 64px 缩略图，计算 dHash |
| | | `featureActor` | Stage 2：取约 360px 缩略图，提取 FeaturePrint |
| | | `clusterActor` | 构建候选、聚类、推荐保留，写分组表 |
| | | `qualityActor` | P1：清晰度/人脸质量评分 |

**并发控制直接复用 Fusion 的调度能力。** 工作线程池有 CPU 核数 × 2 条线程，对 Vision 来说太多。`scanService` 子类化 `FusionService` 并重写 `canConcurrentExecute:`：当前在途的 `featureActor` 消息数达到上限时返回 NO，消息留到下一轮调度。这样不需要在 Actor 内部再加信号量阻塞工作线程。

**父子消息对应扫描批次。** `scanActor` 收到一条"扫描"父消息后，按 200 张一批派生子消息给 `hashActor`；所有子消息完成后，在 `processCallbackMessage:ParentMessage:` 中派生 `featureActor` 与 `clusterActor` 的子消息。取消扫描时对父消息 `asyncCancelMessage:`，未完成的子消息由框架自动取消。

**Actor 是单实例、可并发执行的。** 单次请求的数据一律放在 `args` 和 `dataTable` 中；Actor 中唯一的共享对象是数据库队列（`FMDatabaseQueue`，内部串行）和 `PHImageManager`（线程安全）。

**进度上报。** Fusion 只在顶层消息完成时发通知，扫描进度需要额外通道：`scanActor` 每完成一批，在主线程 post 一个自定义通知 `PCScanProgressNotification`，`userInfo` 含已处理数、总数、当前阶段。

---

## 4. 识别管线

### 4.1 管线总览

```text
资产元数据（不解码图片，纳秒级）
  ├─ 截图分类：mediaSubtypes 含 PHAssetMediaSubtypePhotoScreenshot
  ├─ 连拍分组：burstIdentifier 相同
  └─ 时间排序：creationDate
        ↓
Stage 1  dHash（64px 缩略图，CPU，约 1–3ms/张）
  ├─ 重复候选：全库多索引哈希，Hamming ≤ 4
  └─ 相似候选：时间窗内相邻照片
        ↓
Stage 2  Vision FeaturePrint（约 360px 缩略图，仅候选照片）
  └─ 候选对的特征距离 ≤ 阈值才确认相似
        ↓
聚类（以组代表为中心，避免链式合并）
        ↓
组内推荐保留（规则打分）
```

### 4.2 元数据预分类

不解码图片就能得到的信息先用掉：

| 信息 | API | 用途 |
| --- | --- | --- |
| 截图 | `asset.mediaSubtypes & PHAssetMediaSubtypePhotoScreenshot` | 截图分类 |
| 连拍 | `asset.burstIdentifier`、`asset.burstSelectionTypes` | 连拍天然成组；系统已标记的 `PHAssetBurstSelectionTypeAutoPick`/`UserPick` 直接作为推荐保留 |
| 收藏 | `asset.isFavorite` | 收藏照片永不进入默认删除建议 |
| 隐藏 | `asset.isHidden` | 默认不展示隐藏照片（用户需在设置中开启） |
| 尺寸 | `pixelWidth`、`pixelHeight` | 重复判定的辅助条件、推荐保留打分 |
| 时间 | `creationDate` | 相似候选的时间窗 |
| 云端状态 | 本地缩略图请求失败（见 4.3） | 标记为"未扫描（仅在 iCloud）" |

拉取时 `PHFetchOptions.includeAllBurstAssets = YES`，否则连拍组只返回代表照片。

### 4.3 缩略图获取

扫描用的缩略图和 UI 用的缩略图分开请求，参数不同：

```objc
PHImageRequestOptions *opt = [[PHImageRequestOptions alloc] init];
opt.synchronous          = YES;   // 在工作线程上同步取图，便于按批次限流
opt.deliveryMode         = PHImageRequestOptionsDeliveryModeHighQualityFormat; // 只回调一次
opt.resizeMode           = PHImageRequestOptionsResizeModeFast;
opt.networkAccessAllowed = NO;    // 扫描绝不触发 iCloud 下载
```

- Stage 1 请求 `64×64` 像素，`PHImageContentModeAspectFill`。
- Stage 2 请求短边约 `360` 像素（Vision 内部还会缩放，再大只增加解码成本，具体尺寸在标定阶段确认）。
- 每张图的处理包在 `@autoreleasepool` 中，否则批处理时 `UIImage`/`CGImage` 会堆积到批次结束才释放。
- 返回 `nil` 且 `info[PHImageResultIsInCloudKey]` 为 YES 时，记为云端资产，不计入扫描失败。

### 4.4 Stage 1：dHash 与候选生成

**算法。** 64px 缩略图 → 9×8 灰度 → 每行比较相邻像素亮度 → 64 位哈希。距离为 `__builtin_popcountll(a ^ b)`。实现见[附录 17.1](#171-dhash)。

dHash 作为粗筛足够：它对缩放、轻微压缩、轻微调色不敏感，对构图变化敏感。后者正是需要 Stage 2 的原因。

**候选来源一：重复照片（全库）。** 同一张图被多次保存，拍摄时间可能相隔数月，因此要做全库比较。不做 O(n²) 两两比较，采用多索引哈希（Multi-Index Hashing）：

- 把 64 位切成 `m = T + 1` 段（T 为 Hamming 阈值）。由鸽巢原理，若两个哈希距离 ≤ T，至少有一段完全相同。
- 每段建一张 `段值 → 资产列表` 的哈希表，查询时只需比较至少一段相同的资产。
- 重复阈值 T = 4，切 5 段（13/13/13/13/12 位）。10K 张时每个桶平均不到 2 个元素，候选比较量在十万次量级，耗时可忽略。

重复判定条件：`Hamming ≤ 4` 且宽高比一致（误差 1% 以内）。命中后仍送 Stage 2 复核一次，防止纯色图、黑屏截图这类低信息量图片被误判为重复（这类图的 dHash 接近全 0 或全 1，需要单独过滤：哈希中 1 的个数 < 4 或 > 60 时不参与重复判定）。

**候选来源二：相似照片（时间窗）。** "同场景不同角度"的 dHash 距离往往很大，靠哈希阈值召不回来。但这类照片几乎总是在短时间内连续拍摄。因此：

- 按 `creationDate` 排序，每张照片与其后 60 秒内、最多 10 张照片组成候选对；
- 连拍（相同 `burstIdentifier`）组内所有照片直接成为候选；
- 候选对全部进入 Stage 2，不再用 dHash 筛掉。

时间窗把 Stage 2 的比较量限制在 O(n × 10)，同时覆盖了哈希漏掉的语义相似。时间窗长度和上限是初始值，在标定集上调整。

### 4.5 Stage 2：Vision FeaturePrint 确认

**选型：** `VNGenerateImageFeaturePrintRequest`（iOS 13+），系统内置，无需打包模型。v1 不叠加自训练投影头，理由见 13 章。

**版本固定。** FeaturePrint 有两个版本，不同版本的特征不可比较：

| revision | 系统 | 维度 | 说明 |
| --- | --- | --- | --- |
| `VNGenerateImageFeaturePrintRequestRevision1` | iOS 13+ | 2048 | 未归一化 |
| `VNGenerateImageFeaturePrintRequestRevision2` | iOS 17+ | 768 | 已 L2 归一化，距离范围更稳定 |

规则：

1. 显式设置 `request.revision`，不依赖系统默认值，防止系统升级后默认版本变化导致新旧特征混算。
2. iOS 17+ 设备用 Revision2，iOS 15/16 用 Revision1；索引中记录 revision。
3. 用户升级到 iOS 17 后，不立即重算全部特征；新特征用 Revision2，跨版本的候选对按需重算旧照片的特征。
4. 两个版本的距离阈值分别标定。

**距离计算。** 优先用系统的 `-[VNFeaturePrintObservation computeDistance:toFeaturePrintObservation:error:]`。持久化时有两种方案：

| 方案 | 存储 | 10K 张（全部提取时） | 说明 |
| --- | --- | --- | --- |
| 归档整个 observation（`NSSecureCoding`） | 原始 float32 + 元数据 | Rev1 约 80MB，Rev2 约 30MB | 可直接调用系统距离函数 |
| 只存向量，转 float16 | `vImageConvert_PlanarFtoPlanar16F` | Rev1 约 40MB，Rev2 约 15MB | 用 vDSP 自行计算 L2 距离 |

采用第二种：只有候选照片才提取特征，实际存储量远低于上表；float16 的数值误差对"是否相似"的二元判定影响很小，但需要在标定集上验证自算距离与系统距离的判定结果一致（一致率 ≥ 99.5%）。

**计算单元。** iOS 17+ 用 `-[VNRequest setComputeDevice:forComputeStage:]` 指定设备，iOS 15/16 保持默认（Vision 自行选择）。`usesCPUOnly` 在 iOS 17 已废弃，不使用。注意 A9/A10 设备没有神经网络引擎，A11 的神经网络引擎不对第三方开放，这些设备上 Vision 跑在 GPU/CPU 上，性能基线要单独定（见 11 章）。

**同时在途数量。** Stage 2 同时在途的请求上限为 2（A12 及以上）或 1（更早机型），由 `scanService canConcurrentExecute:` 控制。

### 4.6 聚类

候选对确认相似后，不能简单地用并查集求连通分量。连通分量有链式效应：A 像 B、B 像 C，但 A 和 C 可能完全不像，长链会把一整天的照片并成一组。

采用"以代表为中心"的贪心聚类：

1. 按时间顺序遍历照片；
2. 对每张照片，在已有的、时间上相邻的组中找代表；与代表的特征距离 ≤ 阈值则加入该组；
3. 否则新建一组，自己成为代表；
4. 组的上限为 50 张，超出则拆分。

重复组单独聚类（重复关系近似可传递，可用并查集），重复组与相似组的照片不重叠：一张照片同时属于两者时只放在重复组。

### 4.7 推荐保留

规则引擎打分，分高者推荐保留。规则透明、可解释，便于在组详情页展示"为什么推荐这张"。

| 顺序 | 规则 | 说明 |
| --- | --- | --- |
| 1 | 收藏 | `isFavorite` 的照片一律推荐保留，可多张 |
| 2 | 连拍系统选择 | `burstSelectionTypes` 含 AutoPick/UserPick |
| 3 | 质量分 | 清晰度（拉普拉斯方差，vImage 实现）+ 人脸质量（`VNDetectFaceCaptureQualityRequest`，仅含人脸的组）；iOS 18+ 可叠加 `VNCalculateImageAestheticsScoresRequest` 的 `overallScore` |
| 4 | 分辨率 | `pixelWidth × pixelHeight` 大者优先 |
| 5 | 非截图 | 同一画面的照片与截图，保留照片 |
| 6 | 时间 | 截图组、重复组保留最新的一张 |

质量分只在相似组内计算，只算一次并入库。推荐结果只是默认标记，用户可以改。

### 4.8 阈值标定

所有阈值（dHash 重复阈值、时间窗、两个 revision 的特征距离阈值、清晰度阈值）都在自建标注集上标定，不使用经验值直接上线：

- 标注集：≥ 20 份真实相册样本（经同意的内部员工相册，标注在本机完成），覆盖连拍、文档翻拍、截图、聊天保存图、风景、人像、宠物；
- 标注单位为照片对：相似 / 重复 / 不相似；
- 选取使精确率 ≥ 95% 的最大阈值；
- 阈值写进远端可下发的配置（复用 `config.zip` 机制）之前，先作为本地常量上线，避免配置错误导致大面积误分组。

---

## 5. 数据存储

### 5.1 原则

- 只存派生数据：哈希、特征向量、评分、分组、删除日志；
- 不存原图、不落盘缩略图文件（缩略图交给 `PHCachingImageManager`）；
- 数据库文件放在 `Library/Application Support/`，设置 `NSURLIsExcludedFromBackupKey`，开启 `NSFileProtectionCompleteUntilFirstUserAuthentication`（需要后台扫描，不能用 `Complete`）；
- 数据库可随时整体丢弃重建，不承载任何不可恢复的用户数据。

### 5.2 表结构（SQLite，FMDB）

```sql
-- 资产索引
CREATE TABLE asset (
    local_id        TEXT PRIMARY KEY,
    creation_ts     REAL,
    modification_ts REAL,          -- 用于 iOS 15 的变更比对
    pixel_w         INTEGER,
    pixel_h         INTEGER,
    media_subtypes  INTEGER,
    burst_id        TEXT,
    burst_sel       INTEGER,
    is_favorite     INTEGER,
    est_bytes       INTEGER,        -- 预估体积，见 8.4
    dhash           INTEGER,        -- 64 位，SQLite INTEGER 为有符号 64 位，按位存取
    scan_state      INTEGER,        -- 0 未扫描 1 已哈希 2 已提特征 3 云端不可用 9 失败
    updated_at      REAL
);
CREATE INDEX idx_asset_creation ON asset(creation_ts);
CREATE INDEX idx_asset_burst    ON asset(burst_id);

-- 特征向量（仅候选照片）
CREATE TABLE feature (
    local_id   TEXT PRIMARY KEY REFERENCES asset(local_id) ON DELETE CASCADE,
    revision   INTEGER NOT NULL,
    dim        INTEGER NOT NULL,
    vec_f16    BLOB NOT NULL,
    quality    REAL                  -- 质量分，可为空
);

-- 分组
CREATE TABLE cluster (
    cluster_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    kind         INTEGER,           -- 1 重复 2 相似 3 截图 4 模糊 5 大视频
    anchor_ts    REAL,              -- 组内最早时间，用于排序
    dirty        INTEGER DEFAULT 0  -- 成员变化后待重算
);
CREATE TABLE cluster_member (
    cluster_id  INTEGER REFERENCES cluster(cluster_id) ON DELETE CASCADE,
    local_id    TEXT    REFERENCES asset(local_id) ON DELETE CASCADE,
    keep_rank   INTEGER,            -- 1 为推荐保留
    PRIMARY KEY (cluster_id, local_id)
);

-- 删除日志（不含图片内容）
CREATE TABLE delete_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id    TEXT,
    local_id    TEXT,
    cluster_id  INTEGER,
    kind        INTEGER,
    est_bytes   INTEGER,
    result      INTEGER,            -- 0 成功 1 用户取消 2 资产已不存在 3 其他错误
    ts          REAL
);

-- 元信息：schema 版本、变更 token、阈值版本
CREATE TABLE meta (key TEXT PRIMARY KEY, value BLOB);
```

`meta` 中保存 `schema_version`、`persistent_change_token`（iOS 16+，`NSKeyedArchiver` 归档）、`threshold_version`。阈值版本变化时，把所有 `cluster` 标记为 dirty，重新聚类，但不重算哈希和特征。

删除日志保留 90 天，超期清理。

---

## 6. 扫描调度与增量更新

### 6.1 首次全量扫描

1. `syncActor` 拉取全部图片资产（`PHAssetMediaTypeImage`，按 `creationDate` 降序），写入 `asset` 表，只读元数据，10K 张约 1 秒内完成；
2. 元数据分类立即可用：截图、连拍分组先展示给用户，降低等待感；
3. `scanActor` 按"最新优先"拆批执行 Stage 1。最近的照片最可能是用户想清理的，先出结果；
4. Stage 1 完成后执行 Stage 2 与聚类；
5. 每批完成即写库（断点），App 被杀或切后台后，下次从 `scan_state` 继续，不从头开始。

### 6.2 增量更新

**App 运行期间：** 注册 `PHPhotoLibraryChangeObserver`。`photoLibraryDidChange:` 在后台队列回调，在回调中：

```objc
PHFetchResultChangeDetails *d = [changeInstance changeDetailsForFetchResult:self.fetchResult];
if (!d) return;
self.fetchResult = d.fetchResultAfterChanges;   // 必须替换为变更后的结果
if (d.hasIncrementalChanges) {
    // insertedObjects / removedObjects / changedObjects → 发 syncActor 消息
} else {
    // 变更无法增量描述：重新比对整表
}
```

`fetchResultAfterChanges` 已包含新增资产，不需要重新发起 fetch。

**跨启动（iOS 16+）：** 用持久化变更追踪。

```objc
NSError *err = nil;
PHPersistentChangeFetchResult *changes =
    [[PHPhotoLibrary sharedPhotoLibrary] fetchPersistentChangesSinceToken:savedToken error:&err];
// 遍历每个 PHPersistentChange：
//   [change changeDetailsForObjectType:PHObjectTypeAsset error:]
//   → insertedLocalIdentifiers / updatedLocalIdentifiers / deletedLocalIdentifiers
// 处理完成后保存 [PHPhotoLibrary sharedPhotoLibrary].currentChangeToken
```

token 过期（`PHPhotosErrorPersistentChangeTokenExpired`）或变更量过大时，退化为整表比对。

**跨启动（iOS 15）：** 没有持久化变更 API。启动时拉取全部资产的 `localIdentifier` 与 `modificationDate`，与 `asset` 表比对，10K 张约 1 秒。

**增量处理规则：**

| 变更 | 处理 |
| --- | --- |
| 新增 | 插入 `asset`，计算 dHash；按时间窗找邻居，必要时提特征；所在时间段的组标记 dirty |
| 修改（`modificationDate` 变化） | 重算 dHash 与特征（编辑后画面可能已变）；所在组标记 dirty |
| 删除 | 删除 `asset` 行（级联删除特征和组成员）；成员数 < 2 的组删除 |

dirty 组在用户进入对应分类页前重算，不在后台反复计算。

### 6.3 后台扫描（P1）

- 注册 `BGProcessingTaskRequest`，`requiresExternalPower = YES`，`requiresNetworkConnectivity = NO`；
- `expirationHandler` 中取消父消息，已完成的批次已写库，不丢进度；
- 后台只做 Stage 1 与 Stage 2，不做聚类以外的 UI 相关计算。

### 6.4 节流与热管理

| 条件 | 行为 |
| --- | --- |
| `NSProcessInfo.thermalState` ≥ `Serious` | 暂停 Stage 2，Stage 1 批间隔加 200ms |
| `thermalState == Critical` | 暂停扫描，界面提示"设备温度较高，已暂停" |
| 低电量模式 | 暂停 Stage 2，用户可手动继续 |
| 收到内存警告 | 清空 `PHCachingImageManager` 缓存，当前批完成后暂停 500ms |
| App 进入后台 | 当前批完成后暂停（有后台任务时由 6.3 接管） |

监听 `NSProcessInfoThermalStateDidChangeNotification` 与 `NSProcessInfoPowerStateDidChangeNotification`，状态写入 `scanService`，`canConcurrentExecute:` 据此放行或挂起消息。

---

## 7. 界面与交互

### 7.1 页面清单

| 页面 | 类 | 说明 |
| --- | --- | --- |
| 首页 | `PCHomePage` | 存储概览、各分类入口、扫描按钮 |
| 授权引导 | `PCAuthGuidePage` | 价值说明 → 系统弹窗；拒绝后引导去设置 |
| 扫描进度 | `PCScanProgressPage` | 分阶段进度、已发现数量实时更新 |
| 分类列表 | `PCClusterListPage` | 某一类的所有组，按可释放空间降序 |
| 组详情 | `PCClusterDetailPage` | 组内全部照片、推荐理由、逐张选择 |
| 大图预览 | `PCPreviewPage` | 左右滑动对比、双指缩放 |
| 删除确认 | `PCDeleteConfirmPage` | 张数、预估空间、iCloud 提示 |
| 付费墙 | `PCPaywallPage` | 订阅档位 |
| 设置 | `PCSettingsPage` | 隐私说明、包含隐藏照片开关、恢复购买 |

所有页面继承 `FusionPageController`，在 `Script/Page/*.lua` 中注册，跳转使用 `FusionPageMessage`。组详情页向删除确认页传递的是 `localIdentifier` 数组，不传 `PHAsset` 对象。

### 7.2 缩略图加载

网格页使用 `PHCachingImageManager`：

- `targetSize` 以像素计：`cellSize × UIScreen.mainScreen.scale`；
- 预热与实际请求使用完全相同的 `targetSize`、`contentMode`、`options`，否则缓存不命中；
- 根据 `UICollectionView` 可见区域上下各扩展一屏作为预热窗口，滚动时计算新增区域 `startCachingImagesForAssets:`、移出区域 `stopCachingImagesForAssets:`（参考 Apple 示例工程的差集算法）；
- 网格请求 `deliveryMode = Opportunistic`、`networkAccessAllowed = NO`；大图预览才允许网络，显示 iCloud 下载进度；
- cell 复用时用 `requestID` 取消旧请求，并在回调中比对 `localIdentifier`，防止错图；
- 离开页面时 `stopCachingImagesForAllAssets`。

### 7.3 扫描进度页

- 分三段展示：读取相册（元数据）→ 快速比对（Stage 1）→ 精细识别（Stage 2）；
- 进度通知节流到每 0.2 秒最多刷新一次 UI；
- 已发现的分类数量实时增长，扫描中即可点进已完成的分类；
- 扫描中可离开页面，扫描继续。

### 7.4 信任设计

| 原则 | 落地 |
| --- | --- |
| 删除必须是显式动作 | 进入组详情时没有任何照片被选中删除；推荐保留的照片带"建议保留"标记 |
| 批量操作也要显式 | 提供"选中本组建议删除项"和"全部分组按建议选择"两个按钮，点击后才会勾选 |
| 推荐可解释 | 推荐保留的照片显示理由标签：最清晰 / 已收藏 / 分辨率最高 / 最新 |
| 收藏受保护 | 收藏照片勾选删除时弹出二次确认 |
| 可以逐张核对 | 每组可展开，大图左右滑动对比 |
| 删除可恢复 | 确认页说明"照片将移到最近删除，30 天内可恢复" |
| 空间数字诚实 | 显示"约 X GB"，并说明清空"最近删除"后才会真正释放（见 8.4） |

---

## 8. 删除流程与安全

### 8.1 流程

```text
用户勾选 → 删除确认页（张数 / 预估空间 / iCloud 同步提示）
   → 用户点"删除"
   → deleteActor：
       1. 用 localIdentifier 重新 fetch，丢弃已不存在的资产
       2. 一次 performChanges 提交全部剩余资产
       3. 系统弹出"允许删除 N 张照片？"
   → 成功：写删除日志，从索引移除，刷新分组
   → 用户在系统弹窗点取消：写日志（result=1），保持勾选状态不变
   → 其他失败：见 8.2
```

### 8.2 错误处理

`performChanges:` 是事务性的：块内任何一个资产删除失败，整个变更都不会生效。不能"逐资产容错"地在一次调用内部跳过失败项；而拆成多次调用，系统会弹多次确认框，体验不可接受。

处理策略：

1. **事前校验：** 提交前 `fetchAssetsWithLocalIdentifiers:` 重新获取，已被删除的资产自然不在结果中；同时检查 `canPerformEditOperation:PHAssetEditOperationDelete`。
2. **失败后重试一次：** 若失败且错误不是用户取消，重新 fetch 后再提交一次（期间资产可能被其他 App 或 iCloud 同步删除）。
3. **仍失败：** 提示用户"部分照片无法删除"，记录日志，不再自动重试。

批量上限：单次最多 500 张。超过时分批，每批前明确提示"将分 N 次确认"，由用户逐次点击。

### 8.3 不做后台删除

所有删除都在前台由用户确认后发起。系统本身也会对每次删除弹出确认框，后台无法完成删除。代码层面 `deleteActor` 在 `UIApplication.applicationState != UIApplicationStateActive` 时直接置 Failed。

### 8.4 可释放空间的计算

| 方法 | 精度 | 风险 |
| --- | --- | --- |
| `PHAssetResource` 的 `fileSize`（通过 KVC 读取） | 准确 | 非公开属性，审核与系统升级均有风险 |
| `PHAssetResourceManager requestDataForAssetResource:` 累加 | 准确 | 需读取完整文件，非常慢，可能触发 iCloud 下载 |
| 按像素数与格式估算（HEIC 约 0.12–0.2 字节/像素，JPEG 约 0.3–0.5 字节/像素，截图 PNG 单独估） | ±30% | 无 |

v1 默认使用估算值，UI 一律显示"约"。`fileSize` KVC 作为可配置开关，默认关闭，上线前评估。

用户必须被告知的事实：

- 删除后照片进入"最近删除"，**空间在清空"最近删除"或 30 天后才释放**。删除成功页提供"如何立即释放空间"的引导（App 无法代替用户清空"最近删除"）。
- 开启 iCloud 照片且"优化 iPhone 储存空间"时，本机只存小尺寸版本，本机实际释放的空间小于原图体积，但 iCloud 空间会释放。
- 开启 iCloud 照片时，删除会同步到用户所有设备。确认页必须写明。

---

## 9. 权限、隐私与合规

### 9.1 照片权限

- 使用 `+[PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:]`（iOS 14+）。删除需要读写权限。
- 首屏不弹权限。授权引导页说明用途，用户点"开始扫描"后才触发系统弹窗。
- `NSPhotoLibraryUsageDescription` 写具体用途，例如："用于在本机识别相似、重复照片和截图，帮你清理相册。照片不会上传。"
- Info.plist 设置 `PHPhotoLibraryPreventAutomaticLimitedAccessAlert = YES`，避免系统在每次启动时自动弹出受限访问选择器，由 App 在合适的位置调用 `presentLimitedLibraryPickerFromViewController:`。

| 授权状态 | 体验 |
| --- | --- |
| `Authorized` | 完整功能 |
| `Limited` | 只扫描已授权照片；首页常驻提示"当前只能访问部分照片"，提供"选择更多照片"和"去设置开启全部访问" |
| `Denied` / `Restricted` | 展示说明页与"去设置"按钮（`UIApplicationOpenSettingsURLString`），不白屏 |
| `NotDetermined` | 授权引导页 |

### 9.2 App Store 审核要点

| 条款 | 要求 | 落地 |
| --- | --- | --- |
| 5.1.1 数据收集与存储 | 隐私标签与实现一致 | 不收集照片内容；分析 SDK 只上报匿名事件（扫描耗时、分组数量区间、付费漏斗），禁用其自动截图/录屏功能 |
| 5.1.1 权限用途 | 用途字符串具体、真实 | 见 9.1 |
| 2.3 元数据准确 | 不夸大功能 | 不使用"加速手机""清理病毒""清理内存"等宣传 |
| 3.1.2 自动续期订阅 | 价格、周期、试用条款清楚展示 | 付费墙展示完整价格、续期说明、隐私政策与使用条款链接、恢复购买 |
| 4.2 最低功能 | 需提供实际价值 | 免费版可完成完整的清理闭环 |

### 9.3 中国大陆上架

- 完成 App 备案（ICP），在 App Store Connect 填写备案号；
- 首次启动先展示隐私政策弹窗，用户同意前不初始化任何第三方 SDK、不采集任何数据；
- 隐私政策列明第三方 SDK 清单及其收集的信息；
- 提供注销与个人信息删除说明（本产品无账号，说明"所有数据存储在本机，卸载即删除"）。

---

## 10. 商业化与内购工程

### 10.1 定价

| 档位 | 参考定价（中国区） | 定位 |
| --- | --- | --- |
| 免费 | 每日可删除 30 张；可查看全部分组 | 完成一次完整闭环，感知价值 |
| 周订阅 | ¥18–28 | 一次性大扫除用户 |
| 年订阅 | ¥128–198 | 主推档位 |
| 终身 | ¥298–398 | 订阅疲劳用户 |

原方案引用的品类收入与竞品定价数据（Appfigures、Cleen、Breezy Cleaner）在立项评审前需要重新核对最新数据。

### 10.2 付费墙位置

- 不在启动时弹出；
- 首次扫描完成、展示"可释放约 X GB"之后，用户点击批量删除或超过免费额度时出现；
- "全部分组按建议选择"作为订阅专属入口。

### 10.3 StoreKit 工程

StoreKit 2 只有 Swift API。方案：

- 新增一个小的 Swift 模块 `PCStore`，用 StoreKit 2 实现商品拉取、购买、`Transaction.updates` 监听、`Transaction.currentEntitlements` 权益判断，通过 `@objc` 类暴露给 Objective-C；
- 权益状态在本地缓存（Keychain），启动时异步刷新，网络不可用时使用缓存；
- 使用 App Store Server Notifications V2 与服务端校验做对账（如无服务端，v1 只依赖 StoreKit 2 的本地 JWS 校验）；
- 使用 StoreKit Configuration 文件做本地测试，覆盖购买、续期、退款、恢复、家庭共享、Ask to Buy。

不选 StoreKit 1：部分接口（如 `appStoreReceiptURL` 收据验证）在新系统中已废弃，长期维护成本更高。

---

## 11. 性能基线与设备分级

### 11.1 设备分级

iOS 15 最低支持到 iPhone 6s，各代芯片的 Vision 性能差距很大，基线按档位分别定义：

| 档位 | 芯片 | 代表机型 | Stage 2 设备 |
| --- | --- | --- | --- |
| 高 | A14 及以上 | iPhone 12 及以上 | 神经网络引擎 |
| 中 | A12–A13 | iPhone XS / 11 | 神经网络引擎 |
| 低 | A9–A11 | iPhone 6s / 7 / 8 / X | GPU / CPU |

低档设备的 Stage 2 只在用户进入相似分类时按需计算，不在首扫中跑完全库。

### 11.2 指标

测量条件：真机，真实相册 10K 张图片，Release 包，设备温度正常，非模拟器。

| 指标 | 高档 | 中档 | 低档 | 测量方式 |
| --- | --- | --- | --- | --- |
| 元数据同步 | ≤ 1s | ≤ 2s | ≤ 3s | signpost |
| Stage 1 全量 | ≤ 20s | ≤ 30s | ≤ 60s | os_signpost + Time Profiler |
| Stage 2 单张特征提取 | ≤ 20ms | ≤ 40ms | ≤ 150ms | Vision signpost |
| 网格滚动 | 60fps，无掉帧 >3 帧 | 同左 | 允许偶发掉帧 | Animation Hitches |
| 网格滚动峰值内存 | ≤ 80MB | ≤ 80MB | ≤ 60MB | VM Tracker / Allocations |
| 扫描期间常驻内存 | ≤ 150MB | ≤ 150MB | ≤ 120MB | Allocations |
| 增量扫描（新增 < 100 张） | ≤ 2s | ≤ 3s | ≤ 5s | 变更回调到分组更新 |
| 删除 100 张 | ≤ 3s（不含系统弹窗等待） | 同左 | ≤ 5s | performChanges 回调 |
| 20 轮连续扫描吞吐保持 | ≥ 60% 峰值 | 同左 | — | 热衰减测试 |

在代码中为每个阶段埋 `os_signpost`，便于用 Instruments 直接对比。

### 11.3 性能偏差的排查顺序

1. 是否有照片绕过了 Stage 1/时间窗，直接进入 Stage 2；
2. Stage 2 的缩略图尺寸是否过大；
3. 是否在 Vision 请求外层漏了 `@autoreleasepool`；
4. 同时在途的 Vision 请求是否超出上限，导致排队和发热；
5. 是否误把扫描放在了主线程或 `UI` 类型的 Service 上。

---

## 12. 测试与质量保障

### 12.1 识别质量

- 标注集见 4.8，作为离线评估集，每次修改阈值或管线都要跑一遍；
- 评估工具：一个 Debug 页面，读取标注文件，在真机上跑完整管线，输出精确率、召回率、混淆样例；
- 回归门槛：精确率不得下降超过 0.5 个百分点。

### 12.2 单元测试

| 对象 | 用例 |
| --- | --- |
| dHash | 同图不同尺寸距离 ≤ 2；纯色图被低信息量过滤；旋转 90° 距离大 |
| 多索引哈希 | 随机数据下与暴力比较结果完全一致 |
| 聚类 | 构造链式样本 A~B~C，验证 A、C 不因 B 合并 |
| 推荐保留 | 每条规则的优先级 |
| 增量处理 | 插入、修改、删除后分组正确更新 |
| 数据库迁移 | 从每个历史 schema 版本升级 |

### 12.3 PhotoKit 场景测试

在测试设备上准备专用相册，覆盖：

- 受限访问下的扫描与"选择更多照片"；
- 扫描中途切后台、被系统杀死后恢复；
- 扫描中用系统相册删除/新增照片；
- iCloud 仅云端的照片；
- 删除时在系统弹窗点取消；
- 删除前资产已被其他设备删除；
- 收藏照片的删除二次确认；
- iOS 15、16、17、18 及当前最新系统各一台设备。

### 12.4 稳定性

- 50K 张相册的压力测试（内存峰值、扫描是否完成）；
- 扫描期间反复进出页面 100 次，检查内存泄漏（Leaks、Memory Graph）；
- 线上接入崩溃收集，崩溃率目标 < 0.1%。

---

## 13. 对原方案的修订说明

| 原方案表述 | 问题 | 本方案做法 |
| --- | --- | --- |
| 用多表哈希把 Hamming ≤ 8 的图片映射到同一桶 | dHash 本身不是局部敏感哈希，需要说明分段规则；且 ≤ 8 的阈值做全库重复判定误报偏高 | 鸽巢原理分段的多索引哈希，全库阈值收紧到 4；相似照片改由时间窗召回（4.4） |
| pHash 粗筛后才进入 Vision 精排 | "同场景不同角度"恰恰是 dHash 距离大的情况，粗筛会把它们筛掉 | 相似候选来自时间窗，不经 dHash 过滤，直接进入 Stage 2（4.4） |
| FeaturePrint 与 Core ML 投影头融合为单次 ANE 调度，每次省 8–12ms | Vision 请求与 Core ML 预测是两次独立调用，无法融合；v1 也没有投影头的必要 | v1 直接用 FeaturePrint 距离，投影头留待数据证明召回不足时再做（4.5） |
| 512 维嵌入、float16 与 INT8 的 Recall 对比数据 | 系统 FeaturePrint 是 2048 维（Rev1）或 768 维（Rev2），引用数据与实际模型不符 | 保留 float16 存储思路，在自有标注集上验证判定一致率（4.5） |
| 通过 `usesCPUOnly = false` 让 ANE 调度 | `usesCPUOnly` 在 iOS 17 已废弃；A9–A11 设备第三方无法使用神经网络引擎 | iOS 17+ 用 `setComputeDevice:forComputeStage:`；按设备分级定基线（4.5、11.1） |
| 16 permit 的 async 信号量 | Swift Concurrency 的写法，与本项目的 Objective-C + Fusion 线程模型不匹配；对 Vision 来说 16 也过高 | 通过 `canConcurrentExecute:` 控制在途数量，Stage 2 上限 1–2（3.2、4.5） |
| PHFetchResult 快照中看不到新插入资产，需要主动开启新的 fetch session | 变更回调中的 `fetchResultAfterChanges` 已包含新资产 | 用 `fetchResultAfterChanges` 替换旧结果；跨启动用 iOS 16 的持久化变更追踪（6.2） |
| 批量删除逐 asset 容错，不能因一个失败回滚整批 | `performChanges:` 是事务性的；拆分调用会导致系统多次弹确认框 | 事前重新 fetch 过滤，失败后重试一次（8.2） |
| 确认页展示"将释放 X GB" | 删除后进入"最近删除"，空间不会立即释放；iCloud 优化存储下本机释放量更小；精确体积需非公开 API | 显示"约 X GB"并说明释放条件（8.4） |
| 推荐保留规则未考虑收藏，连拍需自行评分 | 删除收藏照片是最严重的信任事故；系统已提供连拍推荐 | 收藏最高优先级且受保护；连拍优先使用 `burstSelectionTypes`（4.7） |
| 优先保留"非编辑版本" | 系统相册中编辑是在同一资产上完成的，编辑后的版本通常是用户想要的 | 去掉该规则，由质量分与分辨率决定 |
| 默认不预选删除，只预选推荐保留 | 与"AI 一键清理"付费入口需要协调 | 默认不勾选，提供显式的"按建议选择"按钮（7.4） |
| 网格滚动峰值内存 ≤ 50MB | 对 3x 屏幕、多列网格偏紧，未区分机型 | 按设备档位定义，高中档 ≤ 80MB（11.2） |
| 未提及中国区合规 | 原方案以中国市场为主 | 补充备案与隐私政策要求（9.3） |
| 未提及 StoreKit 的语言限制 | StoreKit 2 仅 Swift | Swift 桥接模块（10.3） |

---

## 14. 明确不做的事项

| 事项 | 原因 |
| --- | --- |
| 引入 OpenCV | Vision、Core ML、Accelerate（vImage/vDSP）已覆盖哈希、特征、清晰度计算；OpenCV 增加 10MB 以上包体积和 C++ 桥接 |
| v1 自动删除 | 信任模型不允许；系统也要求每次删除由用户确认 |
| HNSW/ANN 索引 | 时间窗 + 多索引哈希后的比较规模很小，索引维护成本大于收益；只有做"以图搜图"时才需要 |
| 云端推理 | 隐私标签、审核、离线可用性同时变差，与产品主张冲突 |
| 自建回收站 | 系统"最近删除"是用户已经理解和信任的机制 |
| v1 自训练相似度模型 | 先用标注集证明 FeaturePrint 在某类图片上召回不足，再用 Create ML 训练投影头 |

---

## 15. 风险清单

| 风险 | 概率 | 影响 | 应对 |
| --- | --- | --- | --- |
| 误分组导致用户误删 | 中 | 高 | 精确率门槛 ≥ 95%；默认不勾选；收藏保护；最近删除可恢复 |
| `fileSize` KVC 被审核拒绝或系统升级失效 | 中 | 中 | 默认使用估算值，KVC 只作开关 |
| 低端机 Stage 2 过慢、发热 | 高 | 中 | 设备分级，低档按需计算；热状态节流 |
| 用户对"释放空间"数字不满（未清空最近删除） | 高 | 中 | 显示"约"；删除后引导清空最近删除 |
| 受限访问下功能价值低，转化差 | 中 | 中 | 明确提示，引导开启完整访问 |
| FeaturePrint 版本升级导致阈值失效 | 低 | 中 | 显式固定 revision，按版本标定阈值 |
| 竞品同质化 | 高 | 中 | 以识别精确率和删除安全作为差异点，体现在评价与截图中 |

---

## 16. 里程碑

工期为单人 iOS 开发的粗估，需在 M0 结束后根据验证结果修正。

| 阶段 | 周期 | 交付 | 退出标准 |
| --- | --- | --- | --- |
| M0 技术验证 | 2 周 | dHash、多索引、时间窗、FeaturePrint 的 Demo；标注集首版 | 精确率 ≥ 90%；中档机 Stage 1 ≤ 40s / 10K |
| M1 核心链路 | 4 周 | 权限、全量扫描、重复/相似/截图分类、组详情、删除 | 12.3 场景测试通过 |
| M2 增量与体验 | 3 周 | 增量更新、缓存与滚动优化、热管理、推荐保留 | 11.2 指标达标 |
| M3 商业化与合规 | 2 周 | StoreKit 2、付费墙、隐私政策、备案材料 | 沙盒购买全场景通过 |
| M4 灰度 | 2 周 | TestFlight 外测，阈值调整 | 崩溃率 < 0.1%；无误删反馈 |
| v1.1 | — | 模糊照片、大视频、后台扫描 | — |

---

## 17. 附录：关键代码

以下代码均为 Objective-C，遵循项目 `SafeARC.h` 约定（示例按 ARC 书写）。

### 17.1 dHash

```objc
#import <CoreGraphics/CoreGraphics.h>

/// 输入应为已缩小的图片（如 PhotoKit 返回的 64px 缩略图）。
/// 返回 0 且 *ok == NO 表示失败。
static uint64_t PCDHash(CGImageRef image, BOOL *ok) {
    const size_t w = 9, h = 8;
    uint8_t pixels[9 * 8] = {0};

    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(pixels, w, h, 8, w, gray, kCGImageAlphaNone);
    CGColorSpaceRelease(gray);
    if (!ctx) { if (ok) *ok = NO; return 0; }

    CGContextSetInterpolationQuality(ctx, kCGInterpolationMedium);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), image);
    CGContextRelease(ctx);

    uint64_t hash = 0;
    for (size_t y = 0; y < h; y++) {
        for (size_t x = 0; x < w - 1; x++) {
            hash <<= 1;
            if (pixels[y * w + x] < pixels[y * w + x + 1]) hash |= 1;
        }
    }
    if (ok) *ok = YES;
    return hash;
}

static inline int PCHamming(uint64_t a, uint64_t b) {
    return __builtin_popcountll(a ^ b);
}

/// 低信息量图片（纯色、黑屏）不参与重复判定
static inline BOOL PCHashIsInformative(uint64_t h) {
    int ones = __builtin_popcountll(h);
    return ones >= 4 && ones <= 60;
}
```

### 17.2 多索引哈希（阈值 4，切 5 段）

```objc
static const int kPCSegCount = 5;
static const int kPCSegBits[kPCSegCount] = {13, 13, 13, 13, 12};

static inline uint32_t PCSegment(uint64_t h, int i) {
    int shift = 0;
    for (int k = 0; k < i; k++) shift += kPCSegBits[k];
    return (uint32_t)((h >> shift) & ((1ULL << kPCSegBits[i]) - 1));
}

/// tables[i]：NSMutableDictionary<NSNumber *段值, NSMutableArray<NSNumber *资产下标> *>
/// 查询时对 5 段分别取桶，合并去重后逐个计算 Hamming 距离，≤ 4 的为重复候选。
```

### 17.3 FeaturePrint 提取

```objc
#import <Vision/Vision.h>

- (VNFeaturePrintObservation *)featurePrintForImage:(CGImageRef)image
                                        orientation:(CGImagePropertyOrientation)orientation
                                           revision:(NSUInteger *)outRevision
                                              error:(NSError **)error {
    VNGenerateImageFeaturePrintRequest *req = [[VNGenerateImageFeaturePrintRequest alloc] init];
    req.imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFill;

    if (@available(iOS 17.0, *)) {
        req.revision = VNGenerateImageFeaturePrintRequestRevision2;
    } else {
        req.revision = VNGenerateImageFeaturePrintRequestRevision1;
    }
    if (outRevision) *outRevision = req.revision;

    VNImageRequestHandler *handler =
        [[VNImageRequestHandler alloc] initWithCGImage:image orientation:orientation options:@{}];
    if (![handler performRequests:@[req] error:error]) return nil;
    return (VNFeaturePrintObservation *)req.results.firstObject;
}
```

距离：

```objc
float distance = 0;
NSError *err = nil;
BOOL ok = [obsA computeDistance:&distance toFeaturePrintObservation:obsB error:&err];
// revision 不同时 ok == NO，需要重算旧特征
```

### 17.4 删除

```objc
- (void)deleteAssetsWithIdentifiers:(NSArray<NSString *> *)ids
                         completion:(void (^)(BOOL success, NSError *error, NSUInteger count))completion {
    PHFetchResult<PHAsset *> *alive = [PHAsset fetchAssetsWithLocalIdentifiers:ids options:nil];
    NSMutableArray<PHAsset *> *targets = [NSMutableArray arrayWithCapacity:alive.count];
    [alive enumerateObjectsUsingBlock:^(PHAsset *a, NSUInteger idx, BOOL *stop) {
        if ([a canPerformEditOperation:PHAssetEditOperationDelete]) [targets addObject:a];
    }];
    if (targets.count == 0) { completion(YES, nil, 0); return; }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest deleteAssets:targets];
    } completionHandler:^(BOOL success, NSError *error) {
        // 回调在任意队列；结果交给 deleteActor 切回 Fusion 线程处理
        // 用户取消：error.domain == PHPhotosErrorDomain && error.code == PHPhotosErrorUserCancelled
        completion(success, error, targets.count);
    }];
}
```

### 17.5 扫描 Service 的并发控制

```objc
@interface PCScanService : FusionService
@end

@implementation PCScanService {
    atomic_int _featureInFlight;   // featureActor 在途数
    atomic_bool _paused;           // 热状态、低电量、后台
}

- (BOOL)canConcurrentExecute:(FusionNativeMessage *)message {
    if (atomic_load(&_paused)) return NO;
    if ([message.actor isEqualToString:@"featureActor"]) {
        return atomic_load(&_featureInFlight) < PCFeatureConcurrencyLimit();
    }
    return YES;
}

@end
```

`featureActor` 开始处理时递增、置 Finish/Failed 前递减计数（通过 Service 暴露的方法）。`PCFeatureConcurrencyLimit()` 按设备档位返回 1 或 2。

### 17.6 Lua 配置

```lua
-- PhotoClean/Script/Service/ScanService.lua
local service = FusionService.new("scanService", "PCScanService")
service.thread_type = 0
service:addActor(FusionActor.new("scanActor",    "PCScanActor"))
service:addActor(FusionActor.new("hashActor",    "PCHashActor"))
service:addActor(FusionActor.new("featureActor", "PCFeatureActor"))
service:addActor(FusionActor.new("clusterActor", "PCClusterActor"))
service:addActor(FusionActor.new("qualityActor", "PCQualityActor"))
register_logic_service(service)
```

```lua
-- PhotoClean/Script/Page/ClusterDetail.lua
local page = Page.new("ClusterDetail", "PCClusterDetailPage", "cluster_detail")
page:addCommand("init")
page:addCommand("refresh")
register_page(page)
```
