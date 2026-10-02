//
//  CourseSchedule.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData

@Model
final class CourseSchedule {
    var id: UUID
    /// 星期几 (1=周一 ... 7=周日)
    var dayOfWeek: Int
    /// 起始节次 (1-12)
    var startPeriod: Int
    /// 结束节次 (1-12)，必须 >= startPeriod
    var endPeriod: Int
    /// 单双周类型
    var weekTypeRaw: String
    /// 起始教学周
    var startWeek: Int
    /// 结束教学周
    var endWeek: Int
    /// 可覆盖 Course 级别的上课地点（如实验课在另一栋楼）
    var location: String?

    /// 反向关联课程
    var course: Course?

    // MARK: - Computed Properties

    /// 持续节数
    var duration: Int {
        endPeriod - startPeriod + 1
    }

    /// 周类型枚举
    var weekType: WeekType {
        get { WeekType(rawValue: weekTypeRaw) ?? .all }
        set { weekTypeRaw = newValue.rawValue }
    }

    /// 是否在指定周次上课（含单双周判断）
    func isActive(in weekNumber: Int) -> Bool {
        guard weekNumber >= startWeek && weekNumber <= endWeek else {
            return false
        }
        switch weekType {
        case .all:
            return true
        case .odd:
            return weekNumber % 2 == 1
        case .even:
            return weekNumber % 2 == 0
        }
    }

    /// 节次范围描述，如 "1-2节"
    var periodDescription: String {
        "\(startPeriod)-\(endPeriod)节"
    }

    /// 星期描述
    var dayOfWeekName: String {
        WeekDay(rawValue: dayOfWeek)?.shortName ?? "周?"
    }

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        startPeriod: Int,
        endPeriod: Int,
        weekType: WeekType = .all,
        startWeek: Int = 1,
        endWeek: Int = 18,
        location: String? = nil
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.startPeriod = startPeriod
        self.endPeriod = endPeriod
        self.weekTypeRaw = weekType.rawValue
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.location = location
    }
}
