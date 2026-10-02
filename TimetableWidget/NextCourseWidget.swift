//
//  NextCourseWidget.swift
//  TimetableWidgetExtension
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct NextCourseProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodayCoursesEntry {
        makePlaceholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayCoursesEntry) -> Void) {
        completion(context.isPreview ? makePlaceholderEntry() : makeCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayCoursesEntry>) -> Void) {
        let entry = makeCurrentEntry()
        let timeline = Timeline(entries: [entry], policy: .after(entry.nextRefreshDate))
        completion(timeline)
    }

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
            courses: [],
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

// MARK: - Accessory Widget Views

/// 锁屏圆形小组件
struct NextCourseAccessoryCircularView: View {
    let entry: TodayCoursesEntry

    var body: some View {
        if let next = entry.nextCourse {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Text(next.name.prefix(3).description)
                        .font(.system(size: 10, weight: .bold))
                    Text(next.startTime)
                        .font(.system(size: 9))
                }
            }
        } else if let current = entry.currentCourse {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "book.fill")
                    .font(.system(size: 16))
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.yellow)
            }
        }
    }
}

/// 锁屏矩形小组件
struct NextCourseAccessoryRectangularView: View {
    let entry: TodayCoursesEntry

    var body: some View {
        if let next = entry.nextCourse {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: next.colorHex))
                        .frame(width: 6, height: 6)
                    Text(next.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text("\(next.startTime)-\(next.endTime)")
                    .font(.caption)
                    Text(next.location)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
            }
        } else if let current = entry.currentCourse {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: current.colorHex))
                        .frame(width: 6, height: 6)
                    Text(current.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text("进行中 · 至 \(current.endTime)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.courses.isEmpty ? "今天没课" : "课程已结束")
                    .font(.headline)
                Text(entry.weekdayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 锁屏内联小组件
struct NextCourseAccessoryInlineView: View {
    let entry: TodayCoursesEntry

    var body: some View {
        if let next = entry.nextCourse {
            Text("下一节: \(next.name) \(next.startTime)")
        } else if let current = entry.currentCourse {
            Text("进行中: \(current.name) 至\(current.endTime)")
        } else if entry.courses.isEmpty {
            Text("今天没课 ☀️")
        } else {
            Text("课程已全部结束 ✅")
        }
    }
}

// MARK: - Widget Entry View

struct NextCourseWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodayCoursesEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            NextCourseAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            NextCourseAccessoryRectangularView(entry: entry)
        case .accessoryInline:
            NextCourseAccessoryInlineView(entry: entry)
        default:
            NextCourseAccessoryRectangularView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct NextCourseWidget: Widget {
    let kind = "com.dingjiayuan.wake-up-timeTable.NextCourseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: NextCourseProvider()
        ) { entry in
            NextCourseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("下一节课")
        .description("在锁屏上显示下一节课信息")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
