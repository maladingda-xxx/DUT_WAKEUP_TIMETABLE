//
//  SettingsViewModel.swift
//  wake-up-timeTable
//

import Foundation
import SwiftData

@Observable
final class SettingsViewModel {
    var currentSemester: Semester?
    var allSemesters: [Semester] = []
    var isLoading: Bool = false

    private let semesterService: SemesterServiceProtocol

    init(semesterService: SemesterServiceProtocol) {
        self.semesterService = semesterService
    }

    func loadSemesters() {
        isLoading = true
        defer { isLoading = false }
        allSemesters = semesterService.fetchAllSemesters()
        currentSemester = semesterService.fetchCurrentSemester()
    }
}
