//
//  ReminderSettings.swift
//  wake-up-timeTable
//

import Foundation

/// 课程提醒偏好设置（UserDefaults 持久化）
@Observable
final class ReminderSettings {

    // MARK: - Keys

    private enum Key: String {
        case isEnabled = "reminder.isEnabled"
        case minutesBefore = "reminder.minutesBefore"
    }

    // MARK: - Properties

    /// 是否启用上课提醒
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.isEnabled.rawValue) }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.isEnabled.rawValue)
        }
    }

    /// 所有可选提醒时长
    static let availableOptions: [Int] = [5, 10, 15]

    /// 提前多少分钟提醒（默认取 availableOptions 第一项）
    var minutesBefore: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: Key.minutesBefore.rawValue)
            let defaults = Self.availableOptions.first ?? 5
            return Self.availableOptions.contains(value) ? value : defaults
        }
        set {
            let valid = Self.availableOptions.contains(newValue) ? newValue : (Self.availableOptions.first ?? 5)
            UserDefaults.standard.set(valid, forKey: Key.minutesBefore.rawValue)
        }
    }

    /// 提醒偏移量（秒）
    var reminderOffset: TimeInterval {
        TimeInterval(minutesBefore * 60)
    }

    /// 描述文本
    var description: String {
        isEnabled ? "提前 \(minutesBefore) 分钟提醒" : "已关闭"
    }
}
