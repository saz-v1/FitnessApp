import SwiftUI

struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    @FocusState private var field: Field?
    @State private var workoutType: WorkoutRecord.WorkoutType = .cardio
    @State private var duration = 30.0
    @State private var intensity: WorkoutRecord.Intensity = .moderate
    @State private var caloriesBurned = ""
    @State private var notes = ""
    @State private var exercises: [WorkoutRecord.Exercise] = []
    @State private var showingAddExercise = false
    @State private var workoutDate = Date()
    @State private var errorMessage: String?
    private enum Field { case calories, notes }

    private var valid: Bool {
        (caloriesBurned.isEmpty || Int(caloriesBurned).map { (0...10000).contains($0) } == true) &&
        notes.count <= 4000 && duration.isFinite && (1...180).contains(duration) && workoutDate <= Date()
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        IconBadge(icon: workoutType.symbol)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Every session counts").font(.headline)
                            Text("Capture the basics. Add details if you like.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                }
                Section("Session") {
                    DatePicker("Date & time", selection: $workoutDate, in: ...Date())
                    Picker("Type", selection: $workoutType) {
                        ForEach(WorkoutRecord.WorkoutType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Intensity", selection: $intensity) {
                        ForEach(WorkoutRecord.Intensity.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Duration & energy") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text("\(Int(duration)) min").font(.headline).monospacedDigit().foregroundStyle(AppTheme.accent)
                        }
                        Slider(value: $duration, in: 1...180, step: 1).accessibilityLabel("Duration in minutes")
                    }.padding(.vertical, 8)
                    HStack {
                        Text("Energy")
                        Spacer()
                        TextField("Optional", text: $caloriesBurned).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).focused($field, equals: .calories)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                }
                Section {
                    if exercises.isEmpty { Text("You can log a session without individual exercises.").font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(exercises) { exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name).font(.headline)
                            if let sets = exercise.sets, let reps = exercise.reps {
                                Text("\(sets) sets × \(reps) reps").font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let weight = exercise.weight {
                                Text("\(userManager.displayWeight(weight).formatted(.number.precision(.fractionLength(0...1)))) \(userManager.weightUnit)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }.onDelete { exercises.remove(atOffsets: $0) }
                    Button { showingAddExercise = true } label: { Label("Add exercise", systemImage: "plus.circle") }
                } header: { Text("Exercises") } footer: { Text("Swipe an exercise to remove it before saving.") }
                Section("Notes") {
                    TextField("How did it feel? (optional)", text: $notes, axis: .vertical).lineLimit(3...6).focused($field, equals: .notes)
                }
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
            }
            .appForm().navigationTitle("Add Workout").navigationBarTitleDisplayMode(.inline).appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        field = nil
                        let record = WorkoutRecord(date: workoutDate, type: workoutType, duration: duration * 60,
                            intensity: intensity, exercises: exercises.isEmpty ? nil : exercises,
                            caloriesBurned: Int(caloriesBurned), notes: notes.isEmpty ? nil : notes)
                        guard userManager.updateUser({ $0.workoutHistory.append(record) }) else {
                            errorMessage = userManager.persistenceError ?? "Your workout could not be saved."; return
                        }
                        dismiss()
                    }.disabled(!valid).accessibilityIdentifier("save-workout")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { field = nil } }
            }
            .sheet(isPresented: $showingAddExercise) { AddExerciseSheet(exercises: $exercises) }
        }.presentationDragIndicator(.visible)
    }
}

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject private var userManager: UserManager
    @Binding var exercises: [WorkoutRecord.Exercise]
    @FocusState private var field: Field?
    @State private var name = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var duration = ""
    private enum Field { case name, sets, reps, weight, duration }

    private var weightInKg: Double? {
        LocalizedDecimal.parse(weight, locale: locale).map { userManager.user.usesMetric ? $0 : $0 * 0.45359237 }
    }
    private var durationInMinutes: Double? { LocalizedDecimal.parse(duration, locale: locale) }
    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 200 &&
        validInteger(sets, maximum: 1000) && validInteger(reps, maximum: 10000) && sets.isEmpty == reps.isEmpty &&
        (weight.isEmpty || weightInKg.map { $0.isFinite && (0.001...2000).contains($0) } == true) &&
        (duration.isEmpty || durationInMinutes.map { (0.01...1440).contains($0) } == true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $name).focused($field, equals: .name)
                }
                Section {
                    input("Sets", text: $sets, field: .sets, unit: nil, decimal: false)
                    input("Reps", text: $reps, field: .reps, unit: nil, decimal: false)
                } header: { Text("Sets & reps") } footer: { Text("Enter both, or leave both blank.") }
                Section("Optional details") {
                    input("Weight", text: $weight, field: .weight, unit: userManager.weightUnit, decimal: true)
                    input("Duration", text: $duration, field: .duration, unit: "min", decimal: true)
                }
            }
            .appForm().navigationTitle("Add Exercise").navigationBarTitleDisplayMode(.inline).appScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        exercises.append(WorkoutRecord.Exercise(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            sets: Int(sets), reps: Int(reps), weight: weightInKg,
                            duration: durationInMinutes.map { $0 * 60 }))
                        dismiss()
                    }.disabled(!valid)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { field = nil } }
            }
        }
    }
    private func input(_ title: String, text: Binding<String>, field: Field, unit: String?, decimal: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Optional", text: text).keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing).focused($field, equals: field)
            if let unit { Text(unit).foregroundStyle(.secondary) }
        }
    }
    private func validInteger(_ text: String, maximum: Int) -> Bool {
        text.isEmpty || Int(text).map { (1...maximum).contains($0) } == true
    }
}
