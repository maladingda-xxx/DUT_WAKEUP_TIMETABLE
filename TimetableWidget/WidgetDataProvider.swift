//
//  WidgetDataProvider.swift
//  TimetableWidgetExtension
//

import Foundation
import SwiftData

/// 从 AppGroup 共享数据库中读取课程数据
enum WidgetDataProvider {

    // MARK: - Public

    /// 获取今日课程数据 + 时间分析
    static func fetchTodayData() -> (courses: [WidgetCourse], current: WidgetCourse?, next: WidgetCourse?) {
        guard let container = try? sharedContainer() else {
            return ([], nil, nil)
        }

        let context = container.mainContext

        // 获取当前学期
        guard let semester = fetchCurrentSemester(context: context) else {
            return ([], nil, nil)
        }

        let now = Date()
        let weekNumber = now.weeksSince(semester.startDate)
        let dayOfWeek = now.weekdayIndex

        // 获取今日课程
        let todaySchedules = fetchTodaySchedules(
            context: context,
            semesterID: semester.id,
            weekNumber: weekNumber,
            dayOfWeek: dayOfWeek
        )

        // 构建 WidgetCourse 列表
        let widgetCourses = todaySchedules.compactMap { info -> WidgetCourse? in
            buildWidgetCourse(from: info, now: now)
        }
        .sorted { $0.startPeriod < $1.startPeriod }

        // 查找当前课程和下一节课
        let current = widgetCourses.first { $0.isCurrent }
        let next = widgetCourses.first { !$0.isCurrent && isUpcoming($0, now: now) }

        return (widgetCourses, current, next)
    }

    /// 获取下一个需要刷新 Widget 的时间点
    static func nextRefreshTime(
        courses: [WidgetCourse],
        current: WidgetCourse?,
        next: WidgetCourse?
    ) -> Date {
        let now = Date()

        // 如果正在上课，在课程结束时刷新
        if let current = current {
            if let endDate = timeToDate(timeString: current.endTime) {
                return endDate.addingTimeInterval(60) // 延迟1分钟容错
            }
        }

        // 如果有下一节课，在开始时刷新
        if let next = next {
            if let startDate = timeToDate(timeString: next.startTime) {
                return startDate
            }
        }

        // 默认：明天午夜刷新
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.startOfDay(for: tomorrow)
    }

    // MARK: - Private

    private static func sharedContainer() throws -> ModelContainer {
        let config = ModelConfiguration(url: Constants.sharedDatabaseURL)
        return try ModelContainer(
            for: Course.self, CourseSchedule.self, Semester.self,
            configurations: config
        )
    }

    private static func fetchCurrentSemester(context: ModelContext) -> Semester? {
        var descriptor = FetchDescriptor<Semester>(
            predicate: #Predicate { $0.isCurrent == true }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func fetchTodaySchedules(
        context: ModelContext,
        semesterID: UUID,
        weekNumber: Int,
        dayOfWeek: Int
    ) -> [(course: Course, schedule: CourseSchedule)] {
        let sid = semesterID
        var descriptor = FetchDescriptor<Course>(
            predicate: #Predicate<Course> { course in
                course.semester?.id == sid
            }
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.schedules]
        let allCourses = (try? context.fetch(descriptor)) ?? []

        var results: [(Course, CourseSchedule)] = []
        for course in allCourses {
            for schedule in course.activeSchedules(for: weekNumber)
                where schedule.dayOfWeek == dayOfWeek {
                results.append((course, schedule))
            }
        }
        return results
    }

    private static func buildWidgetCourse(
        from info: (course: Course, schedule: CourseSchedule),
        now: Date
    ) -> WidgetCourse? {
        let (course, schedule) = info

        guard let startConfig = periodConfig(for: schedule.startPeriod),
              let endConfig = periodConfig(for: schedule.endPeriod) else {
            return nil
        }

        let isCurrent = isCurrentlyActive(
            startTime: startConfig.start,
            endTime: endConfig.end,
            now: now
        )

        return WidgetCourse(
            id: schedule.id.uuidString,
            name: course.name,
            location: course.displayLocation(for: schedule),
            teacherName: course.teacherName ?? "",
            startPeriod: schedule.startPeriod,
            endPeriod: schedule.endPeriod,
            startTime: startConfig.start,
            endTime: endConfig.end,
            colorHex: course.colorHex,
            isCurrent: isCurrent
        )
    }

    private static func periodConfig(for period: Int) -> (start: String, end: String)? {
        guard let config = Constants.periodTimes.first(where: { $0.period == period }) else {
            return nil
        }
        return (config.start, config.end)
    }

    private static func isCurrentlyActive(startTime: String, endTime: String, now: Date) -> Bool {
        guard let start = timeToDate(timeString: startTime),
              let end = timeToDate(timeString: endTime) else {
            return false
        }
        return now >= start && now < end
    }

    private static func isUpcoming(_ course: WidgetCourse, now: Date) -> Bool {
        guard let start = timeToDate(timeString: course.startTime) else {
            return false
        }
        return start > now
    }

    private static func timeToDate(timeString: String) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        )
    }
}
