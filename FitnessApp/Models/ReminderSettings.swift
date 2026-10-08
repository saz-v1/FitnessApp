import Foundation

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case meal, workout, weight
    var id: String {
        switch self {
        case .meal: return "foodLogReminder"
        case .workout: return "workoutReminder"
        case .weight: return "weightLogReminder"
        }
    }
    var preferenceKey: String {
        switch self {
        case .meal: return "foodReminderEnabled"
        case .workout: return "workoutReminderEnabled"
        case .weight: return "weightReminderEnabled"
        }
    }
    var title: String {
        switch self {
        case .meal: return "Log a meal"
        case .workout: return "Log a workout"
        case .weight: return "Log your weight"
        }
    }
    var symbol: String {
        switch self {
        case .meal: return "fork.knife"
        case .workout: return "figure.run"
        case .weight: return "scalemass"
        }
    }
    var defaultHour: Int { self == .meal ? 13 : (self == .workout ? 17 : 10) }
    var managedIdentifiers: [String] {
        [id, id + ".snooze"] + (1...7).map { id + ".day.\($0)" }
    }
    static func fromNotification(_ identifier: String) -> Self? {
        allCases.first { $0.managedIdentifiers.contains(identifier) }
    }
}

struct ReminderSettings: Codable, Equatable, Identifiable {
    let kind: ReminderKind
    var enabled: Bool
    var hour: Int
    var minute: Int
    /// Calendar weekday numbers: Sunday = 1. All seven days means a daily reminder.
    var weekdays: Set<Int>
    var id: ReminderKind { kind }
    var isValid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute) && !weekdays.isEmpty && weekdays.isSubset(of: Set(1...7))
    }
    init(kind: ReminderKind, enabled: Bool = false) {
        self.kind = kind; self.enabled = enabled; hour = kind.defaultHour; minute = 0
        weekdays = kind == .weight ? [2] : Set(1...7)
    }
    func date(calendar: Calendar = .current) -> Date {
        // A fixed day avoids DST making an otherwise valid time impossible to edit.
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: hour, minute: minute)) ?? Date()
    }
    var triggerComponents: [DateComponents] {
        if weekdays.count == 7 { return [DateComponents(hour: hour, minute: minute)] }
        return weekdays.sorted().map { DateComponents(hour: hour, minute: minute, weekday: $0) }
    }
    var requestIdentifiers: [String] {
        weekdays.count == 7 ? [kind.id] : weekdays.sorted().map { kind.id + ".day.\($0)" }
    }
}

enum ReminderStore {
    static let key = "reminderSchedulesV1"
    static func load(defaults: UserDefaults) -> [ReminderSettings] {
        let saved = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([ReminderSettings].self, from: $0) } ?? []
        return ReminderKind.allCases.map { kind in
            saved.first { $0.kind == kind && $0.isValid } ??
                ReminderSettings(kind: kind, enabled: defaults.bool(forKey: kind.preferenceKey))
        }
    }
    static func save(_ settings: [ReminderSettings], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
        for item in settings { defaults.set(item.enabled, forKey: item.kind.preferenceKey) }
    }
}
