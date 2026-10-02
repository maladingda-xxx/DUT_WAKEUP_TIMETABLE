//
//  SemesterService.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData
import WidgetKit

@Observable
final class SemesterService: SemesterServiceProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllSemesters() -> [Semester] {
        let descriptor = FetchDescriptor<Semester>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchCurrentSemester() -> Semester? {
        var descriptor = FetchDescriptor<Semester>(
            predicate: #Predicate { $0.isCurrent == true }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func addSemester(_ semester: Semester) {
        modelContext.insert(semester)
        save()
    }

    func updateSemester(_ semester: Semester) {
        save()
    }

    func deleteSemester(_ semester: Semester) {
        modelContext.delete(semester)
        save()
    }

    func setCurrentSemester(_ semester: Semester) {
        // 取消所有其他学期的 isCurrent 标记
        let allSemesters = fetchAllSemesters()
        for s in allSemesters where s.isCurrent {
            s.isCurrent = false
        }
        semester.isCurrent = true
        save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func save() {
        try? modelContext.save()
    }
}
