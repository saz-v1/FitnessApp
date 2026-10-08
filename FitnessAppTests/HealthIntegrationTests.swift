import Foundation
import Testing
@testable import FitnessApp

@MainActor
struct HealthIntegrationTests {
    @Test func appleHealthAccessRequiresAnExplicitConnection() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let preference = HealthIntegrationPreference(defaults: defaults)
        #expect(!preference.isEnabled)
        #expect(throws: CancellationError.self) { try preference.accessToken() }
        defaults.set(true, forKey: "healthIntegrationEnabled")
        #expect(throws: Never.self) { try preference.accessToken() }
    }

    @Test func disconnectRejectsAnAlreadyStartedHealthRead() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "healthIntegrationEnabled")
        let preference = HealthIntegrationPreference(defaults: defaults)
        let token = try preference.accessToken()
        defaults.set(false, forKey: "healthIntegrationEnabled")
        #expect(throws: CancellationError.self) { try preference.validate(token) }
    }

    @Test func reconnectDoesNotReviveAnOldHealthRead() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(true, forKey: "healthIntegrationEnabled")
        let preference = HealthIntegrationPreference(defaults: defaults)
        let oldToken = try preference.accessToken()
        defaults.set(false, forKey: "healthIntegrationEnabled")
        preference.invalidate()
        defaults.set(true, forKey: "healthIntegrationEnabled")
        #expect(throws: CancellationError.self) { try preference.validate(oldToken) }
        let freshToken = try preference.accessToken()
        #expect(throws: Never.self) { try preference.validate(freshToken) }
    }

    @Test func invalidHealthReadingsCannotCrashIntegerLabels() {
        for invalid in [Double.nan, .infinity, -.infinity, -1, Double.greatestFiniteMagnitude] {
            #expect(HealthKitManager.sanitizedValue(invalid, maximum: 100_000) == 0)
        }
        #expect(HealthKitManager.sanitizedValue(450.5, maximum: 100_000) == 450.5)
        #expect(HealthKitManager.sanitizedValue(25, maximum: 24) == 0)
    }
}
