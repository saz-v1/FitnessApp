import Foundation

enum LocalizedDecimal {
    /// Decimal-pad input excludes grouping and requires the complete value to be valid.
    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        let allowed = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: separator))
        guard !input.isEmpty, input.rangeOfCharacter(from: allowed.inverted) == nil,
              input.rangeOfCharacter(from: .decimalDigits) != nil,
              input.components(separatedBy: separator).count <= 2,
              let value = try? Double(input, format: .number.locale(locale), lenient: false),
              value.isFinite else { return nil }
        return value
    }
}
