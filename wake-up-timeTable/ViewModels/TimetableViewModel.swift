//
//  TimetableViewModel.swift
//  wake-up-timeTable
//

import Foundation

@Observable
final class TimetableViewModel {
    var courses: [Course] = []
    var currentWeekNumber: Int = 1
    var totalWeeks: Int = 18
    var isLoading: Bool = false
    var errorMessage: String?

    private let courseService: CourseServiceProtocol
    private let semesterService: SemesterServiceProtocol

    init(
        courseService: CourseServiceProtocol,
        semesterService: SemesterServiceProtocol
    ) {
        self.courseService = courseService
        self.semesterService = semesterService
    }

    // MARK: - Data Loading

    func loadCourses() {
        guard let semester = semesterService.fetchCurrentSemester() else {
            errorMessage = "请先设置当前学期"
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        currentWeekNumber = min(max(Date().weeksSince(semester.startDate), 1), semester.totalWeeks)
        totalWeeks = semester.totalWeeks
        courses = courseService.fetchCourses(for: semester, weekNumber: currentWeekNumber)
    }

    /// 重新加载指定周次的课程
    func loadCourses(weekNumber: Int) {
        guard let semester = semesterService.fetchCurrentSemester() else {
            errorMessage = "请先设置当前学期"
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        courses = courseService.fetchCourses(for: semester, weekNumber: weekNumber)
    }

    // MARK: - Week Navigation

    func goToNextWeek() {
        guard currentWeekNumber < totalWeeks else { return }
        currentWeekNumber += 1
        loadCourses(weekNumber: currentWeekNumber)
    }

    func goToPreviousWeek() {
        guard currentWeekNumber > 1 else { return }
        currentWeekNumber -= 1
        loadCourses(weekNumber: currentWeekNumber)
    }

    func goToWeek(_ week: Int) {
        guard week >= 1, week <= totalWeeks else { return }
        currentWeekNumber = week
        loadCourses(weekNumber: week)
    }

    /// 跳转到「今天」所在的周
    func goToToday() {
        guard let semester = semesterService.fetchCurrentSemester() else { return }
        let todayWeek = min(max(Date().weeksSince(semester.startDate), 1), semester.totalWeeks)
        goToWeek(todayWeek)
    }

    // MARK: - Week Range Display

    /// 当前周对应的日期范围描述，如 "9月1日 - 9月7日"
    var weekDateRange: String {
        guard let semester = semesterService.fetchCurrentSemester() else {
            return ""
        }
        let calendar = Calendar.current
        // 使用 startOfWeek 与 weeksSince 保持一致的锚点
        let baseMonday = semester.startDate.startOfWeek
        let monday = calendar.date(
            byAdding: .weekOfYear,
            value: currentWeekNumber - 1,
            to: baseMonday
        ) ?? baseMonday
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday

        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: monday)) - \(formatter.string(from: sunday))"
    }

    /// 是否已到学期末尾
    var isAtEnd: Bool {
        currentWeekNumber >= totalWeeks
    }

    /// 是否在学期开头
    var isAtStart: Bool {
        currentWeekNumber <= 1
    }

    /// 获取指定 dayIndex (0=周一) 在当前周的日期
    func dayDate(for dayIndex: Int) -> Date? {
        guard let semester = semesterService.fetchCurrentSemester() else { return nil }
        let calendar = Calendar.current
        let baseMonday = semester.startDate.startOfWeek
        let monday = calendar.date(
            byAdding: .weekOfYear,
            value: currentWeekNumber - 1,
            to: baseMonday
        ) ?? baseMonday
        return calendar.date(byAdding: .day, value: dayIndex, to: monday)
    }
}
