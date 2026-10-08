import Foundation
import Testing
@testable import FitnessApp

struct NumericInputTests {
    @Test func decimalPadAcceptsLocalSeparators() {
        #expect(LocalizedDecimal.parse("12.5", locale: Locale(identifier: "en_GB")) == 12.5)
        #expect(LocalizedDecimal.parse("12,5", locale: Locale(identifier: "fr_FR")) == 12.5)
        #expect(LocalizedDecimal.parse(" 12,5 ", locale: Locale(identifier: "de_DE")) == 12.5)
    }

    @Test func malformedOrAmbiguousDecimalInputIsRejected() {
        let locale = Locale(identifier: "en_GB")
        for input in ["", ".", "12x", "1,000", "12.3.4", "NaN", "Infinity", "1e3", "-2"] {
            #expect(LocalizedDecimal.parse(input, locale: locale) == nil)
        }
        #expect(LocalizedDecimal.parse("12.5", locale: Locale(identifier: "fr_FR")) == nil)
    }
}
