import Foundation

struct ProfileEditor {
    var profile: User
    var height: String
    var weight: String
    var age: String
    var goal: String
    let locale: Locale

    init(user: User, locale: Locale = .current) {
        profile = user; self.locale = locale
        height = Self.text(user.height, locale: locale)
        weight = Self.text(user.weight, locale: locale)
        age = String(user.age)
        goal = user.goalWeight.map { Self.text($0, locale: locale) } ?? ""
    }
    private static func text(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2)))
    }
    private func number(_ text: String, original: Double) -> Double? {
        // Unedited fields retain their exact value despite rounded display formatting.
        text == Self.text(original, locale: locale) ? original : LocalizedDecimal.parse(text, locale: locale)
    }
    var candidate: User? {
        guard let height = number(height, original: profile.height),
              let weight = number(weight, original: profile.weight),
              let ageValue = LocalizedDecimal.parse(age, locale: locale),
              (1...120).contains(ageValue), ageValue.rounded() == ageValue else { return nil }
        var candidate = profile
        candidate.height = height; candidate.weight = weight; candidate.age = Int(ageValue)
        if goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { candidate.goalWeight = nil }
        else {
            guard let value = profile.goalWeight.map({ number(goal, original: $0) }) ??
                    LocalizedDecimal.parse(goal, locale: locale) else { return nil }
            candidate.goalWeight = value
        }
        return candidate.hasValidProfile ? candidate : nil
    }
    func hasChanges(comparedTo saved: User) -> Bool {
        candidate.map { !$0.hasSameProfile(as: saved) } ?? true
    }
    mutating func setMetric(_ metric: Bool) {
        guard var converted = candidate, converted.usesMetric != metric else { return }
        converted.toggleUnits()
        self = Self(user: converted, locale: locale)
    }
}
