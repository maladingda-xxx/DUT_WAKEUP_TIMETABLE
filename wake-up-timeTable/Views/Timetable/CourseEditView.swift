//
//  CourseEditView.swift
//  wake-up-timeTable
//

import SwiftUI
import SwiftData

// MARK: - CourseEditView

struct CourseEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let semester: Semester
    let existingCourse: Course?

    // MARK: - Form State

    @State private var name: String = ""
    @State private var code: String = ""
    @State private var teacherName: String = ""
    @State private var location: String = ""
    @State private var selectedCourseType: CourseType = .compulsory
    @State private var creditsText: String = ""
    @State private var note: String = ""
    @State private var colorHex: String = ""
    @State private var scheduleDrafts: [ScheduleInput] = []

    @State private var showScheduleSheet: Bool = false
    @State private var editingScheduleIndex: Int?  // nil = adding new; non-nil = editing existing draft
    @State private var showConflictAlert: Bool = false
    @State private var conflictMessage: String = ""
    @State private var showValidationAlert: Bool = false
    @State private var validationMessage: String = ""

    private var isEditMode: Bool { existingCourse != nil }

    // MARK: - Init

    init(semester: Semester, existingCourse: Course? = nil) {
        self.semester = semester
        self.existingCourse = existingCourse

        if let course = existingCourse {
            _name = State(initialValue: course.name)
            _code = State(initialValue: course.code ?? "")
            _teacherName = State(initialValue: course.teacherName ?? "")
            _location = State(initialValue: course.location ?? "")
            _selectedCourseType = State(initialValue: course.courseType)
            _creditsText = State(initialValue: course.credits.map { String($0) } ?? "")
            _note = State(initialValue: course.note ?? "")
            _colorHex = State(initialValue: course.colorHex)
            _scheduleDrafts = State(initialValue: (course.schedules ?? []).map { schedule in
                ScheduleInput(
                    id: schedule.id,
                    dayOfWeek: schedule.dayOfWeek,
                    startPeriod: schedule.startPeriod,
                    endPeriod: schedule.endPeriod,
                    weekType: schedule.weekType,
                    startWeek: schedule.startWeek,
                    endWeek: schedule.endWeek,
                    location: schedule.location
                )
            })
        } else {
            _colorHex = State(initialValue: CourseType.compulsory.defaultColorHex)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                scheduleSection
            }
            .navigationTitle(isEditMode ? "编辑课程" : "添加课程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveCourse() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showScheduleSheet) {
                ScheduleEditSheet(
                    existingDraft: editingScheduleIndex.map { scheduleDrafts[$0] },
                    onSave: { draft in
                        if let index = editingScheduleIndex {
                            scheduleDrafts[index] = draft
                        } else {
                            scheduleDrafts.append(draft)
                        }
                        showScheduleSheet = false
                    }
                )
            }
            .alert("时间冲突", isPresented: $showConflictAlert) {
                Button("仍然保存") { performSave() }
                Button("返回修改", role: .cancel) { }
            } message: {
                Text(conflictMessage)
            }
            .alert("请完善信息", isPresented: $showValidationAlert) {
                Button("好") { }
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        Section("基本信息") {
            TextField("课程名称", text: $name)

            TextField("课程编号（选填）", text: $code)

            TextField("授课教师（选填）", text: $teacherName)

            TextField("上课地点（选填）", text: $location)

            Picker("课程类型", selection: $selectedCourseType) {
                ForEach(CourseType.allCases, id: \.self) { type in
                    HStack {
                        Circle()
                            .fill(Color(hex: type.defaultColorHex))
                            .frame(width: 12, height: 12)
                        Text(type.rawValue)
                    }
                    .tag(type)
                }
            }
            .onChange(of: selectedCourseType) { _, newType in
                // 如果用户未手动修改颜色则跟随类型自动更新
                let defaults: [CourseType: String] = [
                    .compulsory: CourseType.compulsory.defaultColorHex,
                    .elective: CourseType.elective.defaultColorHex,
                    .experiment: CourseType.experiment.defaultColorHex,
                    .pe: CourseType.pe.defaultColorHex,
                    .other: CourseType.other.defaultColorHex,
                ]
                if defaults.values.contains(colorHex) {
                    colorHex = newType.defaultColorHex
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("课程颜色")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                CourseColorSwatches(selection: $colorHex, columns: 5)

                ColorPicker(
                    "自定义颜色",
                    selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { colorHex = $0.hexString }
                    ),
                    supportsOpacity: false
                )
            }
            .padding(.vertical, 4)

            HStack {
                Text("学分")
                Spacer()
                TextField("0", text: $creditsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("备注（选填）", text: $note, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        Section {
            if scheduleDrafts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("尚未添加时间安排")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                ForEach(Array(scheduleDrafts.enumerated()), id: \.element.id) { index, draft in
                    Button {
                        editingScheduleIndex = index
                        showScheduleSheet = true
                    } label: {
                        scheduleSummaryRow(draft)
                    }
                }
                .onDelete { indexSet in
                    scheduleDrafts.remove(atOffsets: indexSet)
                }
            }

            Button {
                editingScheduleIndex = nil
                showScheduleSheet = true
            } label: {
                Label("添加时间安排", systemImage: "plus.circle")
            }
        } header: {
            Text("时间安排")
        } footer: {
            if !scheduleDrafts.isEmpty {
                Text("左滑删除，点击编辑。同一时段（星期+节次）的多行会自动合并周数范围。")
            }
        }
    }

    // MARK: - Schedule Summary Row

    private func scheduleSummaryRow(_ draft: ScheduleInput) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(WeekDay(rawValue: draft.dayOfWeek)?.shortName ?? "") \(draft.startPeriod)-\(draft.endPeriod)节")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text("第\(draft.startWeek)-\(draft.endWeek)周")
                    if draft.weekType != .all {
                        Text("·")
                        Text(draft.weekType.rawValue)
                            .foregroundStyle(.blue)
                    }
                    if let loc = draft.location, !loc.isEmpty {
                        Text("·")
                        Text(loc)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Save Logic

    private func saveCourse() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            validationMessage = "请输入课程名称"
            showValidationAlert = true
            return
        }
        guard !scheduleDrafts.isEmpty else {
            validationMessage = "请至少添加一条时间安排"
            showValidationAlert = true
            return
        }

        let courseService = CourseService(modelContext: modelContext)
        let excludeID = existingCourse?.id

        // 冲突检测：对每条 schedule draft 检查冲突
        var conflicts: [String] = []
        for draft in scheduleDrafts {
            for week in draft.startWeek...draft.endWeek {
                guard draft.weekType == .all
                    || (draft.weekType == .odd && week % 2 == 1)
                    || (draft.weekType == .even && week % 2 == 0) else { continue }

                let conflicting = courseService.checkConflict(
                    dayOfWeek: draft.dayOfWeek,
                    startPeriod: draft.startPeriod,
                    endPeriod: draft.endPeriod,
                    weekNumber: week,
                    semester: semester,
                    excludeCourseID: excludeID
                )
                for course in conflicting {
                    let desc = "\(course.name)（第\(week)周 \(WeekDay(rawValue: draft.dayOfWeek)?.shortName ?? "") \(draft.startPeriod)-\(draft.endPeriod)节）"
                    if !conflicts.contains(desc) {
                        conflicts.append(desc)
                    }
                }
            }
        }

        if !conflicts.isEmpty {
            conflictMessage = "检测到以下时间冲突：\n\n" + conflicts.prefix(5).joined(separator: "\n")
            if conflicts.count > 5 {
                conflictMessage += "\n...还有 \(conflicts.count - 5) 项冲突"
            }
            showConflictAlert = true
            return
        }

        performSave()
    }

    private func performSave() {
        let courseService = CourseService(modelContext: modelContext)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        let credits: Double? = {
            let trimmed = creditsText.trimmingCharacters(in: .whitespaces)
            return Double(trimmed)
        }()

        if let course = existingCourse {
            // 编辑模式：更新现有课程
            course.name = trimmedName
            course.code = code.trimmingCharacters(in: .whitespaces).nilIfEmpty
            course.teacherName = teacherName.trimmingCharacters(in: .whitespaces).nilIfEmpty
            course.location = location.trimmingCharacters(in: .whitespaces).nilIfEmpty
            course.courseType = selectedCourseType
            course.colorHex = colorHex
            course.credits = credits
            course.note = note.trimmingCharacters(in: .whitespaces).nilIfEmpty

            // 替换所有时间安排：先删旧再建新
            if let oldSchedules = course.schedules {
                for old in oldSchedules {
                    modelContext.delete(old)
                }
            }
            course.schedules = []

            for input in scheduleDrafts {
                let schedule = CourseSchedule(
                    dayOfWeek: input.dayOfWeek,
                    startPeriod: input.startPeriod,
                    endPeriod: input.endPeriod,
                    weekType: input.weekType,
                    startWeek: input.startWeek,
                    endWeek: input.endWeek,
                    location: input.location
                )
                schedule.course = course
                modelContext.insert(schedule)
                course.schedules?.append(schedule)
            }

            courseService.updateCourse(course)
        } else {
            // 创建模式
            courseService.createCourse(
                name: trimmedName,
                code: code.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                teacherName: teacherName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                location: location.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                colorHex: colorHex,
                courseType: selectedCourseType,
                credits: credits,
                note: note.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                schedules: scheduleDrafts,
                semester: semester
            )
        }

        dismiss()
    }
}

// MARK: - ScheduleEditSheet

struct ScheduleEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingDraft: ScheduleInput?
    let onSave: (ScheduleInput) -> Void

    @State private var dayOfWeek: Int = 1
    @State private var startPeriod: Int = 1
    @State private var endPeriod: Int = 2
    @State private var weekType: WeekType = .all
    @State private var startWeek: Int = 1
    @State private var endWeek: Int = 18
    @State private var location: String = ""

    private var isEditMode: Bool { existingDraft != nil }

    init(existingDraft: ScheduleInput? = nil, onSave: @escaping (ScheduleInput) -> Void) {
        self.existingDraft = existingDraft
        self.onSave = onSave

        if let draft = existingDraft {
            _dayOfWeek = State(initialValue: draft.dayOfWeek)
            _startPeriod = State(initialValue: draft.startPeriod)
            _endPeriod = State(initialValue: draft.endPeriod)
            _weekType = State(initialValue: draft.weekType)
            _startWeek = State(initialValue: draft.startWeek)
            _endWeek = State(initialValue: draft.endWeek)
            _location = State(initialValue: draft.location ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("上课时间") {
                    Picker("星期", selection: $dayOfWeek) {
                        ForEach(WeekDay.allCases, id: \.rawValue) { day in
                            Text(day.shortName).tag(day.rawValue)
                        }
                    }

                    Picker("开始节次", selection: $startPeriod) {
                        ForEach(1...12, id: \.self) { p in
                            Text("第\(p)节").tag(p)
                        }
                    }
                    .onChange(of: startPeriod) { _, newValue in
                        if endPeriod < newValue {
                            endPeriod = newValue
                        }
                    }

                    Picker("结束节次", selection: $endPeriod) {
                        ForEach(startPeriod...12, id: \.self) { p in
                            Text("第\(p)节").tag(p)
                        }
                    }
                }

                Section("周次范围") {
                    Picker("周类型", selection: $weekType) {
                        ForEach(WeekType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    Stepper("起始周: 第\(startWeek)周", value: $startWeek, in: 1...25)
                        .onChange(of: startWeek) { _, newValue in
                            if endWeek < newValue {
                                endWeek = newValue
                            }
                        }

                    Stepper("结束周: 第\(endWeek)周", value: $endWeek, in: startWeek...25)
                }

                Section("地点（选填）") {
                    TextField("教室或地点", text: $location)
                }

                // 预览
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("\(WeekDay(rawValue: dayOfWeek)?.shortName ?? "") \(startPeriod)-\(endPeriod)节")
                                .font(.headline)
                            Text("第\(startWeek)-\(endWeek)周 \(weekType.rawValue)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !location.isEmpty {
                                Text(location)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("预览")
                }
            }
            .navigationTitle(isEditMode ? "编辑时间安排" : "添加时间安排")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("确定") {
                        let draft = ScheduleInput(
                            id: existingDraft?.id ?? UUID(),
                            dayOfWeek: dayOfWeek,
                            startPeriod: startPeriod,
                            endPeriod: endPeriod,
                            weekType: weekType,
                            startWeek: startWeek,
                            endWeek: endWeek,
                            location: location.trimmingCharacters(in: .whitespaces).nilIfEmpty
                        )
                        onSave(draft)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - String Helper

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
