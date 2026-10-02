//
//  Course.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData

@Model
final class Course {
    var id: UUID
    /// 课程名称
    var name: String
    /// 教务系统课程编号（预留，用于教务导入匹配）
    var code: String?
    /// 教师名称
    var teacherName: String?
    /// 默认上课地点（可被单个 CourseSchedule 覆盖）
    var location: String?
    /// 课程卡片颜色（十六进制，如 "#4A90D9"）
    var colorHex: String
    /// 课程类型原始值
    var courseTypeRaw: String
    /// 学分
    var credits: Double?
    /// 备注
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    /// 时间安排（一门课可有多条，如周一 1-2 节、周三 3-4 节）
    @Relationship(deleteRule: .cascade, inverse: \CourseSchedule.course)
    var schedules: [CourseSchedule]?

    /// 关联考试
    @Relationship(deleteRule: .cascade, inverse: \Exam.course)
    var exams: [Exam]?

    /// 所属学期
    var semester: Semester?

    // MARK: - Computed Properties

    /// 课程类型枚举
    var courseType: CourseType {
        get { CourseType(rawValue: courseTypeRaw) ?? .other }
        set { courseTypeRaw = newValue.rawValue }
    }

    /// 按星期+节次排序的时间安排
    var sortedSchedules: [CourseSchedule] {
        (schedules ?? []).sorted { a, b in
            if a.dayOfWeek != b.dayOfWeek {
                return a.dayOfWeek < b.dayOfWeek
            }
            return a.startPeriod < b.startPeriod
        }
    }

    /// 获取指定周次的有效时间安排（含单双周过滤）
    func activeSchedules(for weekNumber: Int) -> [CourseSchedule] {
        (schedules ?? []).filter { $0.isActive(in: weekNumber) }
    }

    /// 获取指定星期几的时间安排
    func schedules(for dayOfWeek: Int, weekNumber: Int) -> [CourseSchedule] {
        activeSchedules(for: weekNumber).filter { $0.dayOfWeek == dayOfWeek }
    }

    /// 覆盖所有上课的星期几
    var activeWeekdays: Set<Int> {
        Set((schedules ?? []).map { $0.dayOfWeek })
    }

    /// 实际显示的上课地点（优先取 Schedule 级别，否则取 Course 级别）
    func displayLocation(for schedule: CourseSchedule) -> String {
        schedule.location ?? location ?? "未指定"
    }

    init(
        id: UUID = UUID(),
        name: String,
        code: String? = nil,
        teacherName: String? = nil,
        location: String? = nil,
        colorHex: String? = nil,
        courseType: CourseType = .compulsory,
        credits: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.teacherName = teacherName
        self.location = location
        self.colorHex = colorHex ?? courseType.defaultColorHex
        self.courseTypeRaw = courseType.rawValue
        self.credits = credits
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
        self.schedules = []
        self.exams = []
    }

    /// 便捷添加一条时间安排
    func addSchedule(
        dayOfWeek: Int,
        startPeriod: Int,
        endPeriod: Int,
        weekType: WeekType = .all,
        startWeek: Int = 1,
        endWeek: Int = 18,
        location: String? = nil
    ) -> CourseSchedule {
        let schedule = CourseSchedule(
            dayOfWeek: dayOfWeek,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            weekType: weekType,
            startWeek: startWeek,
            endWeek: endWeek,
            location: location
        )
        schedule.course = self
        if schedules == nil { schedules = [] }
        schedules?.append(schedule)
        return schedule
    }
}
