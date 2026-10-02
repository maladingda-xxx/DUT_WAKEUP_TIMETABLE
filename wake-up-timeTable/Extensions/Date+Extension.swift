//
//  Date+Extension.swift
//  wake-up-timeTable
//

import Foundation

extension Date {

    /// 获取 Date 所在周的周一日期
    var startOfWeek: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        // 周日=1, 周一=2 ... 周六=7
        let daysFromMonday: Int
        if weekday == 1 {
            daysFromMonday = 6
        } else {
            daysFromMonday = weekday - 2
        }
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: self)) ?? self
    }

    /// 将 Apple 的 weekday (1=周日) 转换为我们的 WeekDay (1=周一)
    var weekdayIndex: Int {
        let appleWeekday = Calendar.current.component(.weekday, from: self)
        return appleWeekday == 1 ? 7 : appleWeekday - 1
    }

    /// 计算与目标日期的周数差（从 1 开始）
    /// 若当前日期在 startDate 之前，返回 0（表示学期尚未开始）
    func weeksSince(_ startDate: Date) -> Int {
        let calendar = Calendar.current
        let startMonday = startDate.startOfWeek
        let currentMonday = self.startOfWeek
        let days = calendar.dateComponents([.day], from: startMonday, to: currentMonday).day ?? 0
        let weeks = days / 7 + 1
        return max(0, weeks)
    }
}
