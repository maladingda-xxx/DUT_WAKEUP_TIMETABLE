//
//  Semester.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData

@Model
final class Semester {
    var id: UUID
    var name: String
    /// 学期第一天（必须是周一）
    var startDate: Date
    /// 总教学周数（含考试周），默认 18
    var totalWeeks: Int
    /// 起始周序号，默认 1
    var startWeekNumber: Int
    /// 是否为当前学期
    var isCurrent: Bool
    var createdAt: Date

    /// 关联课程
    @Relationship(deleteRule: .cascade, inverse: \Course.semester)
    var courses: [Course]?

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        totalWeeks: Int = 18,
        startWeekNumber: Int = 1,
        isCurrent: Bool = false
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.startWeekNumber = startWeekNumber
        self.isCurrent = isCurrent
        self.createdAt = Date()
        self.courses = []
    }
}
