//
//  Enums.swift
//  wake-up-timeTable
//

import Foundation

/// 星期几
enum WeekDay: Int, Codable, CaseIterable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var shortName: String {
        switch self {
        case .monday:    return "周一"
        case .tuesday:   return "周二"
        case .wednesday: return "周三"
        case .thursday:  return "周四"
        case .friday:    return "周五"
        case .saturday:  return "周六"
        case .sunday:    return "周日"
        }
    }
}

/// 单双周类型
enum WeekType: String, Codable, CaseIterable {
    case all  = "每周"
    case odd  = "单周"
    case even = "双周"
}

/// 课程类型
enum CourseType: String, Codable, CaseIterable {
    case compulsory = "必修"
    case elective   = "选修"
    case experiment = "实验"
    case pe         = "体育"
    case other      = "其他"

    /// 默认颜色（用于自动分配课程卡片背景色）
    var defaultColorHex: String {
        switch self {
        case .compulsory: return "#4A90D9"
        case .elective:   return "#7EC856"
        case .experiment: return "#F5A623"
        case .pe:         return "#E8635A"
        case .other:      return "#9B8EC4"
        }
    }
}

/// 学期类型
enum SemesterType: String, Codable {
    case spring = "春"
    case autumn = "秋"
}
