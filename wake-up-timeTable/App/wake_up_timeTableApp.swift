//
//  wake_up_timeTableApp.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

@main
struct WakeUpTimeTableApp: App {
    let container: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(url: Constants.sharedDatabaseURL)
            container = try ModelContainer(
                for: Course.self,
                CourseSchedule.self,
                Semester.self,
                Exam.self,
                configurations: config
            )
            purgeMockDataIfNeeded()
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    await setupNotifications()
                }
        }
        .modelContainer(container)
    }

    // MARK: - Mock Data Cleanup

    /// 一次性清理早期版本注入的 Mock 示例数据（线性代数、体育等）。
    /// 之后课表只保留从大工教务系统导入的真实课程。
    private func purgeMockDataIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Constants.didPurgeMockDataKey) else { return }

        let context = container.mainContext

        // 1. 删除已知编号的 Mock 课程
        if let courses = try? context.fetch(FetchDescriptor<Course>()) {
            for course in courses
                where MockDataGenerator.mockCourseCodes.contains(course.code ?? "") {
                context.delete(course)
            }
            try? context.save()
        }

        // 2. 删除已无课程关联的 Mock 学期（"2026-2027 第一学期"）
        if let semesters = try? context.fetch(FetchDescriptor<Semester>()) {
            for semester in semesters
                where semester.name == "2026-2027 第一学期"
                    && (semester.courses ?? []).isEmpty {
                context.delete(semester)
            }
            try? context.save()
        }

        defaults.set(true, forKey: Constants.didPurgeMockDataKey)
    }

    // MARK: - Notifications

    private func setupNotifications() async {
        let granted = await NotificationManager.shared.requestAuthorization()
        guard granted else { return }

        // 首次授权后立即生成提醒通知
        let context = container.mainContext
        let semesterService = SemesterService(modelContext: context)
        let courseService = CourseService(modelContext: context)

        guard let semester = semesterService.fetchCurrentSemester() else { return }
        let courses = courseService.fetchCourses(for: semester)

        await NotificationManager.shared.scheduleReminders(
            for: courses,
            semester: semester,
            settings: ReminderSettings()
        )
    }
}
