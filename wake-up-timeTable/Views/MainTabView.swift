//
//  MainTabView.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "sun.max.fill")
                }

            TimetableView()
                .tabItem {
                    Label("课表", systemImage: "tablecells.fill")
                }

            CalendarView()
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Course.self, CourseSchedule.self, Semester.self, Exam.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return MainTabView()
        .modelContainer(container)
}
