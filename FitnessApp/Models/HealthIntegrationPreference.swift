import Foundation

/// Invalidates pending Apple Health work when the user changes their connection preference.
@MainActor
final class HealthIntegrationPreference {
    static let shared = HealthIntegrationPreference()
    private let defaults: UserDefaults
    private var revision: UInt = 0

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isEnabled: Bool { defaults.bool(forKey: "healthIntegrationEnabled") }

    func invalidate() { revision &+= 1 }

    func accessToken() throws -> UInt {
        try validate(revision)
        return revision
    }

    func validate(_ token: UInt) throws {
        guard isEnabled, token == revision, !Task.isCancelled else { throw CancellationError() }
    }
}
