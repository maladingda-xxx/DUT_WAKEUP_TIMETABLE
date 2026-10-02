//
//  CourseService.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData
import WidgetKit

/// 课程业务逻辑层 — 负责数据校验、默认值、导入协调
/// 通过 CourseRepository 访问数据，不直接操作 ModelContext
@Observable
final class CourseService: CourseServiceProtocol {

    // MARK: - Properties

    private let repository: CourseRepository

    var supportsAutoImport: Bool { false }

    // MARK: - Init

    init(repository: CourseRepository) {
        self.repository = repository
    }

    /// 便捷初始化：通过 ModelContext 创建
    convenience init(modelContext: ModelContext) {
        self.init(repository: CourseRepository(context: modelContext))
    }

    // MARK: - 查询

    func fetchCourses(for semester: Semester) -> [Course] {
        repository.fetchAllCourses(semesterID: semester.id)
    }

    func fetchCourses(for semester: Semester, weekNumber: Int) -> [Course] {
        repository.fetchCourses(weekNumber: weekNumber, semesterID: semester.id)
    }

    func fetchCourses(for semester: Semester, dayOfWeek: Int, weekNumber: Int) -> [Course] {
        repository.fetchCourses(
            dayOfWeek: dayOfWeek,
            weekNumber: weekNumber,
            semesterID: semester.id
        )
    }

    func fetchSchedules(for semester: Semester, weekNumber: Int) -> [CourseSchedule] {
        let courses = repository.fetchCourses(weekNumber: weekNumber, semesterID: semester.id)
        return courses.flatMap { course in
            course.activeSchedules(for: weekNumber)
        }
    }

    // MARK: - 写入

    @discardableResult
    func createCourse(
        name: String,
        code: String? = nil,
        teacherName: String? = nil,
        location: String? = nil,
        colorHex: String? = nil,
        courseType: CourseType = .compulsory,
        credits: Double? = nil,
        note: String? = nil,
        schedules: [ScheduleInput] = [],
        semester: Semester
    ) -> Course {
        let course = Course(
            name: name.trimmingCharacters(in: .whitespaces),
            code: code?.trimmingCharacters(in: .whitespaces),
            teacherName: teacherName?.trimmingCharacters(in: .whitespaces),
            location: location?.trimmingCharacters(in: .whitespaces),
            colorHex: colorHex ?? courseType.defaultColorHex,
            courseType: courseType,
            credits: credits,
            note: note?.trimmingCharacters(in: .whitespaces)
        )
        course.semester = semester

        // 创建关联的时间安排
        for input in schedules {
            let schedule = CourseSchedule(
                dayOfWeek: input.dayOfWeek,
                startPeriod: input.startPeriod,
                endPeriod: input.endPeriod,
                weekType: input.weekType,
                startWeek: input.startWeek,
                endWeek: input.endWeek,
                location: input.location
            )
            schedule.course = course
            if course.schedules == nil { course.schedules = [] }
            course.schedules?.append(schedule)
        }

        repository.insert(course)
        reloadWidgets()
        refreshNotifications(for: semester)
        return course
    }

    func updateCourse(_ course: Course) {
        repository.update(course)
        reloadWidgets()
        if let semester = course.semester {
            refreshNotifications(for: semester)
        }
    }

    func deleteCourse(_ course: Course) {
        // 先移除该课程的通知
        NotificationManager.shared.removeReminders(for: course.id)

        let semester = course.semester
        repository.delete(course)
        reloadWidgets()

        // 刷新剩余课程的通知
        if let semester = semester {
            refreshNotifications(for: semester)
        }
    }

    // MARK: - 冲突检测

    func checkConflict(
        dayOfWeek: Int,
        startPeriod: Int,
        endPeriod: Int,
        weekNumber: Int,
        semester: Semester,
        excludeCourseID: UUID? = nil
    ) -> [Course] {
        repository.fetchConflictingCourses(
            dayOfWeek: dayOfWeek,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            weekNumber: weekNumber,
            semesterID: semester.id,
            excludeCourseID: excludeCourseID
        )
    }

    // MARK: - 教务导入（占位）

    func importCourses(_ dtos: [CourseImportDTO], to semester: Semester) throws -> [Course] {
        var imported: [Course] = []

        for dto in dtos {
            // 检查是否已有同编号课程（避免重复导入）
            if let code = dto.code,
               let existing = repository.fetchCourse(byCode: code, semesterID: semester.id) {
                // 已存在则更新
                existing.name = dto.name
                existing.teacherName = dto.teacherName
                existing.location = dto.location
                existing.credits = dto.credits
                existing.note = dto.note
                // 清除旧安排，替换为新安排
                if let oldSchedules = existing.schedules {
                    for s in oldSchedules {
                        repository.removeSchedule(s)
                    }
                }
                existing.schedules = []
                for input in dto.schedules {
                    let schedule = CourseSchedule(
                        dayOfWeek: input.dayOfWeek,
                        startPeriod: input.startPeriod,
                        endPeriod: input.endPeriod,
                        weekType: input.weekType,
                        startWeek: input.startWeek,
                        endWeek: input.endWeek,
                        location: input.location
                    )
                    schedule.course = existing
                    existing.schedules?.append(schedule)
                }
                repository.update(existing)
                imported.append(existing)
            } else {
                // 新课程
                let course = createCourse(
                    name: dto.name,
                    code: dto.code,
                    teacherName: dto.teacherName,
                    location: dto.location,
                    courseType: dto.courseType,
                    credits: dto.credits,
                    note: dto.note,
                    schedules: dto.schedules,
                    semester: semester
                )
                imported.append(course)
            }
        }

        reloadWidgets()
        return imported
    }

    // MARK: - Widget Refresh

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Notifications

    private func refreshNotifications(for semester: Semester) {
        let courses = fetchCourses(for: semester)
        let settings = ReminderSettings()
        guard settings.isEnabled else {
            NotificationManager.shared.removeAllReminders()
            return
        }
        Task {
            NotificationManager.shared.removeExpiredAndRefresh(
                courses: courses,
                semester: semester,
                settings: settings
            )
        }
    }
}
