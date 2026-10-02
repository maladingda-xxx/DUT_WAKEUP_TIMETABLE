//
//  CourseDetailView.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

/// 课程详情页 - 以 Sheet 形式弹出
struct CourseDetailView: View {
    let course: Course
    let weekNumber: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEditSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    infoSection
                    scheduleSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("课程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("编辑") { showEditSheet = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                if let semester = course.semester {
                    CourseEditView(semester: semester, existingCourse: course)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(courseColor)

                VStack(spacing: 8) {
                    Text(course.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Text(course.courseType.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.25))
                            .clipShape(Capsule())

                        if let credits = course.credits {
                            Text("\(String(format: "%.1f", credits)) 学分")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(height: 140)
        }
        .padding([.horizontal, .top], 16)
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            VStack(spacing: 0) {
                infoRow(icon: "person.fill", title: "教师", value: course.teacherName ?? "未指定")
                Divider().padding(.leading, 40)
                infoRow(icon: "mappin.and.ellipse", title: "教室", value: course.location ?? "未指定")
                Divider().padding(.leading, 40)
                infoRow(icon: "number", title: "课程编号", value: course.code ?? "暂无")
                if let note = course.note {
                    Divider().padding(.leading, 40)
                    infoRow(icon: "note.text", title: "备注", value: note)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } header: {
            HStack {
                Text("课程信息")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            VStack(spacing: 0) {
                let activeSchedules = course.activeSchedules(for: weekNumber)

                if activeSchedules.isEmpty {
                    HStack {
                        Text("本周无课程安排")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                } else {
                    ForEach(activeSchedules, id: \.id) { schedule in
                        scheduleRow(schedule)
                        if schedule.id != activeSchedules.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } header: {
            HStack {
                Text("第 \(weekNumber) 周上课安排")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    private var courseColor: Color {
        Color(hex: course.colorHex)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(courseColor)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func scheduleRow(_ schedule: CourseSchedule) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .frame(width: 20)
                .foregroundStyle(courseColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(schedule.dayOfWeekName) \(schedule.periodDescription)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("第\(schedule.startWeek)-\(schedule.endWeek)周")
                    if schedule.weekType != .all {
                        Text("·")
                        Text(schedule.weekType.rawValue)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let loc = schedule.location {
                    Text(loc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = MockDataGenerator.previewContainer()
    let context = container.mainContext
    if let course = (try? context.fetch(FetchDescriptor<Course>()))?.first {
        return CourseDetailView(course: course, weekNumber: 1)
            .modelContainer(container)
    }
    return Text("No data")
}
#endif
