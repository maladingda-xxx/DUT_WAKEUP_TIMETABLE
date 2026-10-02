//
//  NotificationManager.swift
//  wake-up-timeTable
//

import Foundation
import UserNotifications

/// 课程提醒通知管理器
/// 负责授权、创建、删除、刷新课程上课提醒
@Observable
final class NotificationManager {

    // MARK: - Singleton

    static let shared = NotificationManager()

    private init() {}

    // MARK: - State

    private(set) var isAuthorized = false

    /// 通知标识符前缀
    private static let identifierPrefix = "course-reminder"

    /// 提前生成通知的天数范围（当前周 + 未来 N 周）
    private static let advanceWeeks = 2

    // MARK: - Authorization

    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    /// 检查当前授权状态
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule

    /// 为一组课程及其所有时间安排生成上课提醒通知
    /// - Parameters:
    ///   - courses: 当前学期的课程列表
    ///   - semester: 当前学期
    ///   - settings: 提醒偏好
    func scheduleReminders(
        for courses: [Course],
        semester: Semester,
        settings: ReminderSettings
    ) async {
        guard settings.isEnabled else { return }
        guard isAuthorized else { return }

        let offset = settings.reminderOffset
        let currentWeek = Date().weeksSince(semester.startDate)
        let maxWeek = min(currentWeek + Self.advanceWeeks, semester.totalWeeks)

        var requests: [UNNotificationRequest] = []

        for course in courses {
            guard let schedules = course.schedules else { continue }

            for schedule in schedules {
                // 只生成当前周 + 未来 N 周的通知
                let effectiveStartWeek = max(schedule.startWeek, currentWeek)
                let effectiveEndWeek = min(schedule.endWeek, maxWeek)

                for week in effectiveStartWeek...effectiveEndWeek {
                    // 单双周过滤
                    guard schedule.isActive(in: week) else { continue }

                    guard let trigger = makeTrigger(
                        semesterStart: semester.startDate,
                        weekNumber: week,
                        dayOfWeek: schedule.dayOfWeek,
                        startPeriod: schedule.startPeriod,
                        reminderOffset: offset
                    ) else { continue }

                    // 确保触发时间在未来
                    guard trigger.nextTriggerDate() ?? Date.distantPast > Date() else {
                        continue
                    }

                    let identifier = notificationIdentifier(
                        courseID: course.id,
                        scheduleID: schedule.id,
                        weekNumber: week
                    )

                    let content = makeContent(
                        course: course,
                        schedule: schedule,
                        weekNumber: week,
                        minutesBefore: settings.minutesBefore
                    )

                    requests.append(UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: trigger
                    ))
                }
            }
        }

        // 批量提交（限制 iOS 最多 64 条待处理通知）
        let pending = Array(requests.prefix(60))
        for request in pending {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("[NotificationManager] Failed to add: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Remove

    /// 删除指定课程的所有通知
    func removeReminders(for courseID: UUID) {
        let prefix = "\(Self.identifierPrefix)-\(courseID.uuidString)"
        Task {
            let identifiers = await pendingIdentifiers(matching: prefix)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    /// 删除所有课程提醒通知
    func removeAllReminders() {
        Task {
            let identifiers = await pendingIdentifiers(matching: Self.identifierPrefix)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    /// 删除已过期的通知，并刷新剩余通知
    func removeExpiredAndRefresh(
        courses: [Course],
        semester: Semester,
        settings: ReminderSettings = ReminderSettings()
    ) {
        Task {
            await removeExpiredNotifications()
            await scheduleReminders(for: courses, semester: semester, settings: settings)
        }
    }

    // MARK: - Debug

    /// 获取所有待处理的通知数量
    func pendingCount() async -> Int {
        await pendingIdentifiers(matching: Self.identifierPrefix).count
    }

    // MARK: - Private: Trigger

    /// 根据学期起始日、周次、星期、节次计算通知触发时间
    private func makeTrigger(
        semesterStart: Date,
        weekNumber: Int,
        dayOfWeek: Int,
        startPeriod: Int,
        reminderOffset: TimeInterval
    ) -> UNCalendarNotificationTrigger? {
        let calendar = Calendar.current

        // 计算该周周一
        let monday = calendar.date(
            byAdding: .weekOfYear,
            value: weekNumber - 1,
            to: semesterStart.startOfWeek
        ) ?? semesterStart

        // 计算具体日期
        guard let courseDate = calendar.date(
            byAdding: .day,
            value: dayOfWeek - 1,
            to: monday
        ) else { return nil }

        // 获取节次开始时间
        guard let periodConfig = Constants.periodTimes.first(where: { $0.period == startPeriod }),
              hourFromTimeString(periodConfig.start) != nil else {
            return nil
        }

        let startComponents = splitHourMinute(periodConfig.start)

        // 设置课程开始时间
        guard let courseStart = calendar.date(
            bySettingHour: startComponents.hour,
            minute: startComponents.minute,
            second: 0,
            of: courseDate
        ) else { return nil }

        // 减去提醒偏移量
        let triggerDate = courseStart.addingTimeInterval(-reminderOffset)

        // 提取日期组件用于日历触发器
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    // MARK: - Private: Content

    private func makeContent(
        course: Course,
        schedule: CourseSchedule,
        weekNumber: Int,
        minutesBefore: Int
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = course.name
        content.sound = .default

        var bodyParts: [String] = []
        bodyParts.append("将在 \(minutesBefore) 分钟后开始")

        let location = course.displayLocation(for: schedule)
        if !location.isEmpty {
            bodyParts.append("📍 \(location)")
        }
        if let teacher = course.teacherName {
            bodyParts.append("👤 \(teacher)")
        }

        bodyParts.append("第 \(weekNumber) 周 \(schedule.dayOfWeekName) \(schedule.periodDescription)")

        content.body = bodyParts.joined(separator: "\n")
        content.badge = 1

        // 按课程名分组，方便用户管理
        content.threadIdentifier = "course-\(course.id.uuidString)"

        return content
    }

    // MARK: - Private: Identifiers

    private func notificationIdentifier(
        courseID: UUID,
        scheduleID: UUID,
        weekNumber: Int
    ) -> String {
        "\(Self.identifierPrefix)-\(courseID.uuidString)-\(scheduleID.uuidString)-w\(weekNumber)"
    }

    private func pendingIdentifiers(matching prefix: String) async -> [String] {
        let all = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return all.map(\.identifier).filter { $0.hasPrefix(prefix) }
    }

    private func removeExpiredNotifications() async {
        let all = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let expired = all.filter { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let nextDate = trigger.nextTriggerDate() else { return false }
            return nextDate <= Date()
        }
        if !expired.isEmpty {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: expired.map(\.identifier))
        }
    }

    // MARK: - Private: Time Parsing

    private func splitHourMinute(_ time: String) -> (hour: Int, minute: Int) {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return (0, 0)
        }
        return (hour, minute)
    }

    private func hourFromTimeString(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]) else { return nil }
        return hour
    }
}
