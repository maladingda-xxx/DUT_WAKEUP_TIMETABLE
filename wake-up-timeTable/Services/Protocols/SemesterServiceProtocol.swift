//
//  SemesterServiceProtocol.swift
//  wake-up-timeTable
//

import Foundation

protocol SemesterServiceProtocol {
    /// 获取所有学期
    func fetchAllSemesters() -> [Semester]

    /// 获取当前学期
    func fetchCurrentSemester() -> Semester?

    /// 添加学期
    func addSemester(_ semester: Semester)

    /// 更新学期
    func updateSemester(_ semester: Semester)

    /// 删除学期
    func deleteSemester(_ semester: Semester)

    /// 切换当前学期
    func setCurrentSemester(_ semester: Semester)
}
