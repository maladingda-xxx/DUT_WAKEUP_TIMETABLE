//
//  SettingsView.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var reminderSettings = ReminderSettings()

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    settingsContent(with: viewModel)
                } else {
                    ProgressView()
                        .onAppear {
                            let vm = SettingsViewModel(
                                semesterService: SemesterService(modelContext: modelContext)
                            )
                            vm.loadSemesters()
                            viewModel = vm
                        }
                }
            }
            .navigationTitle("设置")
        }
        .onAppear {
            viewModel?.loadSemesters()
        }
    }

    @ViewBuilder
    private func settingsContent(with viewModel: SettingsViewModel) -> some View {
        List {
            // MARK: - 提醒设置
            Section {
                Toggle(isOn: $reminderSettings.isEnabled) {
                    Label("上课提醒", systemImage: "bell.fill")
                }
                .onChange(of: reminderSettings.isEnabled) { _, _ in
                    refreshAllNotifications()
                }

                if reminderSettings.isEnabled {
                    Picker("提前时间", selection: $reminderSettings.minutesBefore) {
                        ForEach(ReminderSettings.availableOptions, id: \.self) { minutes in
                            Text("\(minutes) 分钟").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: reminderSettings.minutesBefore) { _, _ in
                        refreshAllNotifications()
                    }
                }
            } header: {
                Text("提醒")
            } footer: {
                Text(reminderSettings.isEnabled
                     ? "每节课开始前 \(reminderSettings.minutesBefore) 分钟发送通知提醒"
                     : "开启后，将在上课前通过通知提醒你")
            }

            // MARK: - 学期管理
            Section("学期管理") {
                NavigationLink {
                    SemesterManagementView()
                } label: {
                    HStack {
                        Text("当前学期")
                        Spacer()
                        if let semester = viewModel.currentSemester {
                            Text(semester.name)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("未设置")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // MARK: - 数据
            Section("数据") {
                NavigationLink {
                    DUTImportDebugView()
                        .navigationTitle("导入课程")
                } label: {
                    Label("从教务系统导入", systemImage: "tray.and.arrow.down")
                }
            }

            // MARK: - 关于
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(Constants.appVersion)
                        .foregroundStyle(.secondary)
                }

            }
        }
    }

    // MARK: - Helpers

    private func refreshAllNotifications() {
        guard viewModel != nil else { return }
        let semesterService = SemesterService(modelContext: modelContext)
        let courseService = CourseService(modelContext: modelContext)

        guard let semester = semesterService.fetchCurrentSemester() else { return }
        let courses = courseService.fetchCourses(for: semester)

        Task {
            if reminderSettings.isEnabled {
                NotificationManager.shared.removeExpiredAndRefresh(
                    courses: courses,
                    semester: semester,
                    settings: reminderSettings
                )
            } else {
                NotificationManager.shared.removeAllReminders()
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Course.self, CourseSchedule.self, Semester.self, Exam.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return SettingsView()
        .modelContainer(container)
}
