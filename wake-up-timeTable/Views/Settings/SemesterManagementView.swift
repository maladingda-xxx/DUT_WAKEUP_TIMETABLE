//
//  SemesterManagementView.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

struct SemesterManagementView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var semesters: [Semester] = []
    @State private var currentSemester: Semester?
    @State private var showAddSheet: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var semesterToDelete: Semester?

    var body: some View {
        List {
            Section {
                if semesters.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("暂无学期数据")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                } else {
                    ForEach(semesters, id: \.id) { semester in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(semester.name)
                                    .font(.body)
                                    .fontWeight(semester.isCurrent ? .semibold : .regular)

                                Text(dateRangeText(for: semester))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if semester.isCurrent {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.blue)
                                        .frame(width: 6, height: 6)
                                    Text("当前")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(.blue.opacity(0.1))
                                )
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            setCurrent(semester)
                        }
                    }
                    .onDelete(perform: confirmDelete)
                }
            } header: {
                Text("所有学期")
            } footer: {
                Text("点击设为当前学期，左滑删除。删除学期将同时删除该学期下的所有课程。")
            }
        }
        .navigationTitle("学期管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSemesterSheet { newSemester in
                let service = SemesterService(modelContext: modelContext)
                service.addSemester(newSemester)
                loadData()
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                if let semester = semesterToDelete {
                    let service = SemesterService(modelContext: modelContext)
                    service.deleteSemester(semester)
                    loadData()
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("删除学期「\(semesterToDelete?.name ?? "")」将同时删除该学期下的所有课程数据，此操作不可撤销。")
        }
        .onAppear { loadData() }
    }

    // MARK: - Data

    private func loadData() {
        let service = SemesterService(modelContext: modelContext)
        semesters = service.fetchAllSemesters()
        currentSemester = service.fetchCurrentSemester()
    }

    private func setCurrent(_ semester: Semester) {
        guard !semester.isCurrent else { return }
        let service = SemesterService(modelContext: modelContext)
        service.setCurrentSemester(semester)
        loadData()
    }

    private func confirmDelete(_ indexSet: IndexSet) {
        if let index = indexSet.first {
            semesterToDelete = semesters[index]
            showDeleteAlert = true
        }
    }

    // MARK: - Helpers

    private func dateRangeText(for semester: Semester) -> String {
        let calendar = Calendar.current
        let endDate = calendar.date(
            byAdding: .day,
            value: semester.totalWeeks * 7 - 1,
            to: semester.startDate.startOfWeek
        ) ?? semester.startDate

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.M.d"
        return "\(fmt.string(from: semester.startDate.startOfWeek)) - \(fmt.string(from: endDate)) · 共\(semester.totalWeeks)周"
    }
}

// MARK: - AddSemesterSheet

private struct AddSemesterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var startDate: Date = {
        // 找最近的周一
        let now = Date()
        return now.startOfWeek
    }()
    @State private var totalWeeks: Int = 18

    let onSave: (Semester) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("学期信息") {
                    TextField("学期名称（如 2027-2028 第一学期）", text: $name)
                    DatePicker("开学日期", selection: $startDate, displayedComponents: .date)
                    Stepper("教学周数: \(totalWeeks)", value: $totalWeeks, in: 8...25)
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(name.isEmpty ? "请输入学期名称" : name)
                                .font(.headline)
                            let fmt = DateFormatter()
                            let _ = { fmt.dateFormat = "yyyy.M.d" }()
                            Text("\(fmt.string(from: startDate.startOfWeek)) 起 · 共\(totalWeeks)周")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("预览")
                }
            }
            .navigationTitle("添加学期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加") {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmedName.isEmpty else { return }
                        let semester = Semester(
                            name: trimmedName,
                            startDate: startDate.startOfWeek,
                            totalWeeks: totalWeeks,
                            startWeekNumber: 1,
                            isCurrent: false
                        )
                        onSave(semester)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
