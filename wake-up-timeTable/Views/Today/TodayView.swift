//
//  TodayView.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData
import Combine

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var viewModel: TodayViewModel?
    @State private var selectedCourse: Course?
    @State private var showCourseDetail: Bool = false

    /// 每 30 秒刷新时间分析
    @State private var refreshTimer = Timer.publish(
        every: 30, on: .main, in: .common
    ).autoconnect()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let viewModel {
                        if let errorMessage = viewModel.errorMessage {
                            errorStateView(message: errorMessage)
                        } else if viewModel.isLoading {
                            loadingView
                        } else if viewModel.courses.isEmpty {
                            emptyStateView
                        } else {
                            dateHeader(viewModel: viewModel)
                            if viewModel.currentCourseService.isInCourse {
                                currentCourseSection(viewModel: viewModel)
                            }
                            if let _ = viewModel.currentCourseService.nextCourse {
                                nextCourseSection(viewModel: viewModel)
                            }
                            if viewModel.isAllDone {
                                allDoneSection
                            }
                            allCoursesSection(viewModel: viewModel)
                        }
                    } else {
                        ProgressView()
                            .padding(.top, 100)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCourseDetail) {
                if let course = selectedCourse {
                    CourseDetailView(
                        course: course,
                        weekNumber: viewModel?.currentWeekNumber ?? 1
                    )
                }
            }
            .onReceive(refreshTimer) { _ in
                viewModel?.refreshAnalysis()
            }
        }
        .onAppear {
            if viewModel == nil {
                initViewModel()
            } else {
                viewModel?.loadToday()
            }
        }
        .onChange(of: showCourseDetail) { _, newValue in
            if !newValue {
                viewModel?.loadToday()
            }
        }
    }

    // MARK: - Init

    private func initViewModel() {
        let vm = TodayViewModel(
            courseService: CourseService(modelContext: modelContext),
            semesterService: SemesterService(modelContext: modelContext)
        )
        vm.loadToday()
        viewModel = vm
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("加载中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 100)
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 80, height: 80)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.yellow)
            }
            Text("今天没有课程")
                .font(.title3)
                .fontWeight(.semibold)
            Text("享受美好的一天 ☀️")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Date Header

    private func dateHeader(viewModel: TodayViewModel) -> some View {
        VStack(spacing: 4) {
            Text(viewModel.todayDateText)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(viewModel.todayWeekdayText)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Current Course Section

    private func currentCourseSection(viewModel: TodayViewModel) -> some View {
        let service = viewModel.currentCourseService
        guard let course = service.currentCourse,
              let schedule = service.currentSchedule else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    icon: "record.circle",
                    iconColor: .green,
                    title: "正在上课"
                )

                courseCard(
                    course: course,
                    schedule: schedule,
                    subtitle: "还剩 \(service.timeRemainingText)",
                    subtitleColor: .green,
                    isHighlighted: true
                )
                .onTapGesture {
                    selectedCourse = course
                    showCourseDetail = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        )
    }

    // MARK: - Next Course Section

    private func nextCourseSection(viewModel: TodayViewModel) -> some View {
        let service = viewModel.currentCourseService
        guard let course = service.nextCourse,
              let schedule = service.nextSchedule else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    icon: "clock.badge",
                    iconColor: .orange,
                    title: "即将开始"
                )

                courseCard(
                    course: course,
                    schedule: schedule,
                    subtitle: "\(service.timeUntilNextText)后开始",
                    subtitleColor: .orange,
                    isHighlighted: false
                )
                .onTapGesture {
                    selectedCourse = course
                    showCourseDetail = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        )
    }

    // MARK: - All Done

    private var allDoneSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
            Text("今天的课程已全部结束")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - All Courses Timeline

    private func allCoursesSection(viewModel: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                icon: "list.bullet",
                iconColor: .blue,
                title: "今日课程"
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                let entries = viewModel.currentCourseService.allEntries
                ForEach(Array(entries.enumerated()), id: \.element.schedule.id) { index, entry in
                    timelineRow(
                        course: entry.course,
                        schedule: entry.schedule,
                        isActive: viewModel.currentCourseService.currentSchedule?.id == entry.schedule.id
                    )
                    .onTapGesture {
                        selectedCourse = entry.course
                        showCourseDetail = true
                    }

                    if index < entries.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 30)
    }

    // MARK: - Timeline Row

    private func timelineRow(
        course: Course,
        schedule: CourseSchedule,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 12) {
            // 颜色指示圆点
            Circle()
                .fill(Color(hex: course.colorHex))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(
                            isActive ? Color.green : Color.clear,
                            lineWidth: 2
                        )
                )
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(course.name)
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundStyle(isActive ? .primary : .primary)

                HStack(spacing: 6) {
                    Text(schedule.periodDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let timeText = periodTimeText(schedule) {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(timeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    let location = course.displayLocation(for: schedule)
                    if !location.isEmpty {
                        Text(location)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let teacher = course.teacherName {
                        if !course.displayLocation(for: schedule).isEmpty {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                        Text(teacher)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if isActive {
                Text("进行中")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(.green.opacity(0.15))
                    )
                    .padding(.trailing, 12)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 12)
        .background(
            isActive
                ? Color(.systemGray6).opacity(0.5)
                : Color.clear
        )
    }

    // MARK: - Course Card (Highlighted)

    private func courseCard(
        course: Course,
        schedule: CourseSchedule,
        subtitle: String,
        subtitleColor: Color,
        isHighlighted: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: course.colorHex))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("\(schedule.periodDescription) \(periodTimeText(schedule) ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(subtitleColor)

                let location = course.displayLocation(for: schedule)
                if !location.isEmpty,
                   let teacher = course.teacherName {
                    Text("\(location) · \(teacher)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isHighlighted
                                ? Color(hex: course.colorHex).opacity(0.3)
                                : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    /// 将节次转换为时间字符串，如 "08:00 - 09:35"
    private func periodTimeText(_ schedule: CourseSchedule) -> String? {
        guard let startConfig = Constants.periodTimes.first(where: { $0.period == schedule.startPeriod }),
              let endConfig = Constants.periodTimes.first(where: { $0.period == schedule.endPeriod }) else {
            return nil
        }
        return "\(startConfig.start) - \(endConfig.end)"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = MockDataGenerator.previewContainer()
    return TodayView()
        .modelContainer(container)
}
#endif
