//
//  DUTImportDebugView.swift
//  wake-up-timeTable
//
//  独立测试 UI — 不修改 App 架构
//  提供 WKWebView 登录 + 全链路导入测试
//
//  登录入口: http://jxgl.dlut.edu.cn/student/home
//  服务器自动处理 SSO 跳转，不要手动拼接 SSO 地址
//

import SwiftUI
import SwiftData
import WebKit
import WidgetKit

// MARK: - Main Debug View

struct DUTImportDebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var service = DUTImportService()
    @State private var showWebView = false

    @State private var jwBaseURLText: String = "http://jxgl.dlut.edu.cn"
    @State private var schedulePagePathText: String = "/student/for-std/course-table"
    @State private var apiPathText: String = "/student/for-std/course-table/get-data"
    @State private var semesterStartDateText: String = ""

    @State private var isTesting: Bool = false

    /// 登录入口 — 唯一 URL，服务器自行处理 SSO 跳转
    private var loginEntryURL: String {
        "\(jwBaseURLText)/student/home"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    infoBanner
                    configSection
                    loginSection
                    testSection
                    resultSection
                }
                .padding()
            }
            .navigationTitle("DUT 教务接口测试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空日志") { service.clearLog() }
                }
            }
            .sheet(isPresented: $showWebView) {
                loginWebViewSheet
            }
            .onAppear {
                service.loadSavedCookies()
            }
        }
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("已确认的教务系统信息", systemImage: "info.circle.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.blue)
            Text("""
            • 登录入口: http://jxgl.dlut.edu.cn/student/home
            • 课表 API: GET /student/for-std/course-table/get-data
            • 认证方式: 服务器自行跳转统一身份认证
            • semesterId: 每次导入自动获取
            • Cookie: 持久化到 Keychain
            """)
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.05)))
    }

    // MARK: - Config Section

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("教务系统配置", systemImage: "gearshape.2").font(.headline)
            configRow(label: "Base URL", text: $jwBaseURLText)
            configRow(label: "课表页面路径", text: $schedulePagePathText)
            configRow(label: "课表 API 路径", text: $apiPathText)
            configRow(label: "学期开始日期 (yyyy-MM-dd，留空=自动检测)", text: $semesterStartDateText)

            Button("应用配置") {
                service.jwBaseURL = jwBaseURLText
                service.schedulePagePath = schedulePagePathText
                service.scheduleAPIPath = apiPathText
                service.log("配置已更新: \(jwBaseURLText)\(apiPathText)")
                if !semesterStartDateText.isEmpty {
                    if parseManualDate(semesterStartDateText) != nil {
                        service.log("📅 学期开始日期已设置: \(semesterStartDateText)（导入时生效）")
                    } else {
                        service.log("⚠️ 日期格式无效: \(semesterStartDateText)，请使用 yyyy-MM-dd")
                    }
                } else {
                    service.log("📅 学期开始日期: 自动检测")
                }
            }
            .buttonStyle(.bordered).tint(.blue)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
    }

    private func configRow(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder).font(.caption)
                .autocapitalization(.none).disableAutocorrection(true)
        }
    }

    // MARK: - Login Section

    private var loginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("登录", systemImage: "person.badge.key").font(.headline)

            Text("点击后 WKWebView 加载学生主页。如未登录，服务器会自动跳转到统一身份认证。请观察日志中的 URL 变化。")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Button {
                    service.log("-- 打开登录入口: \(loginEntryURL) --")
                    showWebView = true
                } label: {
                    Label("打开登录页", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent).tint(.blue)

                Spacer()

                if service.isLoggedIn {
                    Label("已登录 (\(service.cookies.count) Cookie)", systemImage: "checkmark.seal.fill")
                        .font(.caption).foregroundStyle(.green)
                } else {
                    Label("未登录", systemImage: "xmark.seal")
                        .font(.caption).foregroundStyle(.red)
                }
            }

            if service.isLoggedIn {
                DisclosureGroup("Cookie 详情 (\(service.cookies.count))") {
                    ForEach(service.cookies, id: \.name) { cookie in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cookie.name).font(.caption2).fontWeight(.medium)
                            Text("Domain: \(cookie.domain)  Path: \(cookie.path)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .font(.caption)

                Button(role: .destructive) {
                    service.clearKeychain()
                } label: {
                    Label("清除登录状态", systemImage: "trash").font(.caption)
                }
                .buttonStyle(.bordered).tint(.red)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("导入测试", systemImage: "play.circle").font(.headline)

            Text("使用已捕获的 Cookie 完成全链路导入")
                .font(.caption).foregroundStyle(.secondary)

            Button {
                runImport()
            } label: {
                HStack {
                    if service.isFetching { ProgressView().scaleEffect(0.8) }
                    Text("执行导入")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.green)
            .disabled(!service.isLoggedIn || service.isFetching)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
    }

    // MARK: - Result Section

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("输出日志", systemImage: "terminal").font(.headline)
                Spacer()
                if service.isFetching { ProgressView().scaleEffect(0.7) }
                if !service.parsedCourses.isEmpty {
                    Text("\(service.parsedCourses.count) 门")
                        .font(.caption).foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                }
                if !service.outputLog.isEmpty {
                    Button {
                        UIPasteboard.general.string = service.outputLog
                    } label: {
                        Image(systemName: "doc.on.doc").font(.caption)
                    }
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(service.outputLog.isEmpty
                         ? "使用说明:\n1. 点击「打开登录页」\n2. 在 WebView 中完成登录\n3. 点击「完成」关闭 WebView\n4. 点击「执行导入」"
                         : service.outputLog)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("logBottom")
                }
                .frame(minHeight: 400)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                .onChange(of: service.outputLog) { _, _ in
                    withAnimation { proxy.scrollTo("logBottom", anchor: .bottom) }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 4))
    }

    // MARK: - Login WebView Sheet

    private var loginWebViewSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "globe").font(.caption).foregroundStyle(.blue)
                    Text("入口: \(loginEntryURL)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.systemGray6))

                DUTLoginWebView(service: service, targetURL: loginEntryURL)

                Text("登录完成后点击右上角「完成」，Cookie 会自动保存到 Keychain")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.systemGray6))
            }
            .navigationTitle("教务系统登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showWebView = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        if let wv = service.webView {
                            service.captureCookies(from: wv)
                        }
                        showWebView = false
                    }
                }
            }
        }
    }

    // MARK: - Semester Helpers

    /// 根据当前日期自动推算学期名称（如 "2025-2026 第二学期"）
    private func autoSemesterName() -> String {
        let now = Date()
        let cal = Calendar.current
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)
        // 中国学年：9月-1月=第一学期（秋季），2月-7月=第二学期（春季）
        if month >= 8 {
            return "\(year)-\(year + 1) 第一学期"
        } else if month <= 1 {
            // 1月属于上一年的秋季学期
            return "\(year - 1)-\(year) 第一学期"
        } else {
            return "\(year - 1)-\(year) 第二学期"
        }
    }

    /// 从学期名称推断开始日期，保证返回周一
    /// 如 "2024-2025学年 第二学期" → 2025年2月第4周的周一
    private func inferSemesterStartDate(from name: String) -> Date {
        let cal = Calendar.current
        let numbers = name.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }.compactMap { Int($0) }

        if name.contains("第二") || name.contains("春季") || name.contains("春") {
            let year = numbers.count >= 2 ? numbers[1] : (numbers.first ?? cal.component(.year, from: Date()))
            return mondayOfWeek(year: year, month: 2, day: 24)
        } else {
            let year = numbers.first ?? cal.component(.year, from: Date())
            return mondayOfWeek(year: year, month: 9, day: 1)
        }
    }

    /// 返回指定日期所在周的周一，保证 Semester.startDate 始终是周一
    private func mondayOfWeek(year: Int, month: Int, day: Int) -> Date {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        guard let date = cal.date(from: comps) else { return Date() }
        return date.startOfWeek
    }

    /// 解析手动输入的日期字符串（支持 yyyy-MM-dd、yyyy/MM/dd）
    private func parseManualDate(_ str: String) -> Date? {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        let formatters: [DateFormatter] = {
            let fmts: [String] = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyyMMdd"]
            return fmts.map { f in
                let fmt = DateFormatter()
                fmt.dateFormat = f
                fmt.locale = Locale(identifier: "en_US_POSIX")
                return fmt
            }
        }()
        for fmt in formatters {
            if let date = fmt.date(from: trimmed) {
                return date.startOfWeek
            }
        }
        return nil
    }

    /// 创建学期并设为当前
    private func createSemester(name: String, startDate: Date, totalWeeks: Int,
                                 service semesterService: SemesterService) -> Semester {
        let semester = Semester(name: name, startDate: startDate, totalWeeks: totalWeeks,
                                startWeekNumber: 1, isCurrent: true)
        modelContext.insert(semester)
        try? modelContext.save()
        service.log("📅 创建学期: \(name), 开始日期: \(startDate), 共 \(totalWeeks) 周")
        return semester
    }

    // MARK: - Import

    private func runImport() {
        isTesting = true
        service.log("")
        service.log("===== DUT 教务导入 =====")
        service.log("时间: \(Date())")

        Task {
            // Step 1: Cookie
            service.log("")
            service.log("-- [Step 1/7] Cookie --")
            guard service.isLoggedIn else {
                service.log("FAIL: 未登录"); isTesting = false; return
            }
            service.log("OK: \(service.cookies.count) Cookie")
            for c in service.cookies {
                service.log("   \(c.name) | Domain: \(c.domain) | Path: \(c.path)")
            }

            // Step 2-4: fetch + parse
            let fetchOK = await service.fetchCourseData()

            guard fetchOK, !service.parsedCourses.isEmpty else {
                service.log("FAIL: 链路在 Step 2-4 中断")
                if !service.isLoggedIn {
                    service.log("Cookie 已过期，请重新登录")
                    showWebView = true
                }
                isTesting = false; return
            }

            // Step 5: 写入 SwiftData
            service.log("")
            service.log("-- [Step 5/7] 写入 SwiftData --")
            let semesterService = SemesterService(modelContext: modelContext)

            // 始终使用教务系统发现的学期信息创建/更新学期
            // 不使用之前可能存在的 Mock 学期
            let semesterName = service.discoveredSemesterName ?? autoSemesterName()
            // 优先级：手动输入 > 从 HTML/API 自动提取 > 从学期名称推算
            let semesterStartDate: Date = {
                if !semesterStartDateText.isEmpty,
                   let date = parseManualDate(semesterStartDateText) {
                    service.log("📅 使用手动输入的学期开始日期: \(date)")
                    return date
                }
                if let discovered = service.discoveredSemesterStartDate {
                    service.log("📅 使用自动检测的学期开始日期: \(discovered)")
                    return discovered
                }
                let inferred = inferSemesterStartDate(from: semesterName)
                service.log("📅 使用推算的学期开始日期: \(inferred)（学期名: \(semesterName)）")
                return inferred
            }()
            // 从已解析课程中推算 totalWeeks（最大 endWeek + 2 周缓冲）
            let maxEndWeek = service.parsedCourses.flatMap { $0.schedules }.map(\.endWeek).max() ?? 18
            let totalWeeks = max(maxEndWeek + 2, 18)

            // 如果已有当前学期但其名称与教务系统发现的不同，说明是 Mock 数据，需要更换
            let semester: Semester = {
                if let existing = semesterService.fetchCurrentSemester() {
                    if existing.name == semesterName {
                        // 同一学期 — 更新 startDate 和 totalWeeks（防止旧数据残留）
                        let oldStart = existing.startDate
                        existing.startDate = semesterStartDate
                        existing.totalWeeks = totalWeeks
                        try? modelContext.save()
                        service.log("当前学期: \(existing.name)")
                        if oldStart != semesterStartDate {
                            service.log("📅 更新学期开始日期: \(oldStart) → \(semesterStartDate)")
                        }
                        return existing
                    } else {
                        service.log("⚠️ 检测到过期学期 '\(existing.name)'，切换为 '\(semesterName)'")
                        existing.isCurrent = false
                        try? modelContext.save()
                        return createSemester(name: semesterName, startDate: semesterStartDate,
                                              totalWeeks: totalWeeks, service: semesterService)
                    }
                } else {
                    return createSemester(name: semesterName, startDate: semesterStartDate,
                                          totalWeeks: totalWeeks, service: semesterService)
                }
            }()

            // 清理 Mock 数据：删除不属于本学期的课程
            let allCourses = (try? modelContext.fetch(FetchDescriptor<Course>())) ?? []
            let mockCourses = allCourses.filter { $0.semester?.isCurrent == false }
            if !mockCourses.isEmpty {
                for c in mockCourses { modelContext.delete(c) }
                try? modelContext.save()
                service.log("🧹 清理 Mock 课程: \(mockCourses.count) 门")
            }

            let allExisting = (try? modelContext.fetch(FetchDescriptor<Course>())) ?? []
            var existingByCode: [String: Course] = [:]
            var existingByName: [String: Course] = [:]
            for c in allExisting {
                if let code = c.code { existingByCode[code] = c }
                existingByName[c.name] = c
            }

            var writeCount = 0, updateCount = 0
            for dto in service.parsedCourses {
                // 匹配已存在课程：优先按 code，其次按名称（兼容 code 为 nil 的情况）
                let existing: Course?
                if let code = dto.code, let c = existingByCode[code] {
                    existing = c
                } else {
                    existing = existingByName[dto.name]
                }

                if let course = existing {
                    // 防止同一门课被多个 DTO 重复命中
                    if let code = course.code { existingByCode.removeValue(forKey: code) }
                    existingByName.removeValue(forKey: course.name)

                    // 教务系统为权威数据源：更新基本信息并重建时段
                    course.name = dto.name
                    course.code = dto.code
                    course.teacherName = dto.teacherName
                    course.location = dto.location
                    course.courseType = dto.courseType
                    course.credits = dto.credits
                    course.note = dto.note
                    course.colorHex = dto.courseType.defaultColorHex
                    applySchedules(dto.schedules, to: course)
                    service.log("  ↻ \(dto.name) (\(dto.schedules.count) 时段)")
                    updateCount += 1
                } else {
                    let course = Course(name: dto.name, code: dto.code,
                                        teacherName: dto.teacherName, location: dto.location,
                                        colorHex: dto.courseType.defaultColorHex,
                                        courseType: dto.courseType, credits: dto.credits, note: dto.note)
                    course.semester = semester
                    modelContext.insert(course)
                    applySchedules(dto.schedules, to: course)
                    service.log("  + \(dto.name) (\(dto.schedules.count) 时段)")
                    writeCount += 1
                }
            }

            // Step 6: 保存
            service.log("")
            service.log("-- [Step 6/7] 保存 --")
            do {
                try modelContext.save()
                service.log("OK: 新增 \(writeCount), 更新 \(updateCount)")
            } catch {
                service.log("FAIL: \(error.localizedDescription)")
                isTesting = false; return
            }

            // Step 7: 刷新
            service.log("")
            service.log("-- [Step 7/7] 刷新 --")
            WidgetCenter.shared.reloadAllTimelines()
            service.log("OK")

            service.log("")
            service.log("===== 导入完成: 新增 \(writeCount) 门, 更新 \(updateCount) 门 =====")

            isTesting = false
        }
    }

    /// 将解析出的时段写入课程，先清除旧时段再重建（教务系统为权威数据源）
    private func applySchedules(_ schedules: [ScheduleInput], to course: Course) {
        for s in course.schedules ?? [] { modelContext.delete(s) }
        course.schedules = []
        for s in schedules {
            let schedule = CourseSchedule(
                dayOfWeek: s.dayOfWeek, startPeriod: s.startPeriod,
                endPeriod: s.endPeriod, weekType: s.weekType,
                startWeek: s.startWeek, endWeek: s.endWeek, location: s.location)
            schedule.course = course
            modelContext.insert(schedule)
            course.schedules?.append(schedule)
        }
    }
}

