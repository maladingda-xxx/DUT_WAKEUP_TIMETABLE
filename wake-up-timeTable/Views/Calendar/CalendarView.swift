//
//  CalendarView.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: CalendarViewModel?
    @State private var selectedCourse: Course?
    @State private var showCourseDetail: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let viewModel {
                    if let errorMessage = viewModel.errorMessage {
                        errorStateView(message: errorMessage)
                    } else {
                        monthNavigator(viewModel: viewModel)
                        dayOfWeekHeader
                        calendarGrid(viewModel: viewModel)
                        Divider().padding(.top, 8)
                        eventList(viewModel: viewModel)
                    }
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("日历")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCourseDetail) {
                if let course = selectedCourse {
                    CourseDetailView(course: course, weekNumber: currentWeekNumber)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = CalendarViewModel(
                    courseService: CourseService(modelContext: modelContext),
                    semesterService: SemesterService(modelContext: modelContext)
                )
                vm.loadMonth()
                viewModel = vm
            } else {
                viewModel?.loadMonth()
            }
        }
        .onChange(of: showCourseDetail) { _, newValue in
            if !newValue {
                viewModel?.loadMonth()
            }
        }
    }

    // MARK: - Error State

    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var currentWeekNumber: Int {
        guard let semester = SemesterService(modelContext: modelContext)
            .fetchCurrentSemester() else { return 1 }
        return min(max(Date().weeksSince(semester.startDate), 1), semester.totalWeeks)
    }

    // MARK: - Month Navigator

    private func monthNavigator(viewModel: CalendarViewModel) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline).fontWeight(.medium)
            }
            .buttonStyle(.plain)

            Spacer()
            Text(viewModel.monthYearText)
                .font(.headline).fontWeight(.semibold)
            Spacer()

            Button {
                viewModel.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline).fontWeight(.medium)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Day of Week Header

    private var dayOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(WeekDay.allCases, id: \.rawValue) { day in
                Text(day.shortName)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(
                        day == .saturday || day == .sunday ? .secondary : .primary
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Calendar Grid

    private func calendarGrid(viewModel: CalendarViewModel) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: viewModel.currentMonth)
        ) ?? Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: monthStart)

        // weekday: 1=Sun -> grid offset: Sun=6, Mon=0, Tue=1, ... Sat=5
        let leadingEmpty = firstWeekday == 1 ? 6 : firstWeekday - 2
        let totalCells = leadingEmpty + daysInMonth
        let rows = (totalCells + 6) / 7

        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        if idx < leadingEmpty || idx >= totalCells {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 44)
                        } else {
                            let dayNum = idx - leadingEmpty + 1
                            let cellDate = calendar.date(
                                byAdding: .day, value: dayNum - 1, to: monthStart
                            ) ?? Date()
                            let dayStart = calendar.startOfDay(for: cellDate)
                            let events = viewModel.eventsForDate(cellDate)
                            let isToday = dayStart == today
                            let isSel = dayStart == calendar.startOfDay(for: viewModel.selectedDate)

                            dayCell(dayNum: dayNum, events: events,
                                    isToday: isToday, isSelected: isSel) {
                                viewModel.selectedDate = cellDate
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4).padding(.vertical, 4)
        .background(Color(.systemBackground))
    }

    private func dayCell(dayNum: Int, events: [CalendarEvent],
                         isToday: Bool, isSelected: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                ZStack {
                    if isToday {
                        Circle().fill(.blue).frame(width: 28, height: 28)
                    } else if isSelected {
                        Circle().fill(Color(.systemGray4)).frame(width: 28, height: 28)
                    }
                    Text("\(dayNum)")
                        .font(.system(size: 14, weight: isToday ? .semibold : .regular))
                        .foregroundStyle(isToday ? .white : .primary)
                }
                if !events.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(events.prefix(3)), id: \.id) { e in
                            Circle().fill(Color(hex: e.colorHex)).frame(width: 5, height: 5)
                        }
                        if events.count > 3 {
                            Text("+\(events.count - 3)")
                                .font(.system(size: 7)).foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Color.clear.frame(height: 7)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Event List

    private func eventList(viewModel: CalendarViewModel) -> some View {
        let events = viewModel.eventsForDate(viewModel.selectedDate)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 选中日期
                HStack {
                    let fmt: DateFormatter = {
                        let f = DateFormatter()
                        f.dateFormat = "M月d日 EEEE"
                        return f
                    }()
                    Text(fmt.string(from: viewModel.selectedDate))
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

                if events.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2).foregroundStyle(.secondary)
                        Text("当天没有课程或考试")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 32)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                            eventRow(event)
                                .onTapGesture {
                                    if event.type == .course, let c = event.sourceCourse {
                                        selectedCourse = c
                                        showCourseDetail = true
                                    }
                                }
                            if idx < events.count - 1 {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color(hex: event.colorHex)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline).fontWeight(.medium)
                Text(event.detail)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if event.type == .exam {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.caption).foregroundStyle(.red)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = MockDataGenerator.previewContainer()
    return CalendarView()
        .modelContainer(container)
}
#endif
