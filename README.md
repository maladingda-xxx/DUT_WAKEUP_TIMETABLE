# Wake Up 课程表（大工无广版）

> 一款专为**大连理工大学**学生写的 iOS 课程表 App。
> 无广告、无账号体系、无社交，课程数据只保存在你自己的设备上。

课程表浏览是核心，另外可以**用学号直接登录大工教务系统，一键把整学期课表导进来**，支持上课提醒和桌面小组件。

本仓库**没有上架 App Store，也没有提供打包好的安装包**，需要你按下面的步骤用 Xcode 自己编译并安装到 iPhone（对个人开发者来说，这是把自用 App 装进手机的标准做法，整个过程 10 分钟左右）。

---

## 目录

- [一、安装前你需要准备什么](#一安装前你需要准备什么)
- [二、把 App 装到你的 iPhone 上（源码编译）](#二把-app-装到你的-iphone-上源码编译)
- [三、首次使用：导入你的课表](#三首次使用导入你的课表)
- [四、桌面小组件（需要自己接一下）](#四桌面小组件需要自己接一下)
- [五、常见问题](#五常见问题)
- [六、项目结构](#六项目结构)
- [七、技术栈](#七技术栈)
- [八、声明](#八声明)

---

## 一、安装前你需要准备什么

| 项目 | 要求 | 说明 |
|------|------|------|
| 电脑 | macOS | 必须有 Mac，Windows 无法编译 iOS App |
| Xcode | **Xcode 26 或更新版本** | 从 Mac App Store 免费下载，体积较大（十几 GB），建议预留时间 |
| iPhone | 系统版本 **iOS 26.5 及以上** | 工程当前的 Deployment Target 是 26.5，低于此版本装不上，见 [常见问题](#五常见问题) |
| 数据线 | Lightning / USB-C | 首次安装需要用线连接手机 |
| Apple ID | 免费即可，**但功能会受限** | 免费账号无法使用 App Groups 能力，而本项目用它让小组件读取数据，详见步骤 4 |

> **只想先看看效果？** 也可以在 Xcode 里直接选 iPhone 模拟器（Simulator）运行，不需要开发者账号、不需要手机。缺点是模拟器上没有真实课表可导、小组件体验也和真机不同。

---

## 二、把 App 装到你的 iPhone 上（源码编译）

### 步骤 1 · 克隆仓库

```bash
git clone https://github.com/maladingda-xxx/DUT_WAKEUP_TIMETABLE.git
cd DUT_WAKEUP_TIMETABLE
```

也可以直接点仓库右上角的 `Code → Download ZIP`，解压后用。

### 步骤 2 · 用 Xcode 打开工程

```bash
open wake-up-timeTable.xcodeproj
```

工程打开后，左上角的运行目标（Scheme）会自动出现，名称是 `wake-up-timeTable`。

### 步骤 3 · 换成你自己的签名

在 Xcode 左侧点最顶部的项目图标（蓝色的 `wake-up-timeTable`）→ 选中 **TARGETS → wake-up-timeTable** → 打开 **Signing & Capabilities** 标签页：

1. 勾选 **Automatically manage signing**
2. **Team** 下拉里选择你自己的 Apple ID（用免费账号也能选到，显示为 `Personal Team`）
3. **Bundle Identifier** 必须改掉，因为 `com.dingjiayuan.wake-up-timeTable` 这个 ID 已经被原作者占用。改成任意全局唯一的值，例如：
   ```
   com.yourname.wakeup.timetable
   ```

### 步骤 4 · 处理 App Groups（最容易踩坑的一步）

本项目用 App Group 让「主 App」和「桌面小组件」共享同一个数据库，配置文件里写死的是原作者的分组：

```
group.com.dingjiayuan.wake-up-timeTable
```

**这个分组归属于原作者的开发者账号，你无法直接使用**，必须换成你自己的。需要改 **两处**（如果两处不一致，App 会在启动时直接闪退）：

1. **Entitlements 文件**：`wake-up-timeTable/wake_up_timeTable.entitlements`

   ```xml
   <key>com.apple.security.application-groups</key>
   <array>
       <string>group.com.yourname.wakeup.timetable</string>
   </array>
   ```

   > 改完回到 Xcode 的 **Signing & Capabilities** 页，点 `+ Capability` 添加 **App Groups**（如果还没有），然后在里面新建并勾选你上面写的这个分组。

2. **代码里的常量**：`wake-up-timeTable/Utilities/Constants.swift`

   ```swift
   static let appGroupIdentifier = "group.com.yourname.wakeup.timetable"
   ```

> ⚠️ **免费 Apple ID 的坑**：App Groups 属于**付费开发者账号（$99/年）才有的能力**。用免费账号时，Xcode 会报类似 `App Groups capability is not supported` / 无法注册分组，而且本项目在 `Constants.swift` 里对 App Group 容器做了强制解包，**即使侥幸编译通过，启动时也会闪退**。
>
> 只想自己试用、不打算买开发者账号的话，需要自己动手改造：把 `Constants.swift` 里的 `appGroupContainerURL` 从 `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` 改成普通的沙盒目录（如 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]`），并移除 entitlements 里的 App Groups。代价是**小组件无法和主 App 共享数据**。

### 步骤 5 · 连接 iPhone 并打开开发者模式

1. 用数据线把 iPhone 连到 Mac，解锁手机，在手机上点「信任此电脑」
2. 在 iPhone 上开启开发者模式：**设置 → 隐私与安全性 → 开发者模式 → 打开**，然后按提示重启手机

### 步骤 6 · 编译并安装

1. 回到 Xcode，顶部中间的运行目标里把设备从模拟器切成你自己的 iPhone
2. 按 **⌘R**（或点左上角 ▶️）开始编译安装

首次运行会失败在中途弹出提示，这是正常的，接着做步骤 7。

### 步骤 7 · 在手机上信任这个 App

因为不是从 App Store 安装的，iOS 会拦截一次：

**iPhone → 设置 → 通用 → VPN 与设备管理 → 开发者 App → 选择你的 Apple ID → 信任**

然后再在 Xcode 里按一次 **⌘R**，App 就会出现在手机桌面上了。

> **免费账号注意**：用免费 Apple ID 签名的 App **只有 7 天有效期**，7 天后打开会提示「无法使用」。解决办法是把手机连上 Mac 再按一次 ⌘R 重新安装；想长期使用请加入付费开发者计划。

---

## 三、首次使用：导入你的课表

App 装好后，按这个顺序操作就能看到自己的课表：

1. **允许通知**：首次打开会请求通知权限，同意后才能收到「上课提醒」。之后也可以在 **设置 → 提醒** 里开关，并设置提前多少分钟提醒。

2. **导入课表**：进入 **设置 → 从教务系统导入**，页面里是一个带日志的导入工具：

   - 点 **「打开登录页」**，会弹出一个内置浏览器，加载的是大工教务系统 `jxgl.dlut.edu.cn/student/home`
   - 服务器会自动跳转到统一身份认证页，在这里输入你的**学号 + 统一身份认证密码**（可能还需要短信验证）
   - 登录成功后会回到学生主页，点网页左上角的 **「完成」** 关闭它。此时页面顶部会显示「已登录（N Cookie）」和绿色对勾
   - 点 **「执行导入」**，等待日志输出，会出现「已获取 N 门课程」

3. **回到课表**：切到 **课表** 标签页就能看到本周的课表了。

4. **确认学期**：到 **设置 → 当前学期** 里检查学期名称和开学日期。**开学日期决定「现在第几周」的计算**，如果和学校实际安排对不上，周次就会偏。

一句话记住这个顺序：**先登录，再导入，最后核对学期起始日。**

---

## 四、桌面小组件（需要自己接一下）

> ⚠️ **重要**：仓库里的 `TimetableWidget/` 目录**只有小组件的源码，并没有接进 Xcode 工程**。当前 `.xcodeproj` 里只有 `wake-up-timeTable` 一个 target，所以按上面步骤编译出来的 App **不包含桌面小组件**。

仓库里已经写好的小组件代码有两个：

| 文件 | 作用 |
|------|------|
| `TimetableWidget/TodayCoursesWidget.swift` | 今日课程小组件 |
| `TimetableWidget/NextCourseWidget.swift` | 下一节课小组件 |

想让它们跑起来，需要自己在 Xcode 里：

1. **File → New → Target… → Widget Extension**，名字填 `TimetableWidget`，**不要**勾选 "Include Live Activity"
2. 把 Xcode 自动生成的那些模板文件删掉，改为添加 `TimetableWidget/` 目录下的这几个文件：`TimetableWidgetBundle.swift`、`TodayCoursesWidget.swift`、`NextCourseWidget.swift`、`WidgetEntry.swift`、`WidgetDataProvider.swift`
3. 给这个新 target 在 **Signing & Capabilities** 里加上和主 App **完全相同**的 App Groups 分组（这是它能读到课程数据的前提）
4. 把 `TimetableWidget/TimetableWidgetExtension.entitlements` 里的分组名也改成你自己的
5. 主 App 的 **General → Frameworks, Libraries, and Embedded Content** 里确认新扩展已被嵌入
6. 重新 ⌘R，然后在 iPhone 桌面长按 → 左上角 `+` → 搜索 App 名字添加小组件

> 小组件数据读取依赖 App Group，所以只要你的账号不支持 App Groups（免费账号），小组件就无法正常工作。

---

## 五、常见问题

**Q：编译时报 `Signing for "wake-up-timeTable" requires a development team`**
选中 TARGET → Signing & Capabilities → 在 Team 里选择一个你的 Apple ID 即可（见步骤 3）。

**Q：提示 App Groups 能力不可用 / 无法创建分组**
这是免费 Apple ID 的限制。要么加入付费开发者计划，要么按 [步骤 4](#步骤-4--处理-app-groups最容易踩坑的一步) 的说明改造代码去掉 App Group 依赖（代价是小组件不可用）。

**Q：App 一打开就闪退**
九成是 App Group 配置不一致。请检查 `Constants.swift` 里的 `appGroupIdentifier` 和 `wake_up_timeTable.entitlements` 里的字符串是否**完全一致**，且这个分组已在你的账号下创建成功。

**Q：手机上提示「未受信任的开发者」/ 无法打开 App**
到 **设置 → 通用 → VPN 与设备管理** 里信任你的开发者证书（见步骤 7）。

**Q：用了一周之后 App 突然打不开了**
免费 Apple ID 签名的证书有效期只有 7 天。连上 Mac 重新 ⌘R 安装一次即可。

**Q：登录页打不开 / 一直转圈 / 导入失败**
- 校外网络访问教务系统通常需要先连**校园 VPN**
- 教务系统本身在维护或临时不可用时也会失败，换个时间再试
- Cookie 过期（通常几小时后）后会导入失败，点「清除登录状态」重新登录一次
- 页面顶部的 **输出日志** 会写明失败在哪一步，可以先自己看一眼；日志右上角的复制按钮可以把内容拷出来排查

**Q：我的 iPhone 系统版本低于 iOS 26.5，装不上 / 提示版本不兼容**
工程当前的 Deployment Target 写的是 `26.5`。设计文档 `DESIGN.md` 里标注的目标其实是 iOS 17.0，所以理论上可以下调：在 **TARGETS → wake-up-timeTable → Build Settings → iOS Deployment Target** 改成你想要的版本（最低 17.0，因为代码用了 SwiftData 和 `@Observable`）。**注意这是未经回归测试的改动**，改完请自己确认没有报错、功能正常。

**Q：Xcode 打不开这个工程 / 提示版本不支持**
工程是用较新的 Xcode 创建的，请把 Xcode 升级到 26 或更新版本。

---

## 六、项目结构

```
wake-up-timeTable/
├── wake-up-timeTable.xcodeproj        # Xcode 工程（当前仅含主 App target）
├── Info.plist                         # 主 App 的 Info.plist（含教务系统 HTTP 例外配置）
│
├── wake-up-timeTable/                 # 主 App 源码
│   ├── App/
│   │   └── wake_up_timeTableApp.swift # 入口：初始化 SwiftData、注册通知
│   ├── Models/                        # Course / CourseSchedule / Semester / Exam / Enums
│   ├── Services/                      # 业务服务
│   │   ├── CourseService.swift        # 课程增删改查
│   │   ├── SemesterService.swift      # 学期管理
│   │   ├── CurrentCourseService.swift # 当前课 / 下一节课计算
│   │   ├── NotificationManager.swift  # 上课提醒通知
│   │   └── MockDataGenerator.swift    # 早期示例数据（启动时会自动清理）
│   ├── DUTImport/                     # 大工教务系统导入
│   │   ├── DUTImportService.swift     # 登录、Cookie/Keychain、课表 API、数据解析
│   │   └── DUTImportDebugView.swift   # 导入界面（设置 → 从教务系统导入）
│   ├── ViewModels/                    # MVVM 的 ViewModel（今日 / 课表 / 日历 / 设置）
│   ├── Views/
│   │   ├── MainTabView.swift          # 四个标签页：今日 · 课表 · 日历 · 设置
│   │   ├── Today/                     # 今日：正在上的课、下一节课、剩余时间
│   │   ├── Timetable/                 # 课表：周视图、课程卡片、编辑与配色
│   │   ├── Calendar/                  # 日历视图
│   │   └── Settings/                  # 设置、学期管理
│   ├── Utilities/
│   │   ├── Constants.swift            # 节次时间表、App Group ID、配色板等全局常量
│   │   └── ReminderSettings.swift     # 提醒设置项
│   └── Extensions/                    # Color / Date 扩展
│
├── TimetableWidget/                   # 小组件源码（⚠️ 尚未接入工程，见第四节）
├── DOCS/
│   └── DUT-IMPORT-ANALYSIS.md         # 教务系统抓包分析与导入方案
└── DESIGN.md                          # 完整软件设计文档
```

---

## 七、技术栈

| 项目 | 选型 |
|------|------|
| UI | SwiftUI |
| 持久化 | SwiftData（存放在 App Group 共享容器中） |
| 架构 | MVVM（协议 + Environment 注入依赖） |
| 响应式 | Combine + `@Observable` |
| 小组件 | WidgetKit |
| 导入教务系统 | WKWebView 登录 + Cookie 缓存（Keychain）+ 课表接口解析 |
| 最低系统 | iOS 26.5（当前工程配置；设计目标为 iOS 17.0） |

---

## 八、声明

- 本项目是**个人自用作品，与大连理工大学官方无关**，不是学校发布的 App。
- **密码不会被保存**：登录是在 App 内置的浏览器里打开学校官方登录页完成的，密码只提交给学校服务器；App 只缓存登录后的 Cookie，且存放在系统 Keychain 中。
- 课表数据只在你的设备本地存储，不经过任何第三方服务器。
- 导入功能通过加载学校官方页面实现，请遵守学校的信息化系统使用规定，不要高频请求教务系统。
- 项目目前未附带开源许可证文件；如需转载或分发，请先联系作者。

---

## 相关文档

- [DESIGN.md](DESIGN.md) —— 完整的软件设计文档（架构、数据模型、Widget 设计、开发路线）
- [DOCS/DUT-IMPORT-ANALYSIS.md](DOCS/DUT-IMPORT-ANALYSIS.md) —— 教务系统接口抓包分析、登录流程与数据解析方案
