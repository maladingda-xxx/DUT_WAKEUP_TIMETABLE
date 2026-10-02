//
//  CurrentCourseService.swift
//  wake-up-timeTable
//

import Foundation

/// 当前课程分析服务 — 判断当前上课状态、下一节课、倒计时
@Observable
final class CurrentCourseService {

    // MARK: - Analysis Results

    private(set) var currentCourse: Course?
    private(set) var currentSchedule: CourseSchedule?
    private(set) var nextCourse: Course?
    private(set) var nextSchedule: CourseSchedule?
    private(set) var timeUntilNextText: String = ""
    private(set) var timeRemainingText: String = ""
    private(set) var isInCourse: Bool = false
    private(set) var allEntries: [ScheduleEntry] = []

    // MARK: - Types

    struct ScheduleEntry {
        let course: Course
        let schedule: CourseSchedule
        let startTime: Date
        let endTime: Date
    }

    // MARK: - Analyze

    /// 分析今日课程时间状态
    /// - Parameters:
    ///   - courses: 今日有课的课程列表
    ///   - weekNumber: 当前教学周
    ///   - dayOfWeek: 今天星期几 (1=周一)
    func analyze(
        courses: [Course],
        weekNumber: Int,
        dayOfWeek: Int
    ) {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)

        // 构建所有时间条目，按开始时间排序
        var entries: [ScheduleEntry] = []
        for course in courses {
            for schedule in course.activeSchedules(for: weekNumber) where schedule.dayOfWeek == dayOfWeek {
                guard let startTime = periodToDate(period: schedule.startPeriod, isStart: true, baseDate: today),
                      let endTime = periodToDate(period: schedule.endPeriod, isStart: false, baseDate: today) else {
                    continue
                }
                entries.append(ScheduleEntry(
                    course: course,
                    schedule: schedule,
                    startTime: startTime,
                    endTime: endTime
                ))
            }
        }
        entries.sort { $0.startTime < $1.startTime }
        allEntries = entries

        // 查找当前课程：now 在 [startTime, endTime) 区间内
        let currentEntry = entries.first { now >= $0.startTime && now < $0.endTime }
        if let entry = currentEntry {
            currentCourse = entry.course
            currentSchedule = entry.schedule
            isInCourse = true
            let remaining = Int(entry.endTime.timeIntervalSince(now))
            timeRemainingText = formatCountdown(seconds: remaining)
        } else {
            currentCourse = nil
            currentSchedule = nil
            isInCourse = false
            timeRemainingText = ""
        }

        // 查找下一节课：开始时间 > now 且最接近
        let upcomingEntry = entries.first { $0.startTime > now }
        if let entry = upcomingEntry {
            nextCourse = entry.course
            nextSchedule = entry.schedule
            let until = Int(entry.startTime.timeIntervalSince(now))
            timeUntilNextText = formatCountdown(seconds: until)
        } else {
            nextCourse = nil
            nextSchedule = nil
            timeUntilNextText = ""
        }
    }

    // MARK: - Helpers

    /// 将节次号转换为具体 Date
    private func periodToDate(period: Int, isStart: Bool, baseDate: Date) -> Date? {
        guard let config = Constants.periodTimes.first(where: { $0.period == period }) else {
            return nil
        }
        let timeString = isStart ? config.start : config.end
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }

        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: baseDate
        )
    }

    /// 格式化倒计时文本
    /// - Parameter seconds: 剩余秒数
    /// - Returns: "1小时25分钟" / "25分钟" / "即将开始"
    private func formatCountdown(seconds: Int) -> String {
        guard seconds > 0 else { return "即将开始" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "不到1分钟"
        }
    }
}
