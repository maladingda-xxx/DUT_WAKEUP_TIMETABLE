//
//  CourseCell.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

/// 课程表上的课程卡片
struct CourseCell: View {
    let course: Course
    let schedule: CourseSchedule
    let columnWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private let cellPadding: CGFloat = 2
    private let cornerRadius: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(course.name)
                .font(cellFont)
                .fontWeight(.semibold)
                .lineLimit(duration >= 2 ? 2 : 1)
                .minimumScaleFactor(0.7)

            if let timeText {
                Text(timeText)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .opacity(0.9)
            }

            if duration >= 2 {
                if let location = displayLocation {
                    Text(location)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .opacity(0.85)
                }

                if let teacher = course.teacherName {
                    Text(teacher)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .opacity(0.75)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(cardBackgroundColor.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: shadowColor, radius: 1, x: 0, y: 0.5)
    }

    // MARK: - Computed

    private var duration: Int {
        schedule.duration
    }

    /// 该时段对应的起止时间，如 "08:00 - 09:35"
    private var timeText: String? {
        guard let start = Constants.periodTimes.first(where: { $0.period == schedule.startPeriod })?.start,
              let end = Constants.periodTimes.first(where: { $0.period == schedule.endPeriod })?.end else {
            return nil
        }
        return "\(start) - \(end)"
    }

    private var backgroundColor: Color {
        Color(hex: course.colorHex)
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark
            ? backgroundColor.opacity(0.5)
            : backgroundColor.opacity(0.88)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(0.3)
            : backgroundColor.opacity(0.25)
    }

    private var displayLocation: String? {
        course.displayLocation(for: schedule)
    }

    private var cellFont: Font {
        if duration >= 4 {
            return .system(size: 12)
        } else if duration >= 2 {
            return .system(size: 11)
        } else {
            return .system(size: 10)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = MockDataGenerator.previewContainer()
    let context = container.mainContext
    let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []

    return VStack(spacing: 8) {
        if let course = courses.first,
           let schedule = course.schedules?.first {
            CourseCell(course: course, schedule: schedule, columnWidth: 70)
                .frame(width: 66, height: 100)
        }

        if let course = courses.first,
           let schedule = course.schedules?.first {
            CourseCell(course: course, schedule: schedule, columnWidth: 70)
                .frame(width: 66, height: 46)
        }
    }
    .padding()
    .modelContainer(container)
}
#endif
