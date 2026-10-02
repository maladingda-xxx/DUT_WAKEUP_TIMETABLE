//
//  DUTImportService.swift
//  wake-up-timeTable
//
//  独立测试模块 — 不依赖 App 架构
//  职责: Cookie 管理、Keychain、API 请求、JSON 解析、DTO 映射
//
//  数据来源: 大连理工大学综合教学管理系统
//  登录入口: https://jxgl.dlut.edu.cn/student/home
//  课表 API: GET /student/for-std/course-table/get-data
//
//  认证流程:
//    WKWebView → https://jxgl.dlut.edu.cn/student/home
//    → 服务器自动跳转统一身份认证 → 用户输入学号密码
//    → 登录成功自动返回 /student/home → 捕获 Cookie
//
//  已确认数据结构:
//    { lessons: [{ course, teacherAssignmentList, scheduleText }] }
//

import Foundation
import WebKit
import Security

/// 教务系统导入服务（纯逻辑，不涉及 UI）
@Observable
final class DUTImportService {

    // MARK: - Configuration

    /// 教务系统 Base URL（已确认: HTTP）
    var jwBaseURL: String = "http://jxgl.dlut.edu.cn"

    /// 学生主页 — 唯一登录入口
    /// 服务器自动处理 SSO 跳转，不要手动拼接 SSO 地址
    var studentHomeURL: String = "http://jxgl.dlut.edu.cn/student/home"

    /// 课表页面路径
    var schedulePagePath: String = "/student/for-std/course-table"

    /// 课表数据 API 路径
    var scheduleAPIPath: String = "/student/for-std/course-table/get-data"

    /// 业务类型 ID
    var bizTypeId: Int = 2

    /// 学期 ID（每次导入时自动从教务系统获取）
    var semesterId: Int = 442

    /// 从教务系统发现的学期名称（如 "2024-2025学年 第二学期"）
    private(set) var discoveredSemesterName: String?

    /// 从教务系统发现的学期开始日期
    private(set) var discoveredSemesterStartDate: Date?

    // MARK: - State

    private(set) var isLoggedIn: Bool = false
    private(set) var cookies: [HTTPCookie] = []
    private(set) var outputLog: String = ""
    private(set) var parsedCourses: [CourseImportDTO] = []
    private(set) var rawJSON: String = ""
    private(set) var isFetching: Bool = false

    /// WKWebView 弱引用（由 LoginWebView 设置）
    weak var webView: WKWebView?

    /// 当前学年
    var academicYear: Int = 2026

    /// 学期：3=秋季，12=春季
    var term: Int = 3

    // MARK: - Keychain Keys

    private let keychainService = "com.dingjiayuan.wake-up-timeTable.dut"
    private let keychainAccount = "dut-cookies"

    // MARK: - Cookie 管理

    /// 从 WKWebView 的 WKHTTPCookieStore 读取所有 Cookie
    func captureCookies(from webView: WKWebView) {
        let store = webView.configuration.websiteDataStore
        store.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            self.cookies = cookies

            self.log("📦 Cookie 捕获:")
            self.log("   数量: \(cookies.count)")
            for c in cookies {
                self.log("   ┌─ \(c.name)")
                self.log("   │  Domain: \(c.domain)")
                self.log("   │  Path: \(c.path)")
                self.log("   │  Value: \(c.value.prefix(30))...")
                self.log("   └─")
            }

            // 检查是否获得了教务系统所需的认证 Cookie
            let jwCookies = cookies.filter { $0.domain.contains("dlut.edu.cn") }
            self.isLoggedIn = !jwCookies.isEmpty

            if self.isLoggedIn {
                self.log("✅ 已获得 jxgl.dlut.edu.cn 认证 Cookie (\(jwCookies.count) 个)")
            } else {
                self.log("⚠️ 未检测到 dlut.edu.cn 域的 Cookie")
            }

            // 同步到共享 Cookie 存储（URLSession 自动使用）
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }

