//
//  Constants.swift
//  wake-up-timeTable
//

import Foundation

/// 应用全局常量
enum Constants {

    // MARK: - App Group

    /// App Group 标识符（主 App 与 Widget 共享数据）
    static let appGroupIdentifier = "group.com.dingjiayuan.wake-up-timeTable"

    /// App Group 共享目录 URL
    static var appGroupContainerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )!
    }

    /// SwiftData 共享数据库 URL
    static var sharedDatabaseURL: URL {
        appGroupContainerURL.appending(path: "Timetable.sqlite")
    }

    // MARK: - Period Configuration

    /// 大工常见节次时间安排
    /// 每项格式: (节次序号, 开始时间 "HH:mm", 结束时间 "HH:mm")
    static let periodTimes: [(period: Int, start: String, end: String)] = [
        (1,  "08:00", "08:45"),
        (2,  "08:50", "09:35"),
        (3,  "09:50", "10:35"),
        (4,  "10:40", "11:25"),
        (5,  "13:30", "14:15"),
        (6,  "14:20", "15:05"),
        (7,  "15:10", "15:55"),
        (8,  "16:00", "16:45"),
        (9,  "18:00", "18:45"),
        (10, "18:50", "19:35"),
        (11, "19:40", "20:25"),
        (12, "20:30", "21:15"),
    ]

    /// 每天的节次数
    static let totalPeriodsPerDay = 12

    /// 每周上课天数（周一至周日）
    static let schoolDaysPerWeek = 7

    /// 最大教学周数
    static let maxWeeksPerSemester = 20

    // MARK: - Course Color Palette

    /// 课程卡片可选颜色（十六进制）。前五项与课程类型默认色一致，方便「重置」为类型默认色。
    static let courseColorPalette: [String] = [
        "#4A90D9", "#7EC856", "#F5A623", "#E8635A", "#9B8EC4", // 课程类型默认色
        "#E91E63", "#F06292", "#E040A0", "#9C27B0", "#3F51B5",
        "#2196F3", "#00BCD4", "#26A69A", "#4CAF50", "#8BC34A",
        "#F7B733", "#E8C547", "#795548", "#607D8B", "#9E9E9E",
    ]

    // MARK: - UserDefaults Keys

    /// 是否已清理历史 Mock 示例数据
    static let didPurgeMockDataKey = "didPurgeMockData"

    // MARK: - App Info

    static let appName = "Wake Up 课程表"
    static let appVersion = "1.0.0"
}
