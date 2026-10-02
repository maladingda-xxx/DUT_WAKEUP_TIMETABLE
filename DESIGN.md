# Wake Up 课程表 — 软件设计文档

> **版本**: v1.0  
> **日期**: 2026-07-14  
> **目标用户**: 大连理工大学学生  
> **最低系统**: iOS 17.0  

---

## 目录

1. [项目概述](#1-项目概述)
2. [整体架构设计](#2-整体架构设计)
3. [文件目录结构](#3-文件目录结构)
4. [核心数据模型设计](#4-核心数据模型设计)
5. [模块划分](#5-模块划分)
6. [页面结构与导航](#6-页面结构与导航)
7. [数据流设计](#7-数据流设计)
8. [WidgetKit 设计](#8-widgetkit-设计)
9. [教务系统对接预留](#9-教务系统对接预留)
10. [开发路线规划](#10-开发路线规划)

---

## 1. 项目概述

### 1.1 App 定位

一款专为大连理工大学学生设计的智能课程表 App。以课程表浏览为核心，后续逐步接入教务系统实现自动导入，最终成为覆盖课程管理、作业提醒、考试倒计时的一站式学习助手。

### 1.2 核心功能

| 优先级 | 功能 | 说明 |
|--------|------|------|
| P0 | 课程表展示 | 周视图/日视图，支持左右滑动切换周次 |
| P0 | 课程编辑 | 手动添加、编辑、删除课程 |
| P0 | 桌面小组件 | 今日课程、明日课程 |
| P1 | 学期管理 | 多学期切换，学期起止日期 |
| P1 | 单双周支持 | 课程按单周/双周/每周显示 |
| P1 | 考试倒计时 | 关联考试日期 |
| P2 | 教务系统导入 | 从大连理工大学教务系统自动导入 |
| P2 | iCloud 同步 | 多设备同步 |
| P2 | 作业提醒 | 关联课程的作业与截止日期 |

### 1.3 技术选型

| 技术 | 选型 | 理由 |
|------|------|------|
| UI 框架 | SwiftUI | 声明式 UI，与 WidgetKit 天然配合 |
| 持久化 | SwiftData | Apple 新一代持久化框架，与 SwiftUI 深度集成 |
| 架构模式 | MVVM | 分离视图与业务逻辑，可测试性强 |
| 响应式 | Combine + @Observable | SwiftData + SwiftUI 原生绑定 |
| 小组件 | WidgetKit + AppIntent | iOS 17+ 交互式小组件 |
| 依赖管理 | Swift Package Manager | 原生，轻量 |

---

## 2. 整体架构设计

### 2.1 架构分层

```
┌──────────────────────────────────────────────────────┐
│                    Presentation Layer                 │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │  Views    │  │  Widgets │  │  ViewModels        │  │
│  │  (SwiftUI)│  │(WidgetKit)│  │  (@Observable)    │  │
│  └─────┬─────┘  └────┬─────┘  └────────┬──────────┘  │
│        │              │                │              │
├────────┼──────────────┼────────────────┼──────────────┤
│        │         Domain Layer           │              │
│  ┌─────┴──────────────┴────────────────┴──────────┐   │
│  │              Service Protocols                    │   │
│  │  CourseService │ SemesterService │ ImportService │   │
│  └──────────────────────┬──────────────────────────┘   │
│                         │                              │
├─────────────────────────┼──────────────────────────────┤
│                    Data Layer                          │
│  ┌──────────────────────┴──────────────────────────┐   │
│  │              SwiftData ModelContainer             │   │
│  │  Course │ Semester │ Classroom │ Teacher │ Exam  │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │           AppGroup Shared Container              │   │
│  │         (Widget 与主 App 数据共享)               │   │
│  └─────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

### 2.2 MVVM 职责划分

```
View (SwiftUI)
  ├── 纯 UI 声明，不包含业务逻辑
  ├── 通过 @Environment 或构造函数注入 ViewModel
  └── 使用 @Query (SwiftData) 直接读取数据

ViewModel (@Observable)
  ├── 持有业务逻辑
  ├── 协调 Service 与 View 之间的数据流
  ├── 处理用户交互 (CRUD 操作)
  └── 不直接持有 SwiftData ModelContext（通过 Service 层操作）

Service (协议 + 实现)
  ├── 封装数据操作逻辑
  ├── 提供 Mock 实现用于 Preview 和 Test
  └── 教务系统导入逻辑（未来）
```

### 2.3 依赖注入策略

采用 **协议 + 环境值** 的轻量注入方式，避免引入第三方 DI 框架：

```swift
// 服务通过 Environment 注入
@Environment(\.courseService) private var courseService

// 协议定义
protocol CourseService {
    func fetchCourses(for semester: Semester) -> [Course]
    func addCourse(_ course: Course)
    func deleteCourse(_ course: Course)
}
```

---

## 3. 文件目录结构

```
wake-up-timeTable/
├── App/
│   ├── wake_up_timeTableApp.swift          # @main 入口
│   ├── AppDelegate.swift                    # 生命周期处理（如需）
│   └── AppContainer.swift                   # ModelContainer + 服务注册
│
├── Models/
│   ├── Course.swift                         # 课程模型
│   ├── CourseSchedule.swift                 # 课程时间安排（一周多节）
│   ├── Semester.swift                       # 学期模型
│   ├── Classroom.swift                      # 教室模型
│   ├── Teacher.swift                        # 教师模型
│   ├── Exam.swift                           # 考试模型
│   └── Enums/
│       ├── WeekDay.swift                    # 星期枚举
│       ├── WeekType.swift                   # 单双周枚举
│       ├── CourseType.swift                 # 课程类型（必修/选修/实验）
│       ├── Period.swift                     # 节次（第一大节、第二大节...）
│       └── SemesterType.swift              # 学期类型（春/秋）
│
├── Services/
│   ├── Protocols/
│   │   ├── CourseServiceProtocol.swift
│   │   ├── SemesterServiceProtocol.swift
│   │   └── ImportServiceProtocol.swift      # 教务导入协议（预留）
│   ├── CourseService.swift
│   ├── SemesterService.swift
│   ├── WeekCalculator.swift                 # 周次计算工具
│   └── Mock/
│       ├── MockCourseService.swift          # Preview 用 Mock
│       └── MockData.swift                   # 示例数据
│
├── ViewModels/
│   ├── TimetableViewViewModel.swift         # 课程表主页 VM
│   ├── CourseEditViewModel.swift            # 课程编辑 VM
│   ├── SemesterManageViewModel.swift        # 学期管理 VM
│   ├── ExamListViewModel.swift              # 考试列表 VM
│   └── SettingsViewModel.swift              # 设置 VM
│
├── Views/
│   ├── MainTabView.swift                    # 主 Tab 容器
│   │
│   ├── Timetable/
│   │   ├── TimetablePageView.swift           # 课程表主视图（PageView）
│   │   ├── TimetableView.swift              # 课程表网格视图
│   │   ├── DailyTimetableView.swift         # 单日课程表
│   │   ├── CourseCell.swift                 # 课程格子
│   │   ├── CourseCellCompact.swift          # 紧凑课程格子（日视图）
│   │   ├── WeekSelector.swift               # 周次选择器
│   │   ├── TimetableHeader.swift            # 表头（星期 + 日期）
│   │   └── EmptyTimetablePlaceholder.swift   # 空课程表占位
│   │
│   ├── CourseDetail/
│   │   ├── CourseDetailView.swift           # 课程详情页
│   │   ├── CourseEditView.swift             # 课程编辑页（新增/编辑）
│   │   └── CourseSchedulePicker.swift       # 时间选择组件
│   │
│   ├── Exam/
│   │   ├── ExamListView.swift               # 考试列表
│   │   ├── ExamEditView.swift               # 考试编辑
│   │   └── ExamCountdownCard.swift          # 倒计时卡片
│   │
│   ├── Semester/
│   │   ├── SemesterManageView.swift         # 学期管理
│   │   └── SemesterEditView.swift           # 学期编辑
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift               # 设置页
│   │   └── AboutView.swift                  # 关于页
│   │
│   └── Components/
│       ├── ColorPicker.swift                # 课程颜色选择器
│       ├── DUTColor.swift                   # 大工主题色
│       ├── EmptyStateView.swift             # 通用空状态
│       └── LoadingOverlay.swift             # 加载遮罩
│
├── Widgets/
│   ├── TimetableWidgetBundle.swift          # Widget Bundle 入口
│   ├── TodayCoursesWidget/
│   │   ├── TodayCoursesWidget.swift         # 今日课程小组件
│   │   ├── TodayCoursesEntry.swift          # Timeline Entry
│   │   └── TodayCoursesProvider.swift       # Timeline Provider
│   ├── UpcomingCoursesWidget/
│   │   ├── UpcomingCoursesWidget.swift      # 即将上课小组件
│   │   ├── UpcomingCoursesEntry.swift
│   │   └── UpcomingCoursesProvider.swift
│   └── WidgetShared/
│       └── WidgetDataProvider.swift         # Widget 共享数据读取
│
├── Extensions/
│   ├── Date+Extension.swift                 # 日期扩展（周次计算等）
│   ├── Color+Extension.swift                # 颜色扩展
│   ├── Array+Extension.swift                # 数组安全访问
│   └── View+Extension.swift                 # View 修饰符扩展
│
├── Utilities/
│   ├── Constants.swift                      # 全局常量
│   ├── SchoolCalendar.swift                 # 大工校历计算
│   └── DUTImportParser.swift                # 教务系统数据解析（预留）
│
├── Resources/
│   ├── Assets.xcassets                      # 图片资源
│   ├── DUTColors.xcassets                   # 大工标准色
│   └── Info.plist                           # 应用配置（如需）
│
└── Tests/
    ├── wake_up_timeTableTests/
    │   ├── WeekCalculatorTests.swift
    │   ├── CourseServiceTests.swift
    │   └── DUTImportParserTests.swift
    └── wake_up_timeTableUITests/
        └── TimetableUITests.swift
```

---

## 4. 核心数据模型设计

### 4.1 ER 关系图

```
Semester (1) ────< (N) Course (1) ────< (N) CourseSchedule
                                              │
                                              │ (N:1)
                                              │
                                          Classroom

Course (1) ────< (N) Exam

Teacher (N) ────> (N) Course （多对多，简化为 Course 中存储 teacherName）
```

### 4.2 Semester（学期）

```swift
@Model
final class Semester {
    var id: UUID
    var name: String                    // "2026-2027 第一学期"
    var startDate: Date                 // 学期第一天（周一）
    var totalWeeks: Int                 // 总教学周数（含考试周），默认 18
    var startWeekNumber: Int            // 起始周序号，默认 1
    var isCurrent: Bool                 // 是否为当前学期
    var courses: [Course]?              // 关联课程（SwiftData relationship）
    var createdAt: Date
}
```

**设计说明**：
- `startDate` 必须是周一，系统在创建/编辑时校验
- `startWeekNumber` 用于教学周不连续的情况（如 1-8 周、10-17 周，中间有实践周），大多数场景为 1
- `isCurrent` 同一时间只有一个学期为 true，切换时自动置反

### 4.3 Course（课程）

```swift
@Model
final class Course {
    var id: UUID
    var name: String                    // "高等数学A1"
    var code: String?                   // 课程编号 "MATH1001"（教务系统编号）
    var teacherName: String?            // 教师名称（暂用字符串，后续可改关联）
    var location: String?               // 上课地点 "综合教学1号楼 综151"
    var colorHex: String                // 课程卡片颜色 "#4A90D9"（用户可自定义）
    var courseType: CourseType          // 必修/选修/实验/体育
    var credits: Double?                // 学分
    var note: String?                   // 备注
    var schedules: [CourseSchedule]?    // 时间安排
    var exams: [Exam]?                  // 关联考试
    var semester: Semester?             // 所属学期
    var createdAt: Date
    var updatedAt: Date
}
```

**设计说明**：
- `location` 直接存字符串，不建 Classroom 单独模型——大工教室名称变化少，独立模型收益低，过度设计
- `teacherName` 同样存字符串，后续如需展示教师详情再升级为关联
- `colorHex` 每门课分配一个默认颜色（根据 courseType 自动选色），用户可手动修改

### 4.4 CourseSchedule（课程时间安排）

```swift
@Model
final class CourseSchedule {
    var id: UUID
    var dayOfWeek: Int                  // 1=周一 ... 7=周日
    var startPeriod: Int                // 起始节次 1-12
    var duration: Int                   // 持续节数（2 表示两大节连上）
    var weekType: WeekType              // .all / .odd / .even
    var startWeek: Int                  // 起始教学周（默认 1）
    var endWeek: Int                    // 结束教学周（默认 18）
    var location: String?               // 可覆盖 Course 级别的 location
    var course: Course?                 // 反向关联
}
```

**设计说明**：
- 一节 Schedule 对应一周内的一个时间块
- 高等数学可能在周一 1-2 节、周三 3-4 节——这是两条 CourseSchedule 记录
- `startWeek` / `endWeek` 支持某门课只在前半学期开设（如 1-8 周）
- `weekType` 支持单双周：`.all` 每周都上、`.odd` 单周、`.even` 双周
- `location` 允许覆盖：理论课在 A 楼，实验课在 B 楼

### 4.5 Exam（考试）

```swift
@Model
final class Exam {
    var id: UUID
    var name: String                    // "高等数学A1 期末考试"
    var date: Date                      // 考试日期
    var startTime: Date                 // 考试开始时间
    var endTime: Date                   // 考试结束时间
    var location: String?               // 考场
    var seatNumber: String?             // 座位号
    var note: String?                   // 备注（如 "闭卷"）
    var course: Course?                 // 关联课程
}
```

### 4.6 枚举定义

```swift
enum WeekDay: Int, Codable, CaseIterable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
}

enum WeekType: String, Codable, CaseIterable {
    case all = "每周"
    case odd = "单周"
    case even = "双周"
}

enum CourseType: String, Codable, CaseIterable {
    case compulsory = "必修"
    case elective = "选修"
    case experiment = "实验"
    case pe = "体育"
    case other = "其他"
}

enum SemesterType: String, Codable {
    case spring = "春"
    case autumn = "秋"
}
```

### 4.7 节次时间映射

大连理工大学常见节次安排（依据实际校历调整）：

```
第一节 (第一大节): 08:00 - 08:45
第二节 (第一大节): 08:50 - 09:35
第三节 (第二大节): 09:50 - 10:35
第四节 (第二大节): 10:40 - 11:25
第五节 (第三大节): 13:30 - 14:15
第六节 (第三大节): 14:20 - 15:05
第七节 (第四大节): 15:20 - 16:05
第八节 (第四大节): 16:10 - 16:55
第九节 (第五大节): 18:00 - 18:45
第十节 (第五大节): 18:50 - 19:35
第十一节(第六大节): 19:45 - 20:30
第十二节(第六大节): 20:35 - 21:20
```

在 `Constants.swift` 中配置为静态数组，后续可从教务系统动态获取。

---

## 5. 模块划分

### 5.1 模块依赖关系

```
                    ┌─────────────┐
                    │   AppCore   │  (App 入口、DI 容器、ModelContainer)
                    └──────┬──────┘
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
    │  Timetable  │ │   Exam      │ │  Settings   │
    │  Module     │ │   Module    │ │  Module     │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │
           └───────────────┼───────────────┘
                           │
                  ┌────────▼────────┐
                  │  Service Layer  │
                  │  (业务逻辑层)    │
                  └────────┬────────┘
                           │
                  ┌────────▼────────┐
                  │  Models         │
                  │  (SwiftData)    │
                  └────────┬────────┘
                           │
                  ┌────────▼────────┐
                  │  Utilities      │
                  │  (工具/扩展)     │
                  └─────────────────┘
```

### 5.2 各模块职责

| 模块 | 职责 | 核心文件 |
|------|------|---------|
| **AppCore** | 应用启动、ModelContainer 配置、服务注册、Tab 导航 | `App/` |
| **Timetable** | 课程表周视图/日视图、周次切换、课程增删改 | `Views/Timetable/`, `ViewModels/TimetableViewModel` |
| **CourseDetail** | 课程详情查看、编辑表单、时间选择器 | `Views/CourseDetail/`, `ViewModels/CourseEditViewModel` |
| **Exam** | 考试列表、考试编辑、倒计时 | `Views/Exam/`, `ViewModels/ExamListViewModel` |
| **Semester** | 学期管理、学期切换 | `Views/Semester/`, `ViewModels/SemesterManageViewModel` |
| **Settings** | 应用设置、主题/颜色、关于页 | `Views/Settings/` |
| **Widgets** | 桌面小组件（今日课程、即将上课） | `Widgets/` |
| **Services** | 数据 CRUD、周次计算、教务导入 | `Services/` |
| **Utilities** | 颜色常量、日期扩展、校历数据 | `Utilities/`, `Extensions/` |

---

## 6. 页面结构与导航

### 6.1 导航架构

```
TabBar
├── Tab 1: 课程表 (TimetablePageView)
│   ├── [左右滑动] 周视图 (TimetableView)
│   │   └── [点击课程格子] → CourseDetailView (Push)
│   │       └── [点击编辑] → CourseEditView (Sheet)
│   ├── [右上角 +] → CourseEditView (Sheet, 新增模式)
│   ├── [右上角 切换] → 日视图 (DailyTimetableView)
│   └── [顶部] WeekSelector (左右箭头 + 周范围显示)
│
├── Tab 2: 考试 (ExamListView)
│   ├── [点击考试] → 考试详情（暂无独立页，可用 Sheet 编辑）
│   ├── [右上角 +] → ExamEditView (Sheet)
│   └── [Section Header] 考试倒计时卡片
│
├── Tab 3: 设置 (SettingsView)
│   ├── 学期管理 → SemesterManageView (Push)
│   │   ├── [点击学期] → SemesterEditView (Sheet)
│   │   └── [点击"设为当前"] 切换学期
│   ├── 教务导入 → (P2 功能，预留入口)
│   ├── 外观设置 → 颜色主题 / App 图标
│   └── 关于 → AboutView (Push)
│
└── [小组件] 桌面 TodayCoursesWidget / UpcomingCoursesWidget
```

### 6.2 关键交互流程

**添加课程流程：**
```
TimetablePageView → 点击 + → CourseEditView (Sheet)
  ├── 填写课程名称、教师、地点
  ├── 添加时间安排（可选多条）
  │   ├── 选择星期、起始节次、持续节数
  │   ├── 选择周类型（每周/单周/双周）
  │   └── 选择起止教学周
  ├── 选择颜色
  └── 保存 → SwiftData 持久化 → 课程表刷新
```

**查询某周课程流程：**
```
用户滑动到第 N 周 → WeekSelector 更新 currentWeek
  → TimetableView 中 @Query 按 semester + weekNumber 筛选
  → WeekCalculator 计算当前周的日期范围
  → TimetableHeader 显示日期
  → CourseCell 渲染匹配的课程
```

---

## 7. 数据流设计

### 7.1 SwiftData 数据流

```
┌─────────────────────────────────────────────────────┐
│  SwiftUI View                                       │
│  @Query(sort: ..., filter: ...) var courses         │
│      │                                              │
│      │ 自动订阅 SwiftData 变更                       │
│      ▼                                              │
│  ModelContainer.shared                              │
│      │                                              │
│      ▼                                              │
│  SQLite (AppGroup 共享容器)                          │
│      │                                              │
│      ├── 主 App 读写                                │
│      └── Widget 只读                                │
└─────────────────────────────────────────────────────┘
```

### 7.2 ViewModel 与 Service 协作

```
View (用户操作)
  │
  ▼
ViewModel (@Observable)
  │ 调用 Service 协议方法
  ▼
Service (实现类，持有 ModelContext)
  │ 执行 SwiftData CRUD
  ▼
ModelContext.commit()
  │ SwiftData 自动通知
  ▼
@Query 自动刷新 View
```

### 7.3 跨模块通信

- **ViewModel → ViewModel**: 不直接通信。通过 Service 层或 SwiftData 的 `@Query` 自动更新。
- **Widget → 主 App**: Widget 只读共享 SQLite。Widget 上的交互（如点击某节课）通过 `widgetURL` 深链接到主 App 对应页面。
- **主 App → Widget**: 主 App 数据变更后，调用 `WidgetCenter.shared.reloadAllTimelines()` 刷新小组件。

---

## 8. WidgetKit 设计

### 8.1 小组件规划

| 组件 | 尺寸 | 内容 |
|------|------|------|
| **今日课程** | small, medium | 当天课程列表，含时间、地点 |
| **今日课程（大）** | large | 当天完整课程表 + 日期信息 |
| **即将上课** | small, medium | 距离下一节课还有多久，课程信息 |
| **锁屏小组件** | accessory | 下一节课名称 + 时间 + 地点 |

### 8.2 Timeline 刷新策略

```
TimelineProvider 刷新时机：
├── 每次主 App 数据变更 → WidgetCenter.reloadAllTimelines()
├── 系统自动刷新（预算有限，约每 15-60 分钟）
└── Timeline 提前生成策略：
    ├── 当天：每小时刷新一次
    ├── 跨天：在 00:00 刷新
    └── 跨学期：学期结束时刷新到空状态
```

### 8.3 数据共享方案

使用 App Group 共享容器：
1. 主 App 的 `ModelContainer` 配置 Store URL 指向 App Group 目录
2. Widget Extension 使用相同的 Store URL（只读连接）
3. Widget 中通过 `ModelContainer` 直接 `FetchDescriptor` 查询

```swift
// 共享容器路径
static let sharedStoreURL = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.com.dut.wakeup")!
    .appending(path: "Timetable.sqlite")
```

---

## 9. 教务系统对接预留

### 9.1 导入策略

```
教务系统（大连理工大学）
    │
    ▼
ImportServiceProtocol (协议)
    │
    ├── 当前实现: ManualImportService (手动输入)
    │
    └── 未来实现: DUTImportService
        ├── 方案 A: 解析教务系统网页/API
        ├── 方案 B: 解析学生导出的 .ics/.xlsx 文件
        └── 方案 C: 抓包教务系统 App 接口
```

### 9.2 DUTImportService 预留接口

```swift
protocol ImportServiceProtocol {
    /// 是否支持自动导入
    var supportsAutoImport: Bool { get }
    
    /// 从数据源解析课程
    func parseCourses(from data: Data) async throws -> [CourseImportDTO]
    
    /// 导入课程到指定学期
    func importCourses(_ dtos: [CourseImportDTO], to semester: Semester) async throws
}

struct CourseImportDTO {
    var name: String
    var code: String?
    var teacherName: String?
    var location: String?
    var schedules: [ScheduleDTO]
    var courseType: CourseType
    var credits: Double?
}
```

### 9.3 数据模型扩展点

- `Course.code` 字段预留用于教务系统课程编号
- `Semester` 可扩展 `externalId` 字段对接教务系统学期 ID
- 所有模型均使用 `Codable`，便于序列化导入/导出

---

## 10. 开发路线规划

### Phase 1: 基础框架搭建（预计 3-5 天）

- [x] 创建 Xcode 项目，SwiftUI + SwiftData
- [ ] 配置 App Group、ModelContainer
- [ ] 搭建目录结构
- [ ] 实现所有数据模型（`@Model`）
- [ ] 实现枚举类型
- [ ] 配置 App 入口、TabView 壳
- [ ] 注入 Mock 数据用于开发调试

### Phase 2: 课程表核心展示（预计 5-7 天）

- [ ] `TimetableView` — 课程表网格视图（5 列 × 6 大节）
- [ ] `CourseCell` — 课程卡片（颜色、名称、地点、教师）
- [ ] `WeekSelector` — 周次切换（第 1 周 ↔ 第 18 周）
- [ ] `TimetableHeader` — 日期头部
- [ ] 单双周、起止周筛选逻辑
- [ ] 课程表左右滑动切换周次
- [ ] 空课程表占位引导
- [ ] `DailyTimetableView` — 今日课程列表视图

### Phase 3: 课程增删改查（预计 4-5 天）

- [ ] `CourseEditView` — 课程编辑表单
- [ ] `CourseSchedulePicker` — 时间选择器组件
- [ ] `CourseDetailView` — 课程详情页
- [ ] `CourseService` — CRUD 逻辑封装
- [ ] 滑动删除、拖拽排序（暂不实现排序，数据驱动）
- [ ] 课程颜色自动分配 + 手动选择

### Phase 4: 学期管理（预计 2-3 天）

- [ ] `SemesterManageView` — 学期列表
- [ ] `SemesterEditView` — 学期编辑（日期、周数）
- [ ] `SemesterService` — 学期 CRUD
- [ ] 当前学期切换逻辑
- [ ] 学期起止日期 → 自动计算当前教学周

### Phase 5: 考试模块（预计 2-3 天）

- [ ] `ExamListView` — 考试列表 + 倒计时
- [ ] `ExamEditView` — 考试编辑
- [ ] `ExamCountdownCard` — 倒计时卡片
- [ ] 考试关联课程
- [ ] 系统日历提醒（可选）

### Phase 6: 桌面小组件（预计 3-4 天）

- [ ] Widget Extension Target 配置
- [ ] App Group 数据共享验证
- [ ] `TodayCoursesWidget` (small, medium, large)
- [ ] `UpcomingCoursesWidget` (small, medium)
- [ ] 锁屏小组件 (accessory)
- [ ] Timeline 刷新策略
- [ ] 点击小组件跳转主 App

### Phase 7: 打磨与发布（预计 3-5 天）

- [ ] 大工主题色 / 品牌调性
- [ ] 启动画面
- [ ] App Icon 设计
- [ ] 动画效果（课程表加载、切换周次）
- [ ] 无障碍适配
- [ ] 性能优化（@Query 过滤优化）
- [ ] TestFlight 内测
- [ ] App Store 上架

### Phase 8: 教务系统导入（预计 7-10 天）

- [ ] 调研大工教务系统数据结构
- [ ] 实现 `DUTImportService`（Web API / 网页解析 / 文件导入）
- [ ] 导入预览 + 冲突合并策略
- [ ] 增量更新（已有课程对比）

### Phase 9: 高级功能（持续迭代）

- [ ] iCloud 多设备同步
- [ ] 作业提醒
- [ ] 成绩查询
- [ ] 校历订阅
- [ ] Siri Shortcuts 集成
- [ ] Apple Watch 配对小部件
- [ ] 课程分享（给同学）

---

## 附录 A: 关键设计决策记录

| # | 决策 | 理由 | 替代方案 |
|---|------|------|---------|
| 1 | SwiftData 而非 Core Data | 与 SwiftUI 原生集成，代码量减少 50%+，iOS 17+ 已稳定 | Core Data + NSFetchedResultsController |
| 2 | MVVM 而非 VIPER/Redux | 与 SwiftUI + SwiftData 配合最自然，学习成本低 | TCA (The Composable Architecture) |
| 3 | 协议 + 环境值注入而非框架 | 轻量、零依赖、SwiftUI 原生 | Swinject / Resolver |
| 4 | CourseSchedule 独立模型 | 一门课多时间段是常见需求，分离模型查询更高效 | 在 Course 中用 Transformable 存 JSON |
| 5 | 教师/教室不建独立模型 | 当前阶段无独立查询需求，避免过度设计 | 建 Teacher/Classroom 模型 |
| 6 | App Group SQLite 共享 Widget | 无需额外序列化，Widget 直接读数据库 | App Group UserDefaults / JSON 文件 |

## 附录 B: 校历参考

大连理工大学校历关键节点（以实际校历为准）：

- 秋季学期：约 9 月初 — 次年 1 月中旬（约 18 周 + 考试周）
- 春季学期：约 2 月底 — 7 月初（约 18 周 + 考试周）
- 国庆假期、五一假期等需在 `SchoolCalendar` 中维护

`WeekCalculator` 依据学期 `startDate` + 当前日期，自动计算当前教学周。

---

> **文档维护**: 本文档随项目演进持续更新。架构层面变更需同步更新本文档。