            // 保存到 Keychain
            self.saveCookiesToKeychain(cookies)
        }
    }

    /// 构建 Cookie 请求头
    private func cookieHeader() -> String {
        cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    // MARK: - Keychain

    private func saveCookiesToKeychain(_ cookies: [HTTPCookie]) {
        guard !cookies.isEmpty else { return }
        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: cookies,
                requiringSecureCoding: false
            )
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount,
                kSecValueData as String: data,
            ]
            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
            log("🔑 Cookie 已保存到 Keychain")
        } catch {
            log("⚠️ Keychain 保存失败: \(error.localizedDescription)")
        }
    }

    private func loadCookiesFromKeychain() -> [HTTPCookie] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let cookies = try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, HTTPCookie.self],
                from: data
              ) as? [HTTPCookie] else {
            return []
        }
        log("🔑 从 Keychain 加载了 \(cookies.count) 个 Cookie")
        return cookies
    }

    func loadSavedCookies() {
        let saved = loadCookiesFromKeychain()
        guard !saved.isEmpty else {
            log("🔑 Keychain 中无已保存的 Cookie")
            return
        }
        self.cookies = saved
        self.isLoggedIn = saved.contains { $0.domain.contains("dlut.edu.cn") }
        for cookie in saved {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        log("✅ 已从 Keychain 恢复 \(saved.count) 个 Cookie")
    }

    func clearKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        cookies = []
        isLoggedIn = false
        log("🗑 Keychain 已清除")
    }

    // MARK: - 认证验证

    /// 验证当前 Cookie 是否有效
    /// 通过 GET /student/for-std/course-table/get-data 测试
    /// - Returns: true 表示认证有效，false 表示需要重新登录
    func verifyAuthentication() async -> Bool {
        guard !cookies.isEmpty else {
            log("❌ Authentication Failed — 无 Cookie")
            return false
        }

        guard let url = URL(string: "\(jwBaseURL)\(scheduleAPIPath)?bizTypeId=\(bizTypeId)&semesterId=\(semesterId)") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("\(jwBaseURL)\(schedulePagePath)", forHTTPHeaderField: "Referer")

        log("🔍 验证认证状态: GET \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            log("   ← HTTP \(statusCode)")

            if statusCode == 200 {
                // 检查是否返回了课表数据（而不是登录页 HTML）
                if let body = String(data: data, encoding: .utf8),
                   body.contains("\"lessons\"") || body.contains("\"course\"") {
                    log("✅ 认证有效 — 返回课表数据")
                    return true
                }
                // 200 但内容不是 JSON — 可能是登录页
                if let body = String(data: data, encoding: .utf8) {
                    let preview = String(body.prefix(500))
                    log("⚠️ HTTP 200 但内容非课表数据: \(preview)")
                    if preview.contains("login") || preview.contains("Login") ||
                       preview.contains("密码") || preview.contains("password") {
                        log("❌ Authentication Failed — 返回了登录页")
                        return false
                    }
                }
                // 其他 200 响应视为有效
                return true
            }

            if statusCode == 302 || statusCode == 301 {
                log("❌ Authentication Failed — 被重定向 (Cookie 已过期)")
                return false
            }

            log("❌ Authentication Failed — HTTP \(statusCode)")
            return false
        } catch {
            log("❌ Authentication Failed — 网络错误: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 课程数据获取

    /// 获取课表数据（主入口）
    func fetchCourseData() async -> Bool {
        guard isLoggedIn else {
            log("❌ 未登录，请先在 WebView 中完成登录")
            return false
        }

        isFetching = true
        defer { isFetching = false }

        // 先验证认证状态
        log("")
        log("═══ 验证认证状态 ═══")
        let isAuthValid = await verifyAuthentication()
        if !isAuthValid {
            log("")
            log("❌ Authentication Failed")
            log("💡 请重新打开登录页面完成认证")
            isLoggedIn = false
            return false
        }

        // 自动获取 semesterId
        log("")
        log("═══ [Step 2/7] 自动获取学期 ID ═══")
        if let discovered = await discoverSemesterId() {
            semesterId = discovered
            log("✅ [Step 2/7] 学期 ID: \(semesterId)")

            // 尝试用发现的 semesterId 获取学期详细信息（名称、开始日期）
            if discoveredSemesterName == nil || discoveredSemesterStartDate == nil {
                log("  🔍 尝试获取学期详细信息...")
                let detailPaths = [
                    "/student/for-std/semester/\(semesterId)",
                    "/student/api/semester/\(semesterId)",
                    "/api/semester/\(semesterId)",
                ]
                for path in detailPaths {
                    _ = await tryGetSemesterFromAPI(path: path)
                }
            }
        } else {
            log("⚠️ [Step 2/7] 无法自动获取，使用当前值: \(semesterId)")
        }

        log("")
        log("═══ [Step 3/7] 请求课表数据 API ═══")
        log("  URL: \(jwBaseURL)\(scheduleAPIPath)")
        log("  参数: bizTypeId=\(bizTypeId), semesterId=\(semesterId)")
        log("  Cookie: \(cookies.count) 个")
        for c in cookies {
            log("    \(c.name) (Domain: \(c.domain), Path: \(c.path))")
        }

        if let json = await tryGetScheduleDataAPI() {
            log("")
            log("  Response Body (前500字符):")
            log("  \(String(json.prefix(500)))")

            rawJSON = json
            log("")
            log("═══ [Step 4/7] 解析 JSON → CourseImportDTO ═══")
            parseAndMap(json)
            if !parsedCourses.isEmpty {
                log("✅ [Step 4/7] JSON lessons 数量: 已解析 \(parsedCourses.count) 门 CourseImportDTO")
                return true
            }
            log("❌ [Step 4/7] JSON 解析失败")
            return false
        }

        log("")
        log("❌ [Step 3/7] API 请求失败")
        return false
    }

    // MARK: - 学期 ID 自动发现

    private func discoverSemesterId() async -> Int? {
        log("  🔍 尝试从课表页面提取 semesterId 和学期开始日期...")
        if let html = await tryGetHTML(path: schedulePagePath) {
            // 先从 HTML 提取学期开始日期
            if discoveredSemesterStartDate == nil {
                extractSemesterStartDateFromHTML(html)
                if discoveredSemesterStartDate == nil {
                    // 诊断：输出 HTML 中包含日期/周号的关键片段
                    dumpHTMLExtractForDiagnosis(html)
                }
            }
            if let id = extractSemesterIdFromHTML(html) {
                log("  ✅ 从课表页面 HTML 提取到 semesterId: \(id)")
                return id
            }
            let candidates = extractAllPossibleSemesterIds(from: html)
            if !candidates.isEmpty {
                log("  📋 页面中发现的候选 ID: \(candidates)")
            }
        }

        let semesterAPIPaths = [
            "/student/for-std/semester",
            "/student/for-std/semester/list",
            "/student/api/semester",
            "/api/semester/current",
        ]
        for path in semesterAPIPaths {
            if let id = await tryGetSemesterFromAPI(path: path) {
                log("  ✅ 从 API \(path) 获取到 semesterId: \(id)")
                return id
            }
        }

        return nil
    }

    /// 从课程表 HTML 页面提取学期开始日期
    private func extractSemesterStartDateFromHTML(_ html: String) {
        let cal = Calendar.current
        let thisYear = cal.component(.year, from: Date())

        /// 用月日构建日期（智能处理跨年：如 6月 在 1月 之后用今年，如 1月 在 6月 之前用今年）
        func makeDate(month: Int, day: Int) -> Date? {
            var comps = DateComponents()
            comps.month = month; comps.day = day
            // 尝试今年
            comps.year = thisYear
            if let d = cal.date(from: comps), d <= Date().addingTimeInterval(86400 * 180) {
                return d
            }
            // 尝试去年
            comps.year = thisYear - 1
            return cal.date(from: comps)
        }

        // 模式1: 周选择器选项 "第1周 (6月29日-7月5日)" 或 "第1周(6/29-7/05)"
        let weekOptionPatterns = [
            #"第\s*(\d+)\s*周\s*[\(（]\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日[～\-~]\s*\d{1,2}\s*月\s*\d{1,2}\s*日[\)）]"#,
            #"第\s*(\d+)\s*周\s*[\(（]\s*(\d{1,2})/(\d{1,2})[～\-~]\s*\d{1,2}/\d{1,2}[\)）]"#,
        ]
        for pattern in weekOptionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let weekR = Range(match.range(at: 1), in: html),
               let monthR = Range(match.range(at: 2), in: html),
               let dayR = Range(match.range(at: 3), in: html),
               let weekNum = Int(html[weekR]),
               let month = Int(html[monthR]), let day = Int(html[dayR]),
               let date = makeDate(month: month, day: day) {
                // 反推学期开始: startDate = columnDate - (weekNum - 1) * 7
                let semesterStart = cal.date(byAdding: .day, value: -(weekNum - 1) * 7, to: date.startOfWeek)!
                discoveredSemesterStartDate = semesterStart
                log("  📅 从 HTML 周选择器提取: 第\(weekNum)周 \(month)/\(day) → 学期开始 \(semesterStart)")
                return
            }
        }

        // 模式2: 页面标题 "第3周（7月13日-7月19日）"
        let titlePattern = #"第\s*(\d+)\s*周\s*[\(（]\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日[～\-~]\s*\d{1,2}\s*月\s*\d{1,2}\s*日[\)）]"#
        if let regex = try? NSRegularExpression(pattern: titlePattern),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let weekR = Range(match.range(at: 1), in: html),
           let monthR = Range(match.range(at: 2), in: html),
           let dayR = Range(match.range(at: 3), in: html),
           let weekNum = Int(html[weekR]),
           let month = Int(html[monthR]), let day = Int(html[dayR]),
           let date = makeDate(month: month, day: day) {
            let semesterStart = cal.date(byAdding: .day, value: -(weekNum - 1) * 7, to: date.startOfWeek)!
            discoveredSemesterStartDate = semesterStart
            log("  📅 从 HTML 标题提取: 第\(weekNum)周 \(month)/\(day) → 学期开始 \(semesterStart)")
            return
        }

        // 模式3: 表头日期 + 星期 "6月29日 周一" — 假设显示的周是当前教学周
        let headerDatePattern = #"(\d{1,2})\s*月\s*(\d{1,2})\s*日.*?周\s*[一二三四五六日]"#
        if let regex = try? NSRegularExpression(pattern: headerDatePattern),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let monthR = Range(match.range(at: 1), in: html),
           let dayR = Range(match.range(at: 2), in: html),
           let month = Int(html[monthR]), let day = Int(html[dayR]),
           let date = makeDate(month: month, day: day) {
            discoveredSemesterStartDate = date.startOfWeek
            log("  📅 从 HTML 表头提取: \(month)/\(day) → 学期开始 \(date.startOfWeek)（假定为第1周）")
            return
        }

        // 模式4: JSON/JS 中的 semester 或 week 开始日期
        let jsDatePatterns = [
            #""startDate"\s*:\s*"(\d{4}-\d{2}-\d{2})""#,
            #""firstDay"\s*:\s*"(\d{4}-\d{2}-\d{2})""#,
            #"startDate\s*=\s*['"](\d{4}-\d{2}-\d{2})['"]"#,
            #"semesterStart\s*=\s*['"](\d{4}-\d{2}-\d{2})['"]"#,
            #"weekStart\s*=\s*['"](\d{4}-\d{2}-\d{2})['"]"#,
        ]
        for pattern in jsDatePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let dateR = Range(match.range(at: 1), in: html) {
                let dateStr = String(html[dateR])
                if let date = parseAPIDate(dateStr) {
                    discoveredSemesterStartDate = date.startOfWeek
                    log("  📅 从 HTML JS 变量提取学期开始日期: \(dateStr)")
                    return
                }
            }
        }

        log("  ⚠️ HTML 中未找到学期开始日期，将使用推算值")
    }

    /// 诊断：输出 HTML 中包含"周"或日期模式的关键片段，帮助分析页面格式
    private func dumpHTMLExtractForDiagnosis(_ html: String) {
        // 去掉 script/style 标签内容以减少噪音
        let cleaned = html
            .replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>",
                                  with: "", options: .regularExpression)
            .replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>",
                                  with: "", options: .regularExpression)

        // 搜索包含"周"的行
        let lines = cleaned.components(separatedBy: .newlines)
        let weekLines = lines.filter {
            $0.contains("周") || $0.contains("semester") || $0.contains("Semester")
        }.prefix(10)

        if !weekLines.isEmpty {
            log("  📋 HTML 中包含'周'的前10行:")
            for line in weekLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    log("    \(String(trimmed.prefix(200)))")
                }
            }
        }

        // 搜索日期模式 X月X日
        let datePattern = #"\d{1,2}\s*月\s*\d{1,2}\s*日"#
        if let regex = try? NSRegularExpression(pattern: datePattern) {
            let matches = regex.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned))
            if !matches.isEmpty {
                log("  📋 HTML 中找到 \(matches.count) 个日期模式（前5个）:")
                for match in matches.prefix(5) {
                    if let range = Range(match.range, in: cleaned) {
                        // 取日期前后各30字符的上下文
                        let start = cleaned.index(range.lowerBound, offsetBy: -30, limitedBy: cleaned.startIndex)
                            ?? cleaned.startIndex
                        let end = cleaned.index(range.upperBound, offsetBy: 30, limitedBy: cleaned.endIndex)
                            ?? cleaned.endIndex
                        let context = String(cleaned[start..<end])
                            .replacingOccurrences(of: "\n", with: " ")
                            .replacingOccurrences(of: "\r", with: "")
                        log("    ...\(context)...")
                    }
                }
            }
        }
    }

    private func extractSemesterIdFromHTML(_ html: String) -> Int? {
        let patterns = [
            #"<option[^>]+selected[^>]+value="(\d+)"[^>]*>"#,
            #"<option[^>]+value="(\d+)"[^>]+selected[^>]*>"#,
            #"(?:var|let|const)\s+semesterId\s*=\s*['"]?(\d+)['"]?"#,
            #"(?:var|let|const)\s+currentSemesterId\s*=\s*['"]?(\d+)['"]?"#,
            #""semesterId"\s*:\s*(\d+)"#,
            #"semesterId\s*:\s*(\d+)"#,
            #"semesterId\s*=\s*(\d+)"#,
            #"<input[^>]+name="semesterId"[^>]+value="(\d+)"[^>]*>"#,
            #"[?&]semesterId=(\d+)"#,
        ]
        for pattern in patterns {
            if let id = extractFirstInt(from: html, pattern: pattern),
               id > 0, id < 10000 { return id }
        }
        return nil
    }

    private func extractAllPossibleSemesterIds(from html: String) -> [Int] {
        var ids: Set<Int> = []
        let pattern = #"semester[^0-9]*?(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
                if let range = Range(match.range(at: 1), in: html),
                   let id = Int(html[range]), id > 0, id < 10000 {
                    ids.insert(id)
                }
            }
        }
        return Array(ids).sorted()
    }

    private func extractFirstInt(from html: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html),
              let value = Int(html[range]) else { return nil }
        return value
    }

    private func tryGetSemesterFromAPI(path: String) async -> Int? {
        guard let url = URL(string: "\(jwBaseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let jsonString = String(data: data, encoding: .utf8) else { return nil }

            if let id = extractSemesterIdFromHTML(jsonString) { return id }
            if let jsonData = jsonString.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                // 提取学期名称
                extractSemesterName(from: obj)

                if let id = obj["id"] as? Int { return id }
                if let id = obj["semesterId"] as? Int { return id }
                if let list = (obj["data"] ?? obj["list"]) as? [[String: Any]] {
                    for item in list {
                        if let isCurrent = item["isCurrent"] as? Bool, isCurrent {
                            extractSemesterName(from: item)
                            if let id = item["id"] as? Int { return id }
                        }
                    }
                    if list.count == 1 {
                        extractSemesterName(from: list[0])
                        if let id = list[0]["id"] as? Int { return id }
                    }
                }
            }
        } catch { }
        return nil
    }

    /// 从 API 返回的 JSON 字典中提取学期名称和开始日期
    private func extractSemesterName(from dict: [String: Any]) {
        if discoveredSemesterName == nil {
            // 尝试多个可能的字段名
            for key in ["name", "nameZh", "semesterName", "semester", "title", "label"] {
                if let name = dict[key] as? String, !name.isEmpty {
                    discoveredSemesterName = name
                    log("  📅 发现学期名称: \(name)")
                    break
                }
            }
        }
        if discoveredSemesterStartDate == nil {
            for key in ["startDate", "start", "beginDate", "firstDay"] {
                if let dateStr = dict[key] as? String, !dateStr.isEmpty {
                    if let date = parseAPIDate(dateStr) {
                        discoveredSemesterStartDate = date
                        log("  📅 发现学期开始日期: \(dateStr)")
                        break
                    }
                }
            }
        }
    }

    /// 解析 API 返回的日期字符串（支持多种格式）
    private func parseAPIDate(_ str: String) -> Date? {
        let formatters: [DateFormatter] = {
            let fmts: [String] = [
                "yyyy-MM-dd",
                "yyyy/MM/dd",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyyMMdd",
            ]
            return fmts.map { f in
                let fmt = DateFormatter()
                fmt.dateFormat = f
                fmt.locale = Locale(identifier: "en_US_POSIX")
                return fmt
            }
        }()
        for fmt in formatters {
            if let date = fmt.date(from: str) { return date }
        }
        return nil
    }

    // MARK: - HTTP 辅助

    private func tryGetHTML(path: String) async -> String? {
        guard let url = URL(string: "\(jwBaseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - 课表数据 API 请求

    private func tryGetScheduleDataAPI() async -> String? {
        guard var components = URLComponents(string: "\(jwBaseURL)\(scheduleAPIPath)") else {
            log("  ❌ URL 构造失败")
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "bizTypeId", value: String(bizTypeId)),
            URLQueryItem(name: "semesterId", value: String(semesterId)),
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookieHeader(), forHTTPHeaderField: "Cookie")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("\(jwBaseURL)\(schedulePagePath)", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
                         forHTTPHeaderField: "User-Agent")

        log("  → GET \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            log("  ← HTTP Status Code: \(statusCode)")
            log("  ← Response Size: \(data.count) bytes")

            if statusCode == 302 || statusCode == 301 {
                if let location = httpResponse?.value(forHTTPHeaderField: "Location") {
                    log("  ⚠️ 重定向到: \(location)")
                }
                log("  ❌ Authentication Failed — Cookie 已过期")
                return nil
            }

            guard statusCode == 200 else {
                if let body = String(data: data, encoding: .utf8) {
                    log("  ← Response Body: \(String(body.prefix(500)))")
                }
                return nil
            }

            guard let jsonString = String(data: data, encoding: .utf8) else {
                log("  ❌ 无法解码响应")
                return nil
            }

            if jsonString.contains("\"lessons\"") {
                log("  ✅ 响应包含 lessons 数组")
                return jsonString
            }

            log("  ⚠️ 响应不含 lessons: \(String(jsonString.prefix(300)))")
            return nil
        } catch {
            log("  ❌ 网络错误: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - JSON 解析与 DTO 映射

    private func parseAndMap(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else {
            log("❌ 无法将响应转为 Data")
            return
        }

        // 先从顶层 JSON 提取 currentWeek / weekIndices，反推学期日期
        // （比解析 HTML 正则可靠，能保证"第几周"与教务系统一致）
        extractSemesterInfo(from: data)

        let strategies: [(String, (Data) -> [CourseImportDTO]?)] = [
            ("{lessons: [...]}", { self.parseAsLessonsArray($0) }),
            ("{data: {lessons: [...]}}", { self.parseAsDataLessonsField($0) }),
            ("直接数组", { self.parseAsArray($0) }),
            ("{data: [...]}", { self.parseAsDataField($0) }),
            ("{courses: [...]}", { self.parseAsCoursesField($0) }),
        ]

        for (name, parser) in strategies {
            if let dtos = parser(data), !dtos.isEmpty {
                parsedCourses = dtos
                log("✅ 解析成功 (策略: \(name)): \(dtos.count) 门课程")
                for (_, dto) in dtos.enumerated() {
                    log("  ┌─ \(dto.name)")
                    log("  │  编号: \(dto.code ?? "—")")
                    log("  │  教师: \(dto.teacherName ?? "—")")
                    log("  │  时段: \(dto.schedules.count) 个")
                    log("  └─")
                }
                return
            }
        }

        log("⚠️ 所有 JSON 解析策略均失败")
    }

    // MARK: - 学期信息提取（currentWeek / weekIndices）

    /// 从课表 API 顶层 JSON 提取 currentWeek 和 weekIndices。
    ///
    /// 教务系统返回的 `currentWeek` 是"当前教学周"（绝对周，从 1 开始），
    /// 据此倒推第 1 周的周一，就能保证 App 显示的周次与教务系统完全一致，
    /// 无需依赖任何日期字符串的正则猜测。
    private func extractSemesterInfo(from data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // currentWeek → 反推学期开始日期（第 1 周周一）
        let currentWeekValue = json["currentWeek"]
        let currentWeek = (currentWeekValue as? Int)
            ?? (currentWeekValue as? String).flatMap { Int($0) }
        if let cw = currentWeek, cw > 0 {
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .day, value: -(cw - 1) * 7, to: Date().startOfWeek)
            discoveredSemesterStartDate = start
            log("📅 从 API currentWeek=\(cw) 反推学期开始日期: \(start ?? Date())")
        } else {
            log("⚠️ API 响应未包含 currentWeek，学期日期将回退到 HTML/推算")
        }
    }

    // MARK: - JSON 解析策略

    private func parseAsLessonsArray(_ data: Data) -> [CourseImportDTO]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lessons = json["lessons"] as? [[String: Any]], !lessons.isEmpty else { return nil }
        log("  发现 lessons 数组: \(lessons.count) 条")
        return lessons.compactMap { mapLessonToDTO($0) }
    }

    private func parseAsDataLessonsField(_ data: Data) -> [CourseImportDTO]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataField = json["data"] as? [String: Any],
              let lessons = dataField["lessons"] as? [[String: Any]], !lessons.isEmpty else { return nil }
        return lessons.compactMap { mapLessonToDTO($0) }
    }

    /// lesson → CourseImportDTO
    private func mapLessonToDTO(_ lesson: [String: Any]) -> CourseImportDTO? {
        let course = lesson["course"] as? [String: Any]
        guard let name = extractFirst(course ?? lesson, keys: ["nameZh", "name", "courseName", "kcmc", "title"]),
              !name.isEmpty else {
            log("  ⚠️ 丢弃无课程名的 lesson")
            return nil
        }

        let code = extractFirst(course ?? [:], keys: ["code", "courseCode", "kch"])
        let credits = (course?["credits"] as? Double)
            ?? (course?["credits"] as? Int).map { Double($0) }
        let teachers = extractTeachers(from: lesson)
        let courseTypeDict = lesson["courseType"] as? [String: Any]
        let rawType = extractFirst(courseTypeDict ?? [:], keys: ["nameZh", "name"])
        let campusDict = lesson["campus"] as? [String: Any]
        let campusName = extractFirst(campusDict ?? [:], keys: ["nameZh", "name"])

        let scheduleText = lesson["scheduleText"] as? [String: Any]
        let dateTimePlacePersonText = scheduleText?["dateTimePlacePersonText"] as? [String: Any]
        let rawScheduleText = extractFirst(dateTimePlacePersonText ?? [:], keys: ["text", "textZh"])
            ?? extractFirst(scheduleText?["dateTimePlaceText"] as? [String: Any] ?? [:], keys: ["text", "textZh"])

        let schedules: [ScheduleInput]
        if let text = rawScheduleText, !text.isEmpty {
            schedules = parseScheduleText(text, defaultLocation: campusName)
        } else {
            schedules = parseScheduleFromFields(lesson)
        }

        guard !schedules.isEmpty else {
            log("  ⚠️ 丢弃课程「\(name)」：scheduleText 未能解析出任何时段")
            return nil
        }

        let allLocations = schedules.compactMap { $0.location }
        let primaryLocation = Set(allLocations).joined(separator: "; ")

        return CourseImportDTO(
            name: name,
            code: code,
            teacherName: teachers.isEmpty ? nil : teachers.joined(separator: ", "),
            location: primaryLocation.isEmpty ? campusName : primaryLocation,
            courseType: mapCourseType(rawType),
            credits: credits,
            schedules: schedules,
            note: nil
        )
    }

    // MARK: - 教师提取

    private func extractTeachers(from lesson: [String: Any]) -> [String] {
        guard let teacherList = lesson["teacherAssignmentList"] as? [[String: Any]] else {
            if let teacher = extractFirst(lesson, keys: ["xm", "teacher", "teacherName"]) { return [teacher] }
            return []
        }
        var teachers: [String] = []
        for assignment in teacherList {
            if let person = assignment["person"] as? [String: Any],
               let zhName = person["nameZh"] as? String, !teachers.contains(zhName) {
                teachers.append(zhName)
            }
        }
        return teachers
    }

    // MARK: - scheduleText 文本解析

    private func parseScheduleText(_ text: String, defaultLocation: String?) -> [ScheduleInput] {
        log("  📝 scheduleText 原文: \(text)")
        let entries = text.components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 通用结构：<周次>周[(单|双)] 周X 第A节~第B节 <地点> <教师>
        // 周次段允许：1~4 / 6~16(双) / 6~16周(双) / 1~2,4~12(多段) / 2(单周)
        // 组: 1=周次段 2=单双标记(可选) 3=星期 4=起始节 5=结束节 6=其余
        let pattern = #"^(.*?)周\s*(?:[\(（]\s*([单双])\s*[\)）])?\s*周([一二三四五六日天])\s*第([^~\-～节]+)节\s*[~\-～]\s*第([^节]+)节\s*(.*)$"#

        var schedules: [ScheduleInput] = []

        for entry in entries {
            // 去掉 "#1"/"#2" 实验分组前缀（如 "#1 6~16(双)周 周三 ..."）
            var e = entry
            if let m = e.range(of: #"^#\d+\s*"#, options: .regularExpression) {
                e = String(e[m.upperBound...])
            }

            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: e, range: NSRange(e.startIndex..., in: e)),
                  let weeksR = Range(match.range(at: 1), in: e),
                  let dayR = Range(match.range(at: 3), in: e),
                  let psR = Range(match.range(at: 4), in: e),
                  let peR = Range(match.range(at: 5), in: e),
                  let restR = Range(match.range(at: 6), in: e) else {
                log("  ⚠️ 无法解析条目: \"\(entry)\"")
                continue
            }

            // 单双标记可能在「周」后（如 1~16周(单)），拼回周次段一并解析
            let marker: String = {
                let r = match.range(at: 2)
                guard r.location != NSNotFound, let mr = Range(r, in: e) else { return "" }
                return String(e[mr])
            }()
            let weekRaw = String(e[weeksR]) + marker

            let dayOfWeek = parseDayOfWeek(String(e[dayR]))
            let startPeriod = parseChineseNumber(String(e[psR]))
            let endPeriod = parseChineseNumber(String(e[peR]))
            let (weekRanges, weekType) = parseWeekRanges(weekRaw)
            let (location, _) = splitLocationAndTeacher(
                String(e[restR]).trimmingCharacters(in: .whitespaces))

            // 多段周次（如 1~2,4~12）拆成多条日程，保留中间的"空档周"
            for range in weekRanges {
                schedules.append(ScheduleInput(
                    dayOfWeek: dayOfWeek, startPeriod: startPeriod, endPeriod: endPeriod,
                    weekType: weekType, startWeek: range.start, endWeek: range.end,
                    location: location.isEmpty ? defaultLocation : location))
            }
        }

        return schedules.sorted { a, b in
            a.dayOfWeek != b.dayOfWeek ? a.dayOfWeek < b.dayOfWeek :
            a.startPeriod != b.startPeriod ? a.startPeriod < b.startPeriod :
            a.startWeek < b.startWeek
        }
    }

    /// 解析周次段，支持 "1~4"、"6~16(双)"、"1~2,4~12"（多段）、"2"（单周）
    private func parseWeekRanges(_ raw: String) -> (ranges: [(start: Int, end: Int)], type: WeekType) {
        // 先判断单双周类型（基于原始文本中的「单/双」标记）
        let weekType: WeekType = raw.contains("单") ? .odd : raw.contains("双") ? .even : .all

        // 归一化：去除无关字符，只保留数字与「, ~ -」
        var cleaned = raw
            .replacingOccurrences(of: "第", with: "")
            .replacingOccurrences(of: "周", with: "")
            .replacingOccurrences(of: "单", with: "")
            .replacingOccurrences(of: "双", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "（", with: "")
            .replacingOccurrences(of: "）", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "～", with: "~")

        var ranges: [(start: Int, end: Int)] = []
        for part in cleaned.components(separatedBy: ",") {
            let p = part.trimmingCharacters(in: .whitespaces)
            guard !p.isEmpty else { continue }
            if p.contains("~") || p.contains("-") {
                let seg = p.components(separatedBy: CharacterSet(charactersIn: "~-"))
                if seg.count == 2, let s = Int(seg[0]), let e = Int(seg[1]) { ranges.append((s, e)) }
            } else if let n = Int(p) {
                ranges.append((n, n))
            }
        }
        if ranges.isEmpty { ranges = [(1, 18)] }
        return (ranges, weekType)
    }

    private func splitLocationAndTeacher(_ text: String) -> (location: String, teacher: String?) {
        if let regex = try? NSRegularExpression(pattern: #"^(.+?)\s+([一-鿿]{2,4})$"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let locR = Range(match.range(at: 1), in: text),
           let tR = Range(match.range(at: 2), in: text) {
            return (String(text[locR]), String(text[tR]))
        }
        return (text, nil)
    }

    // MARK: - 旧版兼容解析

    private func parseAsArray(_ data: Data) -> [CourseImportDTO]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return json.compactMap { mapSingleCourse($0) }
    }

    private func parseAsDataField(_ data: Data) -> [CourseImportDTO]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["data"] as? [[String: Any]] else { return nil }
        return list.compactMap { mapSingleCourse($0) }
    }

    private func parseAsCoursesField(_ data: Data) -> [CourseImportDTO]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["courses"] as? [[String: Any]] else { return nil }
        return list.compactMap { mapSingleCourse($0) }
    }

    private func mapSingleCourse(_ dict: [String: Any]) -> CourseImportDTO? {
        guard let name = extractFirst(dict, keys: ["kcmc", "title", "courseName", "name"]) else { return nil }
        let (startWeek, endWeek, weekType) = parseWeeks(extractFirst(dict, keys: ["zcd", "weeks"]))
        let (startPeriod, endPeriod) = parseSections(extractFirst(dict, keys: ["jcd", "jc"]))
        return CourseImportDTO(
            name: name,
            code: extractFirst(dict, keys: ["kch", "course_id", "code"]),
            teacherName: extractFirst(dict, keys: ["xm", "teacher", "teacherName"]),
            location: extractFirst(dict, keys: ["cdmc", "place", "location"]),
            courseType: mapCourseType(extractFirst(dict, keys: ["kclb", "category", "courseType"])),
            credits: extractDouble(dict, keys: ["xf", "credit", "credits"]),
            schedules: [ScheduleInput(
                dayOfWeek: extractInt(dict, keys: ["xqj", "weekday", "day"]) ?? 1,
                startPeriod: startPeriod, endPeriod: endPeriod,
                weekType: weekType, startWeek: startWeek, endWeek: endWeek
            )]
        )
    }

    private func parseScheduleFromFields(_ lesson: [String: Any]) -> [ScheduleInput] {
        let (startWeek, endWeek, weekType) = parseWeeks(extractFirst(lesson, keys: ["zcd", "weeks"]))
        let (startPeriod, endPeriod) = parseSections(extractFirst(lesson, keys: ["jcd", "jc"]))
        let campusDict = lesson["campus"] as? [String: Any]
        return [ScheduleInput(
            dayOfWeek: extractInt(lesson, keys: ["xqj", "weekday", "day"]) ?? 1,
            startPeriod: startPeriod, endPeriod: endPeriod,
            weekType: weekType, startWeek: startWeek, endWeek: endWeek,
            location: extractFirst(lesson, keys: ["cdmc", "place", "location"])
                ?? extractFirst(campusDict ?? [:], keys: ["nameZh", "name"])
        )]
    }

    // MARK: - 工具方法

    private func extractFirst(_ dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty { return value }
            if let value = dict[key] as? Int { return String(value) }
        }
        return nil
    }

    private func extractDouble(_ dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dict[key] as? Double { return value }
            if let value = dict[key] as? Int { return Double(value) }
            if let value = dict[key] as? String, let d = Double(value) { return d }
        }
        return nil
    }

    private func extractInt(_ dict: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dict[key] as? Int { return value }
            if let value = dict[key] as? String, let i = Int(value) { return i }
        }
        return nil
    }

    private func parseWeeks(_ raw: String?) -> (start: Int, end: Int, type: WeekType) {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return (1, 18, .all) }
        let cleaned = raw.replacingOccurrences(of: "周", with: "").replacingOccurrences(of: " ", with: "")
        let weekType: WeekType = cleaned.contains("单") ? .odd : cleaned.contains("双") ? .even : .all
        let nums = cleaned.replacingOccurrences(of: "单", with: "").replacingOccurrences(of: "双", with: "")
            .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        if nums.contains("-") || nums.contains("~") {
            let parts = nums.components(separatedBy: CharacterSet(charactersIn: "-~"))
            if parts.count == 2, let s = Int(parts[0]), let e = Int(parts[1]) { return (s, e, weekType) }
        }
        if nums.contains(",") {
            let ns = nums.split(separator: ",").compactMap { Int($0) }
            if let f = ns.first, let l = ns.last { return (f, l, weekType) }
        }
        if let n = Int(nums) { return (n, n, weekType) }
        return (1, 18, .all)
    }

    private func parseSections(_ raw: String?) -> (start: Int, end: Int) {
        guard let raw = raw?.replacingOccurrences(of: "节", with: "").trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else { return (1, 2) }
        if raw.contains("-") || raw.contains("~") {
            let parts = raw.components(separatedBy: CharacterSet(charactersIn: "-~"))
            if parts.count == 2, let s = Int(parts[0]), let e = Int(parts[1]) { return (s, e) }
        }
        if let n = Int(raw) { return (n, n) }
        return (1, 2)
    }

    private func mapCourseType(_ raw: String?) -> CourseType {
        guard let raw = raw else { return .compulsory }
        if raw.contains("选修") { return .elective }
        if raw.contains("实验") || raw.contains("实践") { return .experiment }
        if raw.contains("体育") { return .pe }
        return .other
    }

    private func parseDayOfWeek(_ char: String) -> Int {
        switch char {
        case "一": return 1; case "二": return 2; case "三": return 3
        case "四": return 4; case "五": return 5; case "六": return 6
        case "日", "天": return 7; default: return 1
        }
    }

    private func parseChineseNumber(_ text: String) -> Int {
        let t = text.trimmingCharacters(in: .whitespaces)
        // 纯数字（"1"、"10"）
        if let n = Int(t) { return n }
        // 含数字的文本（"1、2"、"1-2"）取首个数字，避免多字符崩溃
        if let firstDigit = t.first(where: { $0.isNumber }),
           let n = Int(String(firstDigit)) {
            return n
        }
        let map: [Character: Int] = [
            "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
        ]
        // 单字符中文数字（"一"~"十"）
        if t.count == 1, let n = map[t.first!] { return n }
        // "十X"（十一~十九）
        if t.hasPrefix("十"), t.count == 2, let n = map[t.last!] { return 10 + n }
        // "X十"（二十、三十……）
        if t.hasSuffix("十"), t.count == 2, let n = map[t.first!] { return n * 10 }
        log("⚠️ 无法解析节次文本 \"\(text)\"，按第 1 节处理")
        return 1
    }

    // MARK: - Logging

    func log(_ message: String) {
        print("[DUTImport] \(message)")
        outputLog += message + "\n"
    }

    func clearLog() {
        outputLog = ""
        parsedCourses = []
        rawJSON = ""
        isFetching = false
    }
}
