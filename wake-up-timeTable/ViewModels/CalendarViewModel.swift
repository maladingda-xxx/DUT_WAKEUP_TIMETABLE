//
//  CalendarViewModel.swift
//  wake-up-timeTable
//

import Foundation

@Observable
final class CalendarViewModel {
    var selectedDate: Date = Date()
    var currentMonth: Date = Date()
    var eventsByDate: [Date: [CalendarEvent]] = [:]
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

    // MARK: - Load

    func loadMonth() {
        guard let semester = semesterService.fetchCurrentSemester() else {
            errorMessage = "请先设置当前学期"
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let calendar = Calendar.current
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: currentMonth)
        ) else { return }

        guard let monthEnd = calendar.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: monthStart
        ) else { return }

        eventsByDate = [:]

        // 1. 课程事件：将 CourseSchedule 展开为具体日期
        let courses = courseService.fetchCourses(for: semester)
        for course in courses {
            guard let schedules = course.schedules else { continue }
            for schedule in schedules {
                for week in schedule.startWeek...schedule.endWeek {
                    guard schedule.isActive(in: week) else { continue }
                    guard let date = dateFor(week: week, dayOfWeek: schedule.dayOfWeek,
                                              semester: semester) else { continue }
                    guard date >= monthStart && date <= monthEnd else { continue }

                    let event = CalendarEvent(
                        type: .course,
                        title: course.name,
                        date: date,
                        colorHex: course.colorHex,
                        sourceId: course.id,
                        detail: "\(schedule.dayOfWeekName) \(schedule.periodDescription) · 第\(week)周",
                        sourceCourse: course
                    )
                    let dayStart = calendar.startOfDay(for: date)
                    eventsByDate[dayStart, default: []].append(event)
                }
            }
        }

        // 2. 考试事件
        for course in courses {
            guard let exams = course.exams else { continue }
            for exam in exams {
                let examDay = calendar.startOfDay(for: exam.date)
                guard examDay >= monthStart && examDay <= monthEnd else { continue }
                let event = CalendarEvent(
                    type: .exam,
                    title: exam.name,
                    date: exam.date,
                    colorHex: "#E8635A",
                    sourceId: exam.id,
                    detail: exam.location ?? "",
                    sourceCourse: course
                )
                eventsByDate[examDay, default: []].append(event)
            }
        }
    }

    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        eventsByDate[Calendar.current.startOfDay(for: date)] ?? []
    }

    // MARK: - Navigation

    func goToNextMonth() {
        currentMonth = Calendar.current.date(
            byAdding: .month, value: 1, to: currentMonth
        ) ?? currentMonth
        loadMonth()
    }

    func goToPreviousMonth() {
        currentMonth = Calendar.current.date(
            byAdding: .month, value: -1, to: currentMonth
        ) ?? currentMonth
        loadMonth()
    }

    var monthYearText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年 M月"
        return fmt.string(from: currentMonth)
    }

    /// 当前月是否与 selectedDate 不同（用于判断是否需要跳回 today）
    var isCurrentMonth: Bool {
        Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Helpers

    private func dateFor(week: Int, dayOfWeek: Int, semester: Semester) -> Date? {
        let calendar = Calendar.current
        let baseMonday = semester.startDate.startOfWeek
        guard let weekMonday = calendar.date(
            byAdding: .weekOfYear, value: week - 1, to: baseMonday
        ) else { return nil }
        return calendar.date(byAdding: .day, value: dayOfWeek - 1, to: weekMonday)
    }
}

// MARK: - CalendarEvent

struct CalendarEvent: Identifiable {
    var id: String {
        "\(type == .course ? "c" : "e")-\(sourceId)-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
    }

    enum EventType { case course, exam }

    let type: EventType
    let title: String
    let date: Date
    let colorHex: String
    let sourceId: UUID
    let detail: String
    let sourceCourse: Course?
}
