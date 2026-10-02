//
//  TimetableView.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

struct TimetableView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: TimetableViewModel?
    @State private var selectedCourse: Course?
    @State private var showCourseDetail: Bool = false
    @State private var showCourseEdit: Bool = false
    @State private var showNoSemesterAlert: Bool = false
    /// 长按课程卡片进行颜色自定义
    @State private var colorPickerCourse: Course?
    @State private var showColorPicker: Bool = false
    /// 周切换动画方向：true = 切到下一周（新周从右滑入），false = 切到上一周（新周从左滑入）
    @State private var nextWeekTransition = true

    // MARK: - Layout Constants

    private let periodLabelWidth: CGFloat = 52
    private let periodRowHeight: CGFloat = 52
    private let headerHeight: CGFloat = 42
    private let cellPadding: CGFloat = 2

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let viewModel {
                    if let errorMessage = viewModel.errorMessage {
                        errorStateView(message: errorMessage)
                    } else {
                        weekSelector(viewModel: viewModel)
                        separator
                        weekContent(viewModel: viewModel)
                            .id(viewModel.currentWeekNumber)
                            .transition(weekTransition)
                    }
                } else {
                    ProgressView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .simultaneousGesture(swipeGesture)
            .navigationTitle("课程表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showCourseDetail) {
                if let course = selectedCourse {
                    CourseDetailView(
                        course: course,
                        weekNumber: viewModel?.currentWeekNumber ?? 1
                    )
                }
            }
            .sheet(isPresented: $showCourseEdit) {
                let semesterService = SemesterService(modelContext: modelContext)
                if let semester = semesterService.fetchCurrentSemester() {
                    CourseEditView(semester: semester)
                }
            }
            .sheet(isPresented: $showColorPicker) {
                if let course = colorPickerCourse {
                    CourseColorSheet(course: course)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                initViewModel()
            } else {
                viewModel?.loadCourses()
            }
        }
        .onChange(of: showCourseEdit) { _, newValue in
            if !newValue {
                viewModel?.loadCourses()
            }
        }
        .onChange(of: showCourseDetail) { _, newValue in
            if !newValue {
                viewModel?.loadCourses()
            }
        }
        .onChange(of: showColorPicker) { _, newValue in
            if !newValue {
                viewModel?.loadCourses()
            }
        }
        .alert("无法添加课程", isPresented: $showNoSemesterAlert) {
            Button("好", role: .cancel) { }
        } message: {
            Text("请先在「设置 → 学期管理」中添加并设置当前学期")
        }
    }

    // MARK: - ViewModel Init

    private func initViewModel() {
        let vm = TimetableViewModel(
            courseService: CourseService(modelContext: modelContext),
            semesterService: SemesterService(modelContext: modelContext)
        )
        vm.loadCourses()
        viewModel = vm
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel?.goToToday()
            } label: {
                Text("今天")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                let semesterService = SemesterService(modelContext: modelContext)
                if semesterService.fetchCurrentSemester() != nil {
                    showCourseEdit = true
                } else {
                    showNoSemesterAlert = true
                }
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: - Separator

    private var separator: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }

    // MARK: - Week Selector

    private func weekSelector(viewModel: TimetableViewModel) -> some View {
        HStack(spacing: 0) {
            Button {
                goToPreviousWeekAnimated()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.isAtStart ? .tertiary : .primary)
                    .frame(width: 40, height: 36)
            }
            .disabled(viewModel.isAtStart)

            Spacer()

            VStack(spacing: 2) {
                Text("第 \(viewModel.currentWeekNumber) 周")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(viewModel.weekDateRange)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                goToNextWeekAnimated()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(viewModel.isAtEnd ? .tertiary : .primary)
                    .frame(width: 40, height: 36)
            }
            .disabled(viewModel.isAtEnd)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Week Content (随周次滑动的部分)

    private func weekContent(viewModel: TimetableViewModel) -> some View {
        VStack(spacing: 0) {
            dayHeaderRow(viewModel: viewModel)
            separator
            timetableGrid(viewModel: viewModel)
        }
    }

    // MARK: - Day Header

    private func dayHeaderRow(viewModel: TimetableViewModel) -> some View {
        GeometryReader { geometry in
            let dayWidth = (geometry.size.width - periodLabelWidth) / CGFloat(schoolDays)
            HStack(spacing: 0) {
                Color.clear.frame(width: periodLabelWidth, height: headerHeight)

                ForEach(0..<schoolDays, id: \.self) { index in
                    VStack(spacing: 2) {
                        Text(dayName(for: index))
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(dayDateString(for: index, viewModel: viewModel))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: dayWidth, height: headerHeight)
                }
            }
        }
        .frame(height: headerHeight)
        .background(Color(.systemBackground))
    }

    // MARK: - Timetable Grid

    private func timetableGrid(viewModel: TimetableViewModel) -> some View {
        GeometryReader { geometry in
            let dayWidth = (geometry.size.width - periodLabelWidth) / CGFloat(schoolDays)
            let gridWidth = CGFloat(schoolDays) * dayWidth
            let gridHeight = CGFloat(totalPeriods) * periodRowHeight

            ScrollView(.vertical, showsIndicators: false) {
                HStack(spacing: 0) {
                    periodLabels
                    ZStack(alignment: .topLeading) {
                        gridLines(dayWidth: dayWidth, gridWidth: gridWidth, gridHeight: gridHeight)
                        courseCards(viewModel: viewModel, dayWidth: dayWidth)
                        currentTimeIndicator(dayWidth: dayWidth, gridWidth: gridWidth)
                    }
                    .frame(width: gridWidth, height: gridHeight)
                }
            }
        }
    }

    // MARK: - Period Labels

    private var periodLabels: some View {
        VStack(spacing: 0) {
            ForEach(1...totalPeriods, id: \.self) { period in
                VStack(spacing: 1) {
                    Text("\(period)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(periodStartTime(period))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: periodLabelWidth, height: periodRowHeight)
            }
        }
    }

    // MARK: - Grid Lines

    private func gridLines(dayWidth: CGFloat, gridWidth: CGFloat, gridHeight: CGFloat) -> some View {
        Group {
            ForEach(0...totalPeriods, id: \.self) { period in
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: gridWidth, height: period == 0 || period == totalPeriods ? 0.5 : 0.33)
                    .offset(y: CGFloat(period) * periodRowHeight)
            }

            ForEach(0...schoolDays, id: \.self) { day in
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: day == 0 || day == schoolDays ? 0.5 : 0.33, height: gridHeight)
                    .offset(x: CGFloat(day) * dayWidth)
            }
        }
    }

    // MARK: - Course Cards

    private func courseCards(viewModel: TimetableViewModel, dayWidth: CGFloat) -> some View {
        ForEach(viewModel.courses, id: \.id) { course in
            ForEach(course.activeSchedules(for: viewModel.currentWeekNumber), id: \.id) { schedule in
                CourseCell(
                    course: course,
                    schedule: schedule,
                    columnWidth: dayWidth
                )
                .frame(
                    width: dayWidth - cellPadding * 2,
                    height: CGFloat(schedule.duration) * periodRowHeight - cellPadding * 2
                )
                .offset(
                    x: CGFloat(schedule.dayOfWeek - 1) * dayWidth + cellPadding,
                    y: CGFloat(schedule.startPeriod - 1) * periodRowHeight + cellPadding
                )
                .onTapGesture {
                    selectedCourse = course
                    showCourseDetail = true
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    colorPickerCourse = course
                    showColorPicker = true
                }
            }
        }
    }

    // MARK: - Current Time Indicator

    private func currentTimeIndicator(dayWidth: CGFloat, gridWidth: CGFloat) -> some View {
        let now = Date()
        let weekday = now.weekdayIndex

        guard weekday >= 1 && weekday <= schoolDays else {
            return AnyView(EmptyView())
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let timeValue = Double(hour) + Double(minute) / 60.0

        var yPosition: CGFloat = -1
        for periodConfig in Constants.periodTimes {
            guard let startHour = hourFromTimeString(periodConfig.start),
                  let endHour = hourFromTimeString(periodConfig.end) else { continue }

            if timeValue >= startHour && timeValue < endHour {
                let progress = (timeValue - startHour) / (endHour - startHour)
                yPosition = CGFloat(periodConfig.period - 1) * periodRowHeight + CGFloat(progress) * periodRowHeight
                break
            }
        }

        if yPosition == -1 {
            if let firstStart = Constants.periodTimes.first?.start,
               let firstHour = hourFromTimeString(firstStart),
               timeValue < firstHour {
                yPosition = 0
            }
        }

        guard yPosition >= 0 else {
            return AnyView(EmptyView())
        }

        let xPosition = CGFloat(weekday - 1) * dayWidth

        return AnyView(
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                    .offset(x: xPosition - 3, y: yPosition - 3)

                Rectangle()
                    .fill(.red)
                    .frame(width: gridWidth, height: 1.5)
                    .offset(y: yPosition)
            }
        )
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

    // MARK: - Helpers

    private var schoolDays: Int { Constants.schoolDaysPerWeek }
    private var totalPeriods: Int { Constants.totalPeriodsPerDay }

    private func dayName(for index: Int) -> String {
        WeekDay(rawValue: index + 1)?.shortName ?? ""
    }

    private func dayDateString(for index: Int, viewModel: TimetableViewModel) -> String {
        guard let date = viewModel.dayDate(for: index) else { return "" }
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }

    private func periodStartTime(_ period: Int) -> String {
        Constants.periodTimes.first(where: { $0.period == period })?.start ?? ""
    }

    private func hourFromTimeString(_ time: String) -> Double? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Double(parts[0]),
              let minute = Double(parts[1]) else { return nil }
        return hour + minute / 60.0
    }

    // MARK: - Swipe & Week Navigation

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { handleSwipe($0) }
    }

    /// 左右滑动切换周；仅在「明显横向滑动」时触发，避免与纵向滚动冲突
    private func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width
        let dy = value.translation.height
        guard abs(dx) > 50, abs(dx) > abs(dy) else { return }
        if dx < 0 {
            goToNextWeekAnimated()
        } else {
            goToPreviousWeekAnimated()
        }
    }

    /// 周切换动画：旧周滑出、新周从反方向滑入，方向与滑动方向一致
    private var weekTransition: AnyTransition {
        nextWeekTransition
            ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
            : .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
    }

    private func goToNextWeekAnimated() {
        nextWeekTransition = true
        withAnimation(.easeInOut(duration: 0.28)) {
            viewModel?.goToNextWeek()
        }
    }

    private func goToPreviousWeekAnimated() {
        nextWeekTransition = false
        withAnimation(.easeInOut(duration: 0.28)) {
            viewModel?.goToPreviousWeek()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = MockDataGenerator.previewContainer()
    return TimetableView()
        .modelContainer(container)
}
#endif
