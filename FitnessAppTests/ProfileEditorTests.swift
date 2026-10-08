import Foundation
import Testing
@testable import FitnessApp

struct ProfileEditorTests {
    private var user: User {
        User(height: 173.123456789, weight: 72.123456789, age: 25, gender: .other,
            usesMetric: true, activityLevel: .moderatelyActive, weightHistory: [], workoutHistory: [], calorieHistory: [])
    }
    @Test func untouchedFieldsPreserveExactValuesAcrossUnits() {
        var editor = ProfileEditor(user: user)
        #expect(editor.candidate?.height == user.height && editor.candidate?.weight == user.weight)
        #expect(!editor.hasChanges(comparedTo: user))
        for _ in 0..<100 { editor.setMetric(!editor.profile.usesMetric) }
        #expect(abs((editor.candidate?.weight ?? 0) - user.weight) < 0.000001)
    }
    @Test func invalidOrIncompleteInputCannotSaveOldValues() {
        var editor = ProfileEditor(user: user)
        editor.height = ""
        #expect(editor.candidate == nil)
        editor.height = "173"; editor.age = "25x"
        #expect(editor.candidate == nil)
        editor.age = "25"; editor.goal = "not a number"
        #expect(editor.candidate == nil)
        editor.goal = ""; editor.weight = "0"
        #expect(editor.candidate == nil)
    }
    @Test func localizedEditsAndRemovingGoalValidate() {
        var original = user; original.goalWeight = 70
        var editor = ProfileEditor(user: original, locale: Locale(identifier: "fr_FR"))
        editor.weight = "71,5"; editor.goal = ""
        #expect(editor.candidate?.weight == 71.5)
        #expect(editor.candidate?.goalWeight == nil)
        #expect(editor.hasChanges(comparedTo: original))
    }
}
