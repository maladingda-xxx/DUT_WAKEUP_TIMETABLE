//
//  CourseRepository.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData

/// 课程数据访问层 — 直接操作 SwiftData，不包含业务逻辑
/// Widget 和主 App 共享同一数据源（通过 AppGroup 容器），Widget 端只读
@Observable
final class CourseRepository {

    // MARK: - Properties

    private let context: ModelContext

    // MARK: - Init

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Course 查询

    /// 获取指定学期的全部课程
    func fetchAllCourses(semesterID: UUID) -> [Course] {
        let sid = semesterID
        var descriptor = FetchDescriptor<Course>(
            predicate: #Predicate<Course> { course in
                course.semester?.id == sid
            },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.schedules]
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 按 ID 获取单门课程
    func fetchCourse(id: UUID) -> Course? {
        let cid = id
        var descriptor = FetchDescriptor<Course>(
            predicate: #Predicate<Course> { course in
                course.id == cid
            }
        )
        descriptor.fetchLimit = 1
        descriptor.relationshipKeyPathsForPrefetching = [\.schedules, \.exams]
        return try? context.fetch(descriptor).first
    }

    /// 按教务系统课程编号查询（用于教务导入去重）
    func fetchCourse(byCode code: String, semesterID: UUID) -> Course? {
        let queryCode = code
        let sid = semesterID
        var descriptor = FetchDescriptor<Course>(
            predicate: #Predicate<Course> { course in
                course.code == queryCode && course.semester?.id == sid
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// 获取指定周次、指定学期的课程（含单双周过滤）
    func fetchCourses(weekNumber: Int, semesterID: UUID) -> [Course] {
        let all = fetchAllCourses(semesterID: semesterID)
        return all.filter { course in
            course.activeSchedules(for: weekNumber).isNotEmpty
        }
    }

    /// 获取指定星期几、指定周次的课程
    func fetchCourses(
        dayOfWeek: Int,
        weekNumber: Int,
        semesterID: UUID
    ) -> [Course] {
        fetchCourses(weekNumber: weekNumber, semesterID: semesterID)
            .filter { $0.schedules(for: dayOfWeek, weekNumber: weekNumber).isNotEmpty }
    }

    /// 获取指定节次范围内的课程数（冲突检测用）
    func fetchConflictingCourses(
        dayOfWeek: Int,
        startPeriod: Int,
        endPeriod: Int,
        weekNumber: Int,
        semesterID: UUID,
        excludeCourseID: UUID? = nil
    ) -> [Course] {
        let courses = fetchCourses(dayOfWeek: dayOfWeek, weekNumber: weekNumber, semesterID: semesterID)
        return courses.filter { course in
            guard course.id != excludeCourseID else { return false }
            return course.schedules(for: dayOfWeek, weekNumber: weekNumber).contains { schedule in
                // 时间段有交集
                !(schedule.endPeriod < startPeriod || schedule.startPeriod > endPeriod)
            }
        }
    }

    // MARK: - Course 写入

    /// 插入新课程（含级联插入 schedules 和 exams）
    func insert(_ course: Course) {
        context.insert(course)
        if let schedules = course.schedules {
            for schedule in schedules {
                context.insert(schedule)
            }
        }
        if let exams = course.exams {
            for exam in exams {
                context.insert(exam)
            }
        }
        save()
    }

    /// 批量插入课程（用于教务导入）
    func insertBatch(_ courses: [Course]) {
        for course in courses {
            context.insert(course)
            if let schedules = course.schedules {
                for schedule in schedules {
                    context.insert(schedule)
                }
            }
            if let exams = course.exams {
                for exam in exams {
                    context.insert(exam)
                }
            }
        }
        save()
    }

    /// 更新课程（标记 updatedAt）
    func update(_ course: Course) {
        course.updatedAt = Date()
        save()
    }

    /// 删除课程（级联删除关联的 schedules 和 exams）
    func delete(_ course: Course) {
        context.delete(course)
        save()
    }

    /// 删除指定学期全部课程
    func deleteAll(semesterID: UUID) {
        let courses = fetchAllCourses(semesterID: semesterID)
        for course in courses {
            context.delete(course)
        }
        save()
    }

    // MARK: - Schedule 管理

    /// 添加时间安排
    func addSchedule(_ schedule: CourseSchedule, to course: Course) {
        schedule.course = course
        context.insert(schedule)
        save()
    }

    /// 删除时间安排
    func removeSchedule(_ schedule: CourseSchedule) {
        context.delete(schedule)
        save()
    }

    // MARK: - 统计

    /// 某学期课程总数
    func courseCount(semesterID: UUID) -> Int {
        fetchAllCourses(semesterID: semesterID).count
    }

    /// 某周课程总数
    func courseCount(weekNumber: Int, semesterID: UUID) -> Int {
        fetchCourses(weekNumber: weekNumber, semesterID: semesterID).count
    }

    // MARK: - Private

    private func save() {
        do {
            try context.save()
        } catch {
            print("[CourseRepository] Save failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Helper

private extension Array {
    var isNotEmpty: Bool { !isEmpty }
}
