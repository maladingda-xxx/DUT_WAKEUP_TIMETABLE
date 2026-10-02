//
//  Exam.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData

@Model
final class Exam {
    var id: UUID
    var name: String
    /// 考试日期
    var date: Date
    /// 考试开始时间
    var startTime: Date
    /// 考试结束时间
    var endTime: Date
    /// 考场
    var location: String?
    /// 座位号
    var seatNumber: String?
    /// 备注（如"闭卷"）
    var note: String?

    /// 关联课程
    var course: Course?

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        location: String? = nil,
        seatNumber: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.seatNumber = seatNumber
        self.note = note
    }
}
