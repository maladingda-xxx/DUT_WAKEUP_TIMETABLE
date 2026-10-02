//
//  CourseColorSwatches.swift
//  wake-up-timeTable
//

import SwiftUI

/// 预设课程颜色色板网格。选中项带描边与对勾；对勾颜色按底色亮度自动切换黑白。
/// 复用于「长按选色 Sheet」与「课程编辑页」。
struct CourseColorSwatches: View {
    @Binding var selection: String
    var columns: Int = 5

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(Constants.courseColorPalette, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    swatch(hex)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func swatch(_ hex: String) -> some View {
        let color = Color(hex: hex)
        let isSelected = selection == hex
        return ZStack {
            Circle()
                .fill(color)
                .frame(width: 44, height: 44)

            if isSelected {
                Circle()
                    .strokeBorder(.primary, lineWidth: 2.5)
                    .frame(width: 46, height: 46)

                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color.isLight ? .black : .white)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    CourseColorSwatches(selection: .constant("#4A90D9"))
        .padding()
}
#endif
