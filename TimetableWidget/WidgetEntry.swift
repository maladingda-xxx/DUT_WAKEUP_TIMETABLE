//
//  WidgetEntry.swift
//  TimetableWidgetExtension
//

import WidgetKit

/// Timeline Entry — Widget 在某个时间点展示的数据快照
struct TodayCoursesEntry: TimelineEntry {
    /// 该 Entry 对应的时间点
    let date: Date

    /// 今日课程列表
    let courses: [WidgetCourse]

    /// 正在上的课（nil 表示当前不在课上）
    let currentCourse: WidgetCourse?

    /// 下一节课（nil 表示今天没课了）
    let nextCourse: WidgetCourse?

    /// 星期描述，如 "周二"
    let weekdayText: String

    /// 日期描述，如 "7月15日"
    let dateText: String

    /// 下次建议刷新的时间
    let nextRefreshDate: Date
}

/// Widget 展示用的课程精简结构（不依赖 SwiftData）
struct WidgetCourse: Identifiable, Hashable {
    let id: String
    let name: String
    let location: String
    let teacherName: String
    let startPeriod: Int
    let endPeriod: Int
    let startTime: String
    let endTime: String
    let colorHex: String
    let isCurrent: Bool

    /// 节次描述，如 "1-2节"
    var periodText: String {
        "\(startPeriod)-\(endPeriod)节"
    }

    /// 时间描述，如 "08:00-09:35"
    var timeText: String {
        "\(startTime)-\(endTime)"
    }
}
