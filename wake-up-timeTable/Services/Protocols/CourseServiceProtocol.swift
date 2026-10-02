//
//  CourseServiceProtocol.swift
//  wake-up-timeTable
//

import Foundation

/// 课程服务协议 — ViewModel 通过此协议调用，支持 Mock 替换
protocol CourseServiceProtocol {
    // MARK: - 查询

    /// 获取指定学期的全部课程
    func fetchCourses(for semester: Semester) -> [Course]

    /// 获取指定学期、指定周次的课程（含单双周过滤）
    func fetchCourses(for semester: Semester, weekNumber: Int) -> [Course]

    /// 获取指定学期、指定星期几+周次的课程
    func fetchCourses(for semester: Semester, dayOfWeek: Int, weekNumber: Int) -> [Course]

    /// 获取某个时间段的课程安排
    func fetchSchedules(for semester: Semester, weekNumber: Int) -> [CourseSchedule]

    // MARK: - 写入

    /// 创建课程（含时间安排）
    @discardableResult
    func createCourse(
        name: String,
        code: String?,
        teacherName: String?,
        location: String?,
        colorHex: String?,
        courseType: CourseType,
        credits: Double?,
        note: String?,
        schedules: [ScheduleInput],
        semester: Semester
    ) -> Course

    /// 更新课程基本信息
    func updateCourse(_ course: Course)

    /// 删除课程
    func deleteCourse(_ course: Course)

    // MARK: - 冲突检测

    /// 检测指定时间是否有课程冲突
    func checkConflict(
        dayOfWeek: Int,
        startPeriod: Int,
        endPeriod: Int,
        weekNumber: Int,
        semester: Semester,
        excludeCourseID: UUID?
    ) -> [Course]

    // MARK: - 教务导入（预留）

    /// 是否支持自动导入
    var supportsAutoImport: Bool { get }

    /// 导入课程数据（DTO 数组）
    func importCourses(_ dtos: [CourseImportDTO], to semester: Semester) throws -> [Course]
}

// MARK: - Supporting Types

/// 创建课程时的时间安排输入
struct ScheduleInput: Identifiable {
    let id: UUID
    let dayOfWeek: Int
    let startPeriod: Int
    let endPeriod: Int
    let weekType: WeekType
    let startWeek: Int
    let endWeek: Int
    let location: String?

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
        self.weekType = weekType
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.location = location
    }
}

/// 教务系统导入的课程 DTO（数据来源无关：网页解析/API/文件导入）
struct CourseImportDTO {
    let name: String
    let code: String?
    let teacherName: String?
    let location: String?
    let courseType: CourseType
    let credits: Double?
    let schedules: [ScheduleInput]
    let note: String?

    init(
        name: String,
        code: String? = nil,
        teacherName: String? = nil,
        location: String? = nil,
        courseType: CourseType = .compulsory,
        credits: Double? = nil,
        schedules: [ScheduleInput] = [],
        note: String? = nil
    ) {
        self.name = name
        self.code = code
        self.teacherName = teacherName
        self.location = location
        self.courseType = courseType
        self.credits = credits
        self.schedules = schedules
        self.note = note
    }
}

// MARK: - Default Protocol Implementations

extension CourseServiceProtocol {
    var supportsAutoImport: Bool { false }
}
