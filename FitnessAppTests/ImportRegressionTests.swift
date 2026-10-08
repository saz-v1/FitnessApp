import Foundation
import Testing
@testable import FitnessApp

@MainActor
struct ImportRegressionTests {
    @Test func repeatedImportKeepsManualWeightAndDoesNotWriteAgain() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("user.json")
        let manager = UserManager(storageURL: url, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let imported = WeightRecord(weight: 71, date: Date().addingTimeInterval(-3600))
        #expect(manager.syncWeights([imported]))
        #expect(manager.updateUser { $0.weight = 73 })
        // Moving the file makes any attempted write fail. An idempotent import needs no write.
        let savedData = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        #expect(manager.syncWeights([imported, imported]))
        #expect(manager.user.weight == 73)
        #expect(manager.user.weightHistory == [imported])
        #expect(manager.persistenceError == nil)
        #expect(!savedData.isEmpty)
    }

    @Test func historicalAndFutureImportsDoNotReplaceLatestWeight() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = UserManager(storageURL: directory.appendingPathComponent("user.json"),
            defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let now = Date()
        #expect(manager.addWeight(73, date: now))
        #expect(manager.syncWeights([
            WeightRecord(weight: 65, date: now.addingTimeInterval(-86400)),
            WeightRecord(weight: 80, date: now.addingTimeInterval(86400))
        ]))
        #expect(manager.user.weight == 73)
        #expect(manager.user.weightHistory.count == 2)
    }
}
