import SwiftUI

struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: UserManager
    
    @State private var workoutType: WorkoutRecord.WorkoutType = .cardio
    @State private var duration: Double = 30
    @State private var intensity: WorkoutRecord.Intensity = .moderate
    @State private var caloriesBurned: String = ""
    @State private var notes: String = ""
    @State private var exercises: [WorkoutRecord.Exercise] = []
    @State private var showingAddExercise = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Workout Details")) {
                    Picker("Type", selection: $workoutType) {
                        ForEach(WorkoutRecord.WorkoutType.allCases) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }
                    
                    Picker("Intensity", selection: $intensity) {
                        ForEach(WorkoutRecord.Intensity.allCases) { intensity in
                            Text(intensity.rawValue)
                                .tag(intensity)
                        }
                    }
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(Int(duration)) minutes")
                    }
                    Slider(value: $duration, in: 1...180, step: 1)
                    
                    HStack {
                        Text("Calories Burned")
                        Spacer()
                        TextField("Optional", text: $caloriesBurned)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Exercises")) {
                    if exercises.isEmpty {
                        Text("No exercises added")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(exercises) { exercise in
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                    .font(.headline)
                                
                                HStack {
                                    if let sets = exercise.sets, let reps = exercise.reps {
                                        Text("\(sets) sets × \(reps) reps")
                                    }
                                    
                                    if let weight = exercise.weight {
                                        Text("\(Int(weight)) kg")
                                    }
                                    
                                    if let duration = exercise.duration {
                                        Text("\(Int(duration / 60)) min")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                        }
                        .onDelete { indices in
                            exercises.remove(atOffsets: indices)
                        }
                    }
                    
                    Button(action: {
                        showingAddExercise = true
                    }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let workout = WorkoutRecord(
                            id: UUID(),
                            date: Date(),
                            type: workoutType,
                            duration: duration * 60, // Convert to seconds
                            intensity: intensity,
                            exercises: exercises.isEmpty ? nil : exercises,
                            caloriesBurned: Int(caloriesBurned),
                            notes: notes.isEmpty ? nil : notes
                        )
                        userManager.user.workoutHistory.append(workout)
                        userManager.saveUser()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet(exercises: $exercises)
            }
        }
    }
}

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [WorkoutRecord.Exercise]
    
    @State private var name: String = ""
    @State private var sets: String = ""
    @State private var reps: String = ""
    @State private var weight: String = ""
    @State private var duration: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Exercise Name", text: $name)
                
                HStack {
                    TextField("Sets", text: $sets)
                        .keyboardType(.numberPad)
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    TextField("Weight (kg)", text: $weight)
                        .keyboardType(.decimalPad)
                }
                
                HStack {
                    TextField("Duration (minutes)", text: $duration)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let exercise = WorkoutRecord.Exercise(
                            name: name,
                            sets: Int(sets),
                            reps: Int(reps),
                            weight: Double(weight),
                            duration: duration.isEmpty ? nil : Double(duration)! * 60 // Convert to seconds
                        )
                        exercises.append(exercise)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddWorkoutSheet()
        .environmentObject(UserManager())
} 