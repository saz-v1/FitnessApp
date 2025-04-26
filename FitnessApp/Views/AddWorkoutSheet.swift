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
    @State private var workoutDate = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Text("Add Workout")
                    .font(.headline)
                
                Spacer()
                
                Button("Add") {
                    let workout = WorkoutRecord(
                        id: UUID(),
                        date: workoutDate,
                        type: workoutType,
                        duration: duration * 60,
                        intensity: intensity,
                        exercises: exercises.isEmpty ? nil : exercises,
                        caloriesBurned: Int(caloriesBurned),
                        notes: notes.isEmpty ? nil : notes
                    )
                    userManager.user.workoutHistory.append(workout)
                    userManager.saveUser()
                    dismiss()
                }
                .bold()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            List {
                Section {
                    DatePicker("Date & Time", selection: $workoutDate)
                        .datePickerStyle(.compact)
                    
                    Picker("Type", selection: $workoutType) {
                        ForEach(WorkoutRecord.WorkoutType.allCases) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Picker("Intensity", selection: $intensity) {
                        ForEach(WorkoutRecord.Intensity.allCases) { intensity in
                            Text(intensity.rawValue)
                                .tag(intensity)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Workout Details")
                } footer: {
                    Text("Select the type and intensity of your workout")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text("\(Int(duration)) minutes")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $duration, in: 1...180, step: 1)
                            .tint(.blue)
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Text("Calories Burned")
                        Spacer()
                        TextField("Optional", text: $caloriesBurned)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                } header: {
                    Text("Duration & Calories")
                } footer: {
                    Text("Set the duration and calories burned during your workout")
                }
                
                Section {
                    if exercises.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("No exercises added")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(exercises) { exercise in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(exercise.name)
                                    .font(.headline)
                                
                                HStack(spacing: 16) {
                                    if let sets = exercise.sets, let reps = exercise.reps {
                                        Label("\(sets) sets × \(reps) reps", systemImage: "repeat")
                                    }
                                    
                                    if let weight = exercise.weight {
                                        Label("\(Int(weight)) kg", systemImage: "scalemass")
                                    }
                                    
                                    if let duration = exercise.duration {
                                        Label("\(Int(duration / 60)) min", systemImage: "clock")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { indices in
                            exercises.remove(atOffsets: indices)
                        }
                    }
                    
                    Button(action: {
                        showingAddExercise = true
                    }) {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                } header: {
                    Text("Exercises")
                } footer: {
                    Text("Add exercises to track your workout details")
                }
                
                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Add any additional notes about your workout")
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet(exercises: $exercises)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
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
                Section {
                    TextField("Exercise Name", text: $name)
                        .font(.body)
                } header: {
                    Text("Exercise Name")
                } footer: {
                    Text("Enter the name of the exercise")
                }
                
                Section {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Sets")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("0", text: $sets)
                                .keyboardType(.numberPad)
                                .font(.body)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Reps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("0", text: $reps)
                                .keyboardType(.numberPad)
                                .font(.body)
                        }
                    }
                } header: {
                    Text("Sets & Reps")
                } footer: {
                    Text("Enter the number of sets and reps")
                }
                
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Weight")
                } footer: {
                    Text("Enter the weight used for the exercise")
                }
                
                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("0", text: $duration)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("min")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Duration")
                } footer: {
                    Text("Enter the duration of the exercise in minutes")
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
                    .bold()
                }
            }
        }
    }
}

#Preview {
    AddWorkoutSheet()
        .environmentObject(UserManager())
} 