// MARK: - WKWebView Representable

struct DUTLoginWebView: UIViewRepresentable {
    let service: DUTImportService
    let targetURL: String

    func makeCoordinator() -> Coordinator {
        Coordinator(service: service)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        context.coordinator.webView = webView
        service.webView = webView

        if let url = URL(string: targetURL) {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
                             forHTTPHeaderField: "User-Agent")
            webView.load(request)
            service.log("-- 初始加载: \(targetURL) --")
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        let service: DUTImportService
        weak var webView: WKWebView?

        init(service: DUTImportService) {
            self.service = service
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                if url.contains("sso") || url.contains("login") || !url.contains("jxgl.dlut.edu.cn") {
                    service.log("[跳转] \(url.prefix(150))")
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            if let url = webView.url?.absoluteString {
                service.log("[加载中] \(url.prefix(120))")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            let urlString = url.absoluteString
            let title = webView.title ?? "(无标题)"

            service.log("[完成] URL: \(urlString.prefix(150))")
            service.log("[完成] 标题: \(title)")

            service.captureCookies(from: webView)
            detectLoginState(urlString: urlString, title: title)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            service.log("[失败] 无法加载: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            service.log("[失败] 导航错误: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        private func detectLoginState(urlString: String, title: String) {
            if urlString.contains("sso.dlut.edu.cn") {
                service.log(">>> 已跳转到统一身份认证，请登录 <<<")
            } else if urlString.contains("jxgl.dlut.edu.cn/student/") && !urlString.contains("/login") {
                service.log(">>> 已进入教务系统 <<<")
            } else if urlString.contains("jxgl.dlut.edu.cn") {
                service.log(">>> 教务系统页面: \(title) <<<")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DUTImportDebugView()
}
