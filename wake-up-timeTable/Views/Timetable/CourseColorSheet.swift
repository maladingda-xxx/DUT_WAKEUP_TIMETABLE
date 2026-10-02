//
//  CourseColorSheet.swift
//  wake-up-timeTable
//
//  Created for long-press color customization (mirrors macOS Finder "标签" picker).
//

import SwiftUI
import SwiftData

/// 课程颜色选择 Sheet —— 长按课程卡片后弹出，点选预设色立即生效，也可用原生 ColorPicker 自定义。
struct CourseColorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let course: Course

    /// 原生 ColorPicker 当前值（用于自定义颜色）
    @State private var customColor: Color
    /// 预设色板当前选中项
    @State private var selectedHex: String

    init(course: Course) {
        self.course = course
        _customColor = State(initialValue: Color(hex: course.colorHex))
        _selectedHex = State(initialValue: course.colorHex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewHeader
                    presetGrid
                    customColorSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("更改颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 预览

    private var previewHeader: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: course.colorHex))
                .frame(height: 64)

            Text(course.name)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 预设色网格

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预设颜色")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            CourseColorSwatches(selection: $selectedHex)
        }
        .onChange(of: selectedHex) { _, newValue in
            applyColor(newValue)
            dismiss()
        }
    }

    // MARK: - 自定义颜色

    private var customColorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义颜色")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ColorPicker(
                "自定义颜色",
                selection: Binding(
                    get: { customColor },
                    set: { newColor in
                        customColor = newColor
                        applyColor(newColor.hexString)
                    }
                ),
                supportsOpacity: false
            )
        }
    }

    // MARK: - 持久化

    private func applyColor(_ hex: String) {
        course.colorHex = hex
        CourseService(modelContext: modelContext).updateCourse(course)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = MockDataGenerator.previewContainer()
    let context = container.mainContext
    let course = (try? context.fetch(FetchDescriptor<Course>()))?.first

    return Group {
        if let course {
            CourseColorSheet(course: course)
                .modelContainer(container)
        } else {
            Text("No data")
        }
    }
}
#endif
