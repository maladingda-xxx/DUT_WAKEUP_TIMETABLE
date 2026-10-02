//
//  TodayCoursesWidget.swift
//  TimetableWidgetExtension
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TodayCoursesProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayCoursesEntry {
        makePlaceholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayCoursesEntry) -> Void) {
        if context.isPreview {
            completion(makePlaceholderEntry())
        } else {
            completion(makeCurrentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayCoursesEntry>) -> Void) {
        let entry = makeCurrentEntry()
        let refreshDate = entry.nextRefreshDate
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    // MARK: - Entry Building

    private func makeCurrentEntry() -> TodayCoursesEntry {
        let data = WidgetDataProvider.fetchTodayData()
        let now = Date()
        let refreshDate = WidgetDataProvider.nextRefreshTime(
            courses: data.courses,
            current: data.current,
            next: data.next
        )

        return TodayCoursesEntry(
            date: now,
            courses: data.courses,
            currentCourse: data.current,
            nextCourse: data.next,
            weekdayText: WeekDay(rawValue: now.weekdayIndex)?.shortName ?? "",
            dateText: formatDate(now),
            nextRefreshDate: refreshDate
        )
    }

    private func makePlaceholderEntry() -> TodayCoursesEntry {
        TodayCoursesEntry(
            date: Date(),
            courses: [
                WidgetCourse(
                    id: "1", name: "高等数学A1", location: "综151",
                    teacherName: "张明", startPeriod: 1, endPeriod: 2,
                    startTime: "08:00", endTime: "09:35",
                    colorHex: "#4A90D9", isCurrent: false
                ),
                WidgetCourse(
                    id: "2", name: "大学物理A1", location: "综201",
                    teacherName: "李芳", startPeriod: 3, endPeriod: 4,
                    startTime: "09:50", endTime: "11:25",
                    colorHex: "#7EC856", isCurrent: false
                ),
            ],
            currentCourse: nil,
            nextCourse: WidgetCourse(
                id: "1", name: "高等数学A1", location: "综151",
                teacherName: "张明", startPeriod: 1, endPeriod: 2,
                startTime: "08:00", endTime: "09:35",
                colorHex: "#4A90D9", isCurrent: false
            ),
            weekdayText: "周二",
            dateText: "7月15日",
            nextRefreshDate: Date().addingTimeInterval(900)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

// MARK: - Widget Views

struct TodayCoursesSmallView: View {
    let entry: TodayCoursesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.dateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("下一节")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let next = entry.nextCourse {
                Circle()
                    .fill(Color(hex: next.colorHex))
                    .frame(width: 8, height: 8)

                Text(next.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(next.timeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(next.location)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else if let current = entry.currentCourse {
                Circle()
                    .fill(Color(hex: current.colorHex))
                    .frame(width: 8, height: 8)

                Text(current.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text("\(current.timeText) 进行中")
                    .font(.caption2)
                    .foregroundStyle(.green)

                Text(current.location)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else if entry.courses.isEmpty {
                Text("今天\n没课")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("课程\n已结束")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}

struct TodayCoursesMediumView: View {
    let entry: TodayCoursesEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧当前状态
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.weekdayText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                if let current = entry.currentCourse {
                    courseStatusCard(
                        title: "正在上",
                        course: current,
                        accentColor: .green
                    )
                } else if let next = entry.nextCourse {
                    courseStatusCard(
                        title: "下一节",
                        course: next,
                        accentColor: .orange
                    )
                } else {
                    Text(entry.courses.isEmpty ? "今天没课" : "已结束")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 右侧课程列表
            VStack(alignment: .leading, spacing: 0) {
                Text("今日课程")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                let displayCourses = Array(entry.courses.prefix(4))
                ForEach(displayCourses) { course in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: course.colorHex))
                            .frame(width: 6, height: 6)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(course.name)
                                .font(.caption2)
                                .fontWeight(course.isCurrent ? .semibold : .regular)
                                .lineLimit(1)
                            Text("\(course.startTime)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if course.isCurrent {
                            Circle()
                                .fill(.green)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if entry.courses.count > 4 {
                    Text("还有 \(entry.courses.count - 4) 节课...")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }

    private func courseStatusCard(title: String, course: WidgetCourse, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(accentColor)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: course.colorHex))
                    .frame(width: 8, height: 8)
                Text(course.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            Text(course.timeText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(course.location)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.1))
        )
    }
}

// MARK: - Widget Entry View

struct TodayCoursesWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodayCoursesEntry

    var body: some View {
        switch family {
        case .systemSmall:
            TodayCoursesSmallView(entry: entry)
        case .systemMedium:
            TodayCoursesMediumView(entry: entry)
        default:
            TodayCoursesSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct TodayCoursesWidget: Widget {
    let kind = "com.dingjiayuan.wake-up-timeTable.TodayCoursesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: TodayCoursesProvider()
        ) { entry in
            TodayCoursesWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日课程")
        .description("查看今天的课程安排和下一节课信息")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
