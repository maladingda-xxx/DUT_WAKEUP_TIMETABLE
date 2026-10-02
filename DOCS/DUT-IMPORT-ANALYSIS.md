# 大连理工大学教务系统课程导入 — 技术方案文档

> **版本**: v1.1  
> **日期**: 2026-07-14  
> **更新**: 通过浏览器 DevTools 抓包确认了教务系统实际数据结构  
> **目标**: 学生输入学号+密码后一键导入课程到 Wake Up 课程表  

---

## 目录

1. [系统架构分析](#1-系统架构分析)
2. [登录认证流程](#2-登录认证流程)
3. [课程查询接口](#3-课程查询接口)
4. [网络请求流程](#4-网络请求流程)
5. [课程数据解析](#5-课程数据解析)
6. [自动导入方案设计](#6-自动导入方案设计)
7. [安全与合规](#7-安全与合规)
8. [开发路线](#8-开发路线)

---

## 1. 系统架构分析

### 1.1 大连理工大学教务系统全景

```
┌─────────────────────────────────────────────────────────┐
│                      学生 / 教师                         │
└──────────┬──────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────┐
│  统一身份认证平台 (SSO)                                   │
│  URL: https://sso.dlut.edu.cn                           │
│  ────────────────────────────────────────────────       │
│  认证方式:                                                │
│  · 账号密码（学号 + 统一身份认证密码）                      │
│  · 短信验证码                                             │
│  · i大工 App 扫码登录                                     │
│  ────────────────────────────────────────────────       │
│  密码规则: 长度 10-24 位，必须含数字、字母、特殊符号        │
└──────────┬──────────────────────────────────────────────┘
           │ 认证通过，携带 Token 跳转
           ▼
┌─────────────────────────────────────────────────────────┐
│  教务处门户                                               │
│  URL: https://teach.dlut.edu.cn                         │
│  ────────────────────────────────────────────────       │
│  功能: 通知公告、选课入口、成绩查询入口等                    │
└──────────┬──────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────┐
│  综合教务管理系统（新版 — 正方教务系统）                    │
│  入口: teach.dlut.edu.cn → "综合教务管理系统（新版）       │
│        学生入口"                                          │
│  ────────────────────────────────────────────────       │
│  技术栈: ASP.NET (新版) 或 JSP (旧版)                     │
│  基础框架: 正方教务管理系统 (Zhengfang)                    │
│  ────────────────────────────────────────────────       │
│  功能模块:                                                │
│  · 学生选课中心                                           │
│  · 学生课表查询                                           │
│  · 学生成绩查询                                           │
│  · 考试安排查询                                           │
│  · 培养方案查询                                           │
│  · 教学评价                                               │
└─────────────────────────────────────────────────────────┘
```

### 1.2 关键技术特征

| 特性 | 说明 |
|------|------|
| **认证层** | 教务系统内置登录（可能对接 SSO），Cookie-based Session |
| **教务系统** | 新版正方教务管理系统（已确认） |
| **Base URL** | `http://jxgl.dlut.edu.cn`（已确认） |
| **课表页面** | `/student/for-std/course-table`（已确认 GET 返回 HTML） |
| **编码** | UTF-8 |
| **会话管理** | Cookie: `SESSION`, `INGRESSCOOKIE`, `SERVERNAME` |
| **数据格式** | JSON（`lessons` 数组结构，已确认） |
| **反爬机制** | 无验证码（已登录状态下），需有效 Session Cookie |
| **VPN 限制** | 校外访问可能需通过 VPN |

### 1.3 已确认的 API 数据结构

通过浏览器 DevTools 抓包，确认课表数据为 `lessons` 数组结构：

```json
{
  "lessons": [
    {
      "id": 950086,
      "nameZh": "教学班名称",
      "course": {
        "id": 130027,
        "nameZh": "面向对象方法程序设计及实训",
        "code": "1000308490010",
        "credits": 4
      },
      "teacherAssignmentList": [
        {
          "person": { "id": 98317, "nameZh": "田琳琳" },
          "role": "MAJOR"
        }
      ],
      "scheduleText": {
        "dateTimePlacePersonText": {
          "text": "1~2周 周一 第一节~第四节 开发区校区 A-513 田琳琳; ..."
        },
        "dateTimePlaceText": {
          "text": "1~2周 周一 第一节~第四节 开发区校区 A-513; ..."
        }
      },
      "courseType": { "nameZh": "其它实践环节" },
      "campus": { "nameZh": "开发区校区" }
    }
  ],
  "lessonIds": [950086],
  "weekIndices": [1, 2, 3, 4],
  "currentWeek": 3
}
```

**关键字段映射**：
| 教务字段路径 | App 模型 |
|---|---|
| `lesson.course.nameZh` | Course.name |
| `lesson.course.code` | Course.code |
| `lesson.course.credits` | Course.credits |
| `lesson.teacherAssignmentList[].person.nameZh` | Course.teacherName |
| `lesson.scheduleText.dateTimePlacePersonText.text` | 解析 → [ScheduleInput] |
| `lesson.courseType.nameZh` | Course.courseType |
| `lesson.campus.nameZh` | Course.location (校区) |

**scheduleText 格式**：
```
1~2周 周一 第一节~第四节 开发区校区 A-513 田琳琳;
3~4周 周一 第一节~第四节 开发区校区 A-513 刘金鹏;
3~4周 周一 第五节~第八节 开发区校区 A-515 刘金鹏
```
解析为：`(startWeek, endWeek)` + 星期 + `(startPeriod, endPeriod)` + 地点 + 教师，按分号分隔。

---

## 2. 登录认证流程

### 2.1 双阶段认证模型

```
阶段一: 统一身份认证 (SSO)
  │
  ├── 1. GET https://sso.dlut.edu.cn/login
  │      → 获取登录页面，提取 CSRF Token、Cookie
  │
  ├── 2. POST https://sso.dlut.edu.cn/login
  │      → 提交: 学号 + 密码 + CSRF Token
  │
  └── 3. 302 重定向 → 携带 Ticket 跳转至教务系统
         │
阶段二: 教务系统会话建立
  │
  ├── 4. GET 教务系统入口 (携带 Ticket)
  │      → 教务系统验证 Ticket，建立 Session
  │
  ├── 5. 获取 __VIEWSTATE（ASP.NET 页面状态）
  │
  └── 6. 后续请求携带 Session Cookie + __VIEWSTATE
         → 可访问课表、成绩等页面
```

### 2.2 正方教务系统直接登录（备选方案）

部分高校的正方教务系统跳过了 SSO，直接使用正方内置登录。流程如下：

```
1. GET {base_url}/default2.aspx
   → 提取 __VIEWSTATE、验证码图片 URL

2. GET {base_url}/CheckCode.aspx (Cookie 必须一致)
   → 获取验证码图片（需 OCR 或手动输入）

3. POST {base_url}/default2.aspx
   → 请求体:
     __VIEWSTATE: {viewState}
     txtUserName: {学号}
     TextBox2: {RSA加密后的密码}
     txtSecretCode: {验证码}
     RadioButtonList1: "学生" (GB2312编码)
     Button1: ""
     lbLanguage: ""
   → 成功则返回 302 重定向到主页
```

### 2.3 RSA 密码加密

新版正方系统使用 RSA 公钥加密密码：

```
1. 从登录页面 HTML 中提取 RSA 公钥模数 (modulus) 和指数 (exponent)
   → 通常在隐藏的 <input> 标签或 JavaScript 变量中

2. 密码加密:
   ciphertext = RSA_encrypt(
     password,
     public_key=(modulus, exponent)
   )
   → 输出为 Base64 或 Hex 编码的密文

3. 将密文填入 TextBox2 字段提交
```

### 2.4 验证码识别方案

| 方案 | 实现难度 | 成功率 | 说明 |
|------|---------|--------|------|
| **手动输入** | 低 | 100% | 首次导入时弹出验证码让用户输入，UX 可接受 |
| **OCR 识别** | 中 | ~70% | 使用本地 OCR 模型（如 PaddleOCR）自动识别 |
| **打码平台** | 中 | ~95% | 接入第三方打码服务（成本约 ¥0.01/次） |
| **Cookie 复用** | 低 | 100% | 首次手动登录后缓存 Cookie，过期前复用 |

**推荐方案**: **手动输入 + Cookie 缓存**。首次导入弹出验证码让用户输入，成功后缓存 Session Cookie。Cookie 有效期内（通常数小时）无需再次登录。

---

## 3. 课程查询接口

### 3.1 已确认的接口列表

基于开源项目 `zfn_api`（260+ Stars）和 `school-api` 的逆向工程，正方教务系统提供以下接口：

| 接口 | 功能 | 关键参数 |
|------|------|---------|
| `get_schedule` | 获取学生课表 | `year` 学年, `term` 学期 |
| `get_score` | 获取成绩 | `year` 学年, `term` 学期 |
| `get_exam_schedule` | 获取考试安排 | `year` 学年, `term` 学期 |
| `get_info` | 获取个人信息 | 无 |
| `get_selected_courses` | 已选课程详情 | `year`, `term` |
| `get_place_schedule` | 空教室查询 | 校区、教学楼等 |

### 3.2 课表查询详细参数

```
请求方式: POST (部分学校支持 GET)
路径: {base_url}/xskbcx.aspx 或 /xsgrkbcx.aspx
        或通过统一 API: {base_url}/xsxxx/xxx

参数:
  xnm    学年 (如 2026 表示 2026-2027 学年)
  xqm    学期 (3=秋季, 12=春季, 0=全年)
  xnxq   另一种格式: "2026-2027-1" 或 "2026-2027-1-1"
          (2026-2027学年, 1=第一学期)

请求头:
  Cookie: ASP.NET_SessionId=xxx
  Content-Type: application/x-www-form-urlencoded
  User-Agent: Mozilla/5.0 ...

附加隐藏字段:
  __VIEWSTATE: {从页面提取}
  __VIEWSTATEGENERATOR: {从页面提取}
```

### 3.3 返回数据字段（课表）

```json
{
  "course_id": "MATH1001",       // 课程编号
  "title": "高等数学A1",          // 课程名称
  "teacher": "张明",              // 任课教师
  "weekday": 1,                   // 星期几 (1=周一, 7=周日)
  "sessions": [1, 2],            // 节次范围
  "list_sessions": [1, 2],       // 节次详细列表
  "weeks": [1,2,3,...,18],       // 上课周次列表
  "list_weeks": [1,...,18],      // 开课周次
  "week_type": "all",            // 单双周 (all/odd/even)
  "campus": "主校区",             // 上课校区
  "place": "综合教学1号楼 综151",  // 上课地点
  "credit": 5.0,                  // 学分
  "total_hours": 80,              // 总学时
  "weekly_hours": 4,              // 周学时
  "evaluation_mode": "考试",      // 考核方式
  "class_name": "2024级-01班",   // 教学班
  "category": "必修",             // 课程类别
  "nature": "通识必修课",         // 课程性质
  "hours_composition": {          // 学时组成
    "theory": 64,
    "practice": 16
  }
}
```

### 3.4 学期代码对照

| 学期 | xqm 参数值 | xnxq 格式 |
|------|-----------|-----------|
| 秋季学期（第一学期） | `3` | `{year}-{year+1}-1` |
| 春季学期（第二学期） | `12` | `{year-1}-{year}-2` |
| 夏季短学期 | `4` | 依学校而定 |

---

## 4. 网络请求流程

### 4.1 完整请求时序

```
Client                          SSO Server              教务系统
  │                                  │                      │
  ├─ 1. GET /login ────────────────→│                      │
  │←── Set-Cookie + Login Page ─────┤                      │
  │                                  │                      │
  ├─ 2. POST /login ───────────────→│                      │
  │   (学号+密码+CSRF)               │                      │
  │←── 302 + Ticket ────────────────┤                      │
  │                                  │                      │
  ├─ 3. GET 教务系统入口?ticket=xxx ──────────────────────→│
  │←── Set-Cookie (ASP.NET_SessionId) ────────────────────┤
  │                                  │                      │
  ├─ 4. GET 课表页面 ─────────────────────────────────────→│
  │←── HTML + __VIEWSTATE ────────────────────────────────┤
  │                                  │                      │
  ├─ 5. POST 课表查询 API ────────────────────────────────→│
  │   (xnm, xqm, __VIEWSTATE, Cookie)                      │
  │←── JSON/HTML 课程数据 ─────────────────────────────────┤
  │                                  │                      │
```

### 4.2 Cookie 管理策略

```
请求链 Cookie 传递:

Step 1 (GET SSO login):
  ← Set-Cookie: JSESSIONID=AAA

Step 2 (POST SSO login):
  → Cookie: JSESSIONID=AAA
  ← Set-Cookie: TGC=BBB (Ticket Granting Cookie)

Step 3 (GET 教务系统):
  → Cookie: TGC=BBB
  ← Set-Cookie: ASP.NET_SessionId=CCC

Step 4+ (后续请求):
  → Cookie: ASP.NET_SessionId=CCC
  → Form Data: __VIEWSTATE=DDD
```

### 4.3 请求频率控制

| 操作 | 建议间隔 | 说明 |
|------|---------|------|
| 登录 | 5s+ | 失败后指数退避 |
| 课表查询 | 2s+ | 查询不同学期可稍快 |
| 成绩查询 | 3s+ | 成绩接口可能较慢 |
| 验证码刷新 | 1s+ | 频繁刷新可能被限制 |

---

## 5. 课程数据解析

### 5.1 数据获取方式对比

| 方式 | 技术难度 | 数据完整性 | 维护成本 |
|------|---------|-----------|---------|
| **API JSON** (新版) | 中 | 高，结构化数据 | 低 |
| **HTML Table** (旧版) | 中 | 中，需清洗 | 中 |
| **导出 .xlsx/.ics** | 低 | 高 | 低（但需用户手动操作） |
| **截屏 OCR** | 高 | 低 | 高 |

**推荐优先方案**: API JSON → 降级为 HTML 解析 → 最终降级为文件导入

### 5.2 HTML Table 解析（旧版教务系统）

旧版正方系统课表是 HTML `<table>` 结构：

```html
<table id="Table1" class="timetable">
  <tr>
    <td>节次</td><td>星期一</td><td>星期二</td>...
  </tr>
  <tr>
    <td>第1节</td>
    <td rowspan="2">
      高等数学A1<br>张明<br>综151<br>1-18周
    </td>
    ...
  </tr>
</table>
```

解析策略：
1. 定位 `<table id="Table1">`
2. 遍历 `<tr>` 和 `<td>`，通过 `rowspan` 追踪课程跨度
3. 正则提取：课程名、教师、教室、周次、单双周标记

### 5.3 数据清洗映射

从教务系统原始数据映射到 App 的 `CourseImportDTO`：

```
教务字段               →  App 模型
────────────────────────────────────
course_id / course_code → Course.code
title / course_name     → Course.name
teacher / teacher_name  → Course.teacherName
place / classroom       → Course.location
credit / credits        → Course.credits
category / nature       → Course.courseType (映射)
weekday                 → ScheduleInput.dayOfWeek
sessions / list_sessions → ScheduleInput.startPeriod
                           ScheduleInput.endPeriod
weeks / list_weeks      → ScheduleInput.startWeek
                           ScheduleInput.endWeek
week_type               → ScheduleInput.weekType
```

### 5.4 课程类型映射

```
教务系统分类              → App CourseType
─────────────────────────────────────────
必修 / 通识必修课         → .compulsory
选修 / 通识选修课         → .elective
实验 / 实践环节           → .experiment
体育                     → .pe
其他                     → .other
```

---

## 6. 自动导入方案设计

### 6.1 推荐方案：内置浏览器 + API 混合

```
┌─────────────────────────────────────────────────────────┐
│  App 端（Swift）                                         │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  ImportAuthView (WebView)                        │    │
│  │  ────────────────────────────────────────────    │    │
│  │  加载: https://sso.dlut.edu.cn/login             │    │
│  │  用户在 WebView 中完成登录（含验证码）              │    │
│  │  拦截 Set-Cookie → 提取 TGC + JSESSIONID         │    │
│  └─────────────────┬───────────────────────────────┘    │
│                    │ Cookie                              │
│                    ▼                                     │
│  ┌─────────────────────────────────────────────────┐    │
│  │  DUTImportService                                │    │
│  │  ────────────────────────────────────────────    │    │
│  │  1. 携带 Cookie → 请求教务系统首页                  │    │
│  │  2. 提取 ASP.NET_SessionId                        │    │
│  │  3. 解析 __VIEWSTATE                              │    │
│  │  4. POST 课表查询 API                             │    │
│  │  5. JSON 解析 → [CourseImportDTO]                 │    │
│  │  6. CourseService.importCourses(dtos, semester)   │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**此方案优势**：
- 用户在自己手机 WebView 中登录，密码不经过任何第三方
- WebView 自动处理 SSO 重定向、验证码等复杂逻辑
- Cookie 自动捕获，无需手动提取
- 符合学校信息安全要求

### 6.2 备用方案：文件导入

```
用户操作:
1. 电脑登录教务系统
2. 导出课程表为 .xlsx 或 .ics 文件
3. 通过 AirDrop/微信/QQ 发送到手机
4. App 中点击导入 → 选择文件 → 解析

实现:
- UIDocumentPickerViewController 选择文件
- .xlsx 解析（使用 CoreXLSX 或自定义解析器）
- .ics 解析（使用内置 Calendar 框架）
- 映射到 CourseImportDTO
```

### 6.3 导入冲突处理策略

导入课程时可能与已有课程冲突：

```swift
enum ImportConflictStrategy {
    case replace     // 覆盖已有课程（按 code 匹配）
    case merge       // 合并（保留手动添加的时间安排，新增教务系统安排）
    case skip        // 跳过重复课程
    case ask         // 逐门询问用户
}
```

默认策略：**按 `course.code` 匹配 → replace 同名课程 → skip 未变化课程**。

### 6.4 导入预览 UI 流程

```
┌──────────────────────────────┐
│  导入课程                     │
│                              │
│  正在从教务系统获取课程...      │
│  ████████████░░░░  75%       │
│                              │
│  已获取 8 门课程               │
│  ┌──────────────────────────┐│
│  │ ✅ 高等数学A1    5.0学分  ││
│  │ ✅ 大学物理A1    4.0学分  ││
│  │ 🆕 线性代数      3.0学分  ││  ← 标记新增
│  │ 🔄 C语言程序设计  2.5学分  ││  ← 标记更新
│  │ ⚠️ 体育(篮球)   冲突      ││  ← 标记时间冲突
│  └──────────────────────────┘│
│                              │
│  [ 取消 ]      [ 确认导入 ]   │
└──────────────────────────────┘
```

---

## 7. 安全与合规

### 7.1 密码安全

| 原则 | 实现 |
|------|------|
| **不存储明文密码** | 密码仅在 WebView 的 SSO 登录页使用，App 不做持久化 |
| **Cookie 本地加密** | 缓存的 Session Cookie 使用 Keychain 存储 |
| **网络传输加密** | 全部请求使用 HTTPS |
| **不经过第三方服务器** | 所有请求直接从用户设备发往学校服务器 |

### 7.2 数据合规

| 事项 | 说明 |
|------|------|
| **使用目的** | 仅用于个人课程管理，不收集用户数据 |
| **隐私政策** | 在 App 中声明数据使用范围 |
| **学校规定** | 遵守大连理工大学信息化管理相关规定 |
| **频率限制** | 单用户每小时不超过 10 次请求，避免给服务器造成压力 |

### 7.3 法律风险提示

> ⚠️ 自动登录教务系统属于灰色地带。建议：
> 1. App Store 上架时提供"手动导入"作为主要导入方式
> 2. "自动导入"功能通过 WebView 加载官方登录页实现（合规的 OAuth-like 流程）
> 3. 避免使用模拟请求方式绕过验证码（可能违反学校网络使用规定）

---

## 8. 开发路线

### Phase 8.1: 调研验证（1-2 天）

- [ ] 确认大连理工大学当前使用的教务系统版本（新版/旧版）
- [ ] 确认 SSO 登录页地址和参数
- [ ] 确认课表查询 API 返回格式（JSON 还是 HTML）
- [ ] 在一个干净环境测试完整登录→课表流程
- [ ] 验证 Cookie 有效期

### Phase 8.2: DUTImportService 实现（3-4 天）

- [ ] 实现 `WKWebView` 登录界面
- [ ] 实现 Cookie 拦截和存储（Keychain）
- [ ] 实现 `DUTImportService: ImportServiceProtocol`
- [ ] 实现课表数据获取（API 优先，HTML 降级）
- [ ] 实现数据映射 → `CourseImportDTO`
- [ ] 实现导入预览界面
- [ ] 实现冲突检测和合并逻辑

### Phase 8.3: 降级方案（1-2 天）

- [ ] 实现 .xlsx 文件导入解析器
- [ ] 实现 .ics 文件导入解析器
- [ ] 实现文件选择器（UIDocumentPickerViewController）

### Phase 8.4: 测试与上线（2-3 天）

- [ ] 单元测试（数据解析、映射逻辑）
- [ ] 集成测试（完整导入流程）
- [ ] 错误处理（网络超时、验证码错误、系统维护）
- [ ] App Store 合规审查

---

## 附录 A: 关键 URL 参考

| 系统 | 地址 | 状态 |
|------|------|------|
| **教务系统 Base URL** | `http://jxgl.dlut.edu.cn` | ✅ 已确认 |
| **课表页面** | `http://jxgl.dlut.edu.cn/student/for-std/course-table` | ✅ 已确认 (GET → HTML) |
| **学生主页** | `http://jxgl.dlut.edu.cn/student/home` | ✅ 已确认 (Referer) |
| 教务处官网 | `https://teach.dlut.edu.cn` | 教务通知、入口 |
| 统一身份认证 SSO | `https://sso.dlut.edu.cn` | 待确认确切地址 |
| 校园门户 | `https://portal.dlut.edu.cn` | 综合服务门户 |
| 网络与信息化中心 | `http://its.dlut.edu.cn` | 密码重置等 |

> **注意**: 课表数据 API 的确切路径（返回 JSON 的那个请求）仍需通过 DevTools Network 标签进一步确认。当前 `/student/for-std/course-table` 为 GET 返回 HTML 页面，数据可能通过 XHR/Fetch 从其他路径加载。

## 附录 B: 开源项目参考

| 项目 | 语言 | 功能 | Stars |
|------|------|------|-------|
| [openschoolcn/zfn_api](https://github.com/openschoolcn/zfn_api) | Python | 新版正方 API SDK | 260+ |
| [jimages/school-api](https://github.com/jimages/school-api) | Python | 正方教务 Python SDK | - |
| [LangQi99/dlut-NetworkStealer](https://github.com/LangQi99/dlut-NetworkStealer) | Python | DUT 爬虫工具 | 15 |
| [whliao5am/zfnew](https://github.com/whliao5am/zfnew) | Python | 新版正方教务 SDK | - |
| [atopos31/syluinfo](https://github.com/atopos31/syluinfo) | - | 正方系统接口校园助手 | - |

---

> **文档维护**: 本文档基于公开资料和开源项目分析编写。实际接口地址、参数、数据结构可能因学校系统升级而变化，开发前需做实际验证。
