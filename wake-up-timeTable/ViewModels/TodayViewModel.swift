//
//  TodayViewModel.swift
//  wake-up-timeTable
//

import Foundation

@Observable
final class TodayViewModel {
    var courses: [Course] = []
    var currentWeekNumber: Int = 1
    var todayWeekday: Int = 1
    var isLoading: Bool = false
    var errorMessage: String?

    private let courseService: CourseServiceProtocol
    private let semesterService: SemesterServiceProtocol
    let currentCourseService: CurrentCourseService

    // MARK: - Init

    init(
        courseService: CourseServiceProtocol,
        semesterService: SemesterServiceProtocol,
        currentCourseService: CurrentCourseService = CurrentCourseService()
    ) {
        self.courseService = courseService
        self.semesterService = semesterService
        self.currentCourseService = currentCourseService
    }

    // MARK: - Load

    func loadToday() {
        guard let semester = semesterService.fetchCurrentSemester() else {
            errorMessage = "请先设置当前学期"
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        currentWeekNumber = min(max(Date().weeksSince(semester.startDate), 1), semester.totalWeeks)
        todayWeekday = Date().weekdayIndex

        courses = courseService.fetchCourses(
            for: semester,
            dayOfWeek: todayWeekday,
            weekNumber: currentWeekNumber
        )

        refreshAnalysis()
    }

    /// 刷新时间分析（由 Timer 定期调用）
    func refreshAnalysis() {
        currentCourseService.analyze(
            courses: courses,
            weekNumber: currentWeekNumber,
            dayOfWeek: todayWeekday
        )
    }

    // MARK: - Computed Properties

    /// 今天是否所有课程已结束
    var isAllDone: Bool {
        guard !courses.isEmpty else { return false }
        return currentCourseService.nextCourse == nil && !currentCourseService.isInCourse
    }

    /// 今天的日期描述，如 "7月15日"
    var todayDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: Date())
    }

    /// 今天的星期描述，如 "星期二"
    var todayWeekdayText: String {
        WeekDay(rawValue: todayWeekday)?.shortName ?? ""
    }
}
