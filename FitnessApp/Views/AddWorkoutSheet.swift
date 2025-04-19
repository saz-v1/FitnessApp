import SwiftUI

struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: UserManager
    
    @State private var workoutType: WorkoutRecord.WorkoutType = .cardio
    @State private var duration: Double = 30
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Picker("Type", selection: $workoutType) {
                    ForEach(WorkoutRecord.WorkoutType.allCases) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                
                HStack {
                    Text("Duration")
                    Spacer()
                    Text("\(Int(duration)) minutes")
                }
                Slider(value: $duration, in: 1...180, step: 1)
                
                TextField("Notes (optional)", text: $notes)
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
                            notes: notes.isEmpty ? nil : notes
                        )
                        userManager.user.workoutHistory.append(workout)
                        userManager.saveUser()
                        dismiss()
                    }
                }
            }
        }
    }
} 