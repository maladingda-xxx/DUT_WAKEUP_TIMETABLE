//
//  MockDataGenerator.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData

/// 测试数据生成器 — 提供大连理工大学风格的示例课程数据
/// 仅用于 SwiftUI Preview，生产环境不会写入任何 Mock 数据
enum MockDataGenerator {

    /// 所有 Mock 课程的固定编号，用于识别并清理历史注入的 Mock 数据
    static let mockCourseCodes: Set<String> = [
        "MATH1001", "PHYS1001", "MATH1002", "ENGL1003",
        "PHED1001", "POLI1001", "CSCI1001", "PHYS1002",
    ]

    // MARK: - Semester

    /// 生成 2026-2027 第一学期（秋季学期）
    static func generateSemester(modelContext: ModelContext? = nil) -> Semester {
        // 2026年9月第一个周一：2026年8月31日是周一
        let startDate = dateFrom(year: 2026, month: 8, day: 31)
        let semester = Semester(
            name: "2026-2027 第一学期",
            startDate: startDate,
            totalWeeks: 18,
            startWeekNumber: 1,
            isCurrent: true
        )
        if let context = modelContext {
            context.insert(semester)
            try? context.save()
        }
        return semester
    }

    /// 生成 2026-2027 第二学期（春季学期）
    static func generateSpringSemester(modelContext: ModelContext? = nil) -> Semester {
        let startDate = dateFrom(year: 2027, month: 3, day: 1)
        let semester = Semester(
            name: "2026-2027 第二学期",
            startDate: startDate,
            totalWeeks: 18,
            startWeekNumber: 1,
            isCurrent: false
        )
        if let context = modelContext {
            context.insert(semester)
            try? context.save()
        }
        return semester
    }

    // MARK: - Courses

    /// 生成 8 门示例课程，模拟大工典型课表
    static func generateCourses(for semester: Semester, modelContext: ModelContext? = nil) -> [Course] {
        let courses = buildCourseList(semester: semester)

        if let context = modelContext {
            for course in courses {
                context.insert(course)
            }
            try? context.save()
        }

        return courses
    }

    /// 生成示例数据并返回 (学期, 课程列表)
    @discardableResult
    static func generateAll(modelContext: ModelContext) -> (Semester, [Course]) {
        let semester = generateSemester(modelContext: modelContext)
        let courses = generateCourses(for: semester, modelContext: modelContext)
        return (semester, courses)
    }

    // MARK: - Private Builders

    private static func buildCourseList(semester: Semester) -> [Course] {
        [
            makeCourse(
                name: "高等数学A1",
                code: "MATH1001",
                teacherName: "张明",
                location: "综合教学1号楼 综151",
                courseType: .compulsory,
                credits: 5.0,
                schedules: [
                    (day: 1, start: 1, end: 2, type: .all, startWeek: 1, endWeek: 18),
                    (day: 3, start: 3, end: 4, type: .all, startWeek: 1, endWeek: 18),
                ],
                semester: semester
            ),
            makeCourse(
                name: "大学物理A1",
                code: "PHYS1001",
                teacherName: "李芳",
                location: "综合教学2号楼 综201",
                courseType: .compulsory,
                credits: 4.0,
                schedules: [
                    (day: 2, start: 1, end: 2, type: .all, startWeek: 1, endWeek: 18),
                    (day: 4, start: 1, end: 2, type: .all, startWeek: 1, endWeek: 18),
                ],
                semester: semester
            ),
            makeCourse(
                name: "线性代数",
                code: "MATH1002",
                teacherName: "王强",
                location: "综合教学1号楼 综253",
                courseType: .compulsory,
                credits: 3.0,
                schedules: [
                    (day: 1, start: 5, end: 6, type: .all, startWeek: 1, endWeek: 8),
                    (day: 3, start: 5, end: 6, type: .all, startWeek: 1, endWeek: 8),
                ],
                note: "前8周课程",
                semester: semester
            ),
            makeCourse(
                name: "大学英语III",
                code: "ENGL1003",
                teacherName: "陈静",
                location: "文科楼 文301",
                courseType: .compulsory,
                credits: 2.0,
                schedules: [
                    (day: 3, start: 1, end: 2, type: .all, startWeek: 1, endWeek: 18),
                    (day: 5, start: 3, end: 4, type: .all, startWeek: 1, endWeek: 18),
                ],
                semester: semester
            ),
            makeCourse(
                name: "体育（篮球）",
                code: "PHED1001",
                teacherName: "刘洋",
                location: "体育馆 篮球场",
                courseType: .pe,
                credits: 1.0,
                schedules: [
                    (day: 5, start: 7, end: 8, type: .all, startWeek: 1, endWeek: 18),
                ],
                semester: semester
            ),
            makeCourse(
                name: "马克思主义基本原理",
                code: "POLI1001",
                teacherName: "赵敏",
                location: "综合教学2号楼 综102",
                courseType: .compulsory,
                credits: 3.0,
                schedules: [
                    (day: 2, start: 5, end: 6, type: .odd, startWeek: 1, endWeek: 16),
                ],
                note: "单周上课",
                semester: semester
            ),
            makeCourse(
                name: "C语言程序设计",
                code: "CSCI1001",
                teacherName: "周磊",
                location: "创新创业学院 机房A",
                courseType: .elective,
                credits: 2.5,
                schedules: [
                    (day: 4, start: 5, end: 6, type: .all, startWeek: 1, endWeek: 18),
                    (day: 4, start: 7, end: 8, type: .all, startWeek: 1, endWeek: 18),
                ],
                note: "理论+上机",
                semester: semester
            ),
            makeCourse(
                name: "大学物理实验",
                code: "PHYS1002",
                teacherName: "吴华",
                location: "物理实验中心 302",
                courseType: .experiment,
                credits: 1.5,
                schedules: [
                    (day: 3, start: 7, end: 8, type: .even, startWeek: 4, endWeek: 16),
                ],
                note: "双周上课，第4周开始",
                semester: semester
            ),
        ]
    }

    /// 便捷构造方法：创建带有多条时间安排的课程
    private static func makeCourse(
        name: String,
        code: String?,
        teacherName: String?,
        location: String?,
        courseType: CourseType,
        credits: Double?,
        schedules: [(day: Int, start: Int, end: Int, type: WeekType, startWeek: Int, endWeek: Int)],
        note: String? = nil,
        semester: Semester
    ) -> Course {
        let course = Course(
            name: name,
            code: code,
            teacherName: teacherName,
            location: location,
            courseType: courseType,
            credits: credits,
            note: note
        )
        course.semester = semester

        var scheduleObjects: [CourseSchedule] = []
        for s in schedules {
            let schedule = CourseSchedule(
                dayOfWeek: s.day,
                startPeriod: s.start,
                endPeriod: s.end,
                weekType: s.type,
                startWeek: s.startWeek,
                endWeek: s.endWeek,
                location: nil // 使用 Course 级别的 location
            )
            schedule.course = course
            scheduleObjects.append(schedule)
        }
        course.schedules = scheduleObjects
        return course
    }

    // MARK: - Helpers

    private static func dateFrom(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Preview Helper

#if DEBUG
extension MockDataGenerator {
    /// 创建内存 ModelContainer 用于 SwiftUI Preview
    static func previewContainer() -> ModelContainer {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Course.self, CourseSchedule.self, Semester.self, Exam.self,
                configurations: config
            )
            // 预填充示例数据
            let context = container.mainContext
            generateAll(modelContext: context)
            return container
        } catch {
            fatalError("Preview container creation failed: \(error)")
        }
    }
}
#endif
