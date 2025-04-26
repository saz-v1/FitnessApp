import SwiftUI

struct WorkoutLogView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showingAddWorkout = false
    @State private var showingInsights = false
    @State private var showingTargetedWorkout = false
    @State private var selectedWorkout: WorkoutRecord?
    @State private var showingWorkoutDetail = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupedWorkouts.keys.sorted(by: >), id: \.self) { date in
                    Section(header: Text(formatDate(date))) {
                        ForEach(groupedWorkouts[date] ?? []) { workout in
                            WorkoutRow(workout: workout)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedWorkout = workout
                                    showingWorkoutDetail = true
                                }
                        }
                        .onDelete { indices in
                            indices.forEach { index in
                                if let workout = groupedWorkouts[date]?[index] {
                                    userManager.deleteWorkout(workout)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddWorkout = true }) {
                            Label("Add Workout", systemImage: "plus")
                        }
                        
                        Menu("Workout Tools") {
                            Button(action: { showingInsights = true }) {
                                Label("Workout Insights", systemImage: "chart.bar")
                            }
                            
                            Button(action: { showingTargetedWorkout = true }) {
                                Label("Targeted Workout", systemImage: "figure.strengthtraining.traditional")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutSheet()
            }
            .sheet(isPresented: $showingInsights) {
                WorkoutInsightsView()
            }
            .sheet(isPresented: $showingTargetedWorkout) {
                TargetedWorkoutView()
            }
            .sheet(isPresented: $showingWorkoutDetail) {
                if let workout = selectedWorkout {
                    WorkoutDetailView(workout: workout)
                }
            }
        }
    }
    
    private var groupedWorkouts: [Date: [WorkoutRecord]] {
        let calendar = Calendar.current
        let workouts = userManager.user.workoutHistory
        var grouped: [Date: [WorkoutRecord]] = [:]
        
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.date)
            grouped[day, default: []].append(workout)
        }
        
        return grouped
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
    
    private var calendar: Calendar {
        Calendar.current
    }
}

struct WorkoutRow: View {
    let workout: WorkoutRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.type.rawValue.capitalized)
                    .font(.headline)
                Spacer()
                Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "clock")
                Text("\(Int(workout.duration / 60)) minutes")
                
                Spacer()
                
                Image(systemName: "flame")
                    .foregroundColor(.orange)
                Text(workout.intensity.rawValue)
                    .foregroundColor(.secondary)
                
                if let calories = workout.caloriesBurned {
                    Spacer()
                    Image(systemName: "bolt")
                        .foregroundColor(.yellow)
                    Text("\(calories) cal")
                }
            }
            .font(.subheadline)
            
            if let exercises = workout.exercises, !exercises.isEmpty {
                Text("\(exercises.count) exercises")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let notes = workout.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct WorkoutDetailView: View {
    let workout: WorkoutRecord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Workout Details")) {
                    DetailRow(title: "Type", value: workout.type.rawValue)
                    DetailRow(title: "Date", value: workout.date.formatted(date: .long, time: .shortened))
                    DetailRow(title: "Duration", value: "\(Int(workout.duration / 60)) minutes")
                    DetailRow(title: "Intensity", value: workout.intensity.rawValue)
                    if let calories = workout.caloriesBurned {
                        DetailRow(title: "Calories Burned", value: "\(calories)")
                    }
                }
                
                if let exercises = workout.exercises, !exercises.isEmpty {
                    Section(header: Text("Exercises")) {
                        ForEach(exercises) { exercise in
                            VStack(alignment: .leading, spacing: 4) {
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
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if let notes = workout.notes, !notes.isEmpty {
                    Section(header: Text("Notes")) {
                        Text(notes)
                    }
                }
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct QuickWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: UserManager
    @State private var selectedType: WorkoutRecord.WorkoutType = .cardio
    @State private var duration: TimeInterval = 30 * 60 // 30 minutes
    @State private var intensity: WorkoutRecord.Intensity = .moderate
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Workout Type")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(WorkoutRecord.WorkoutType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                }
                
                Section(header: Text("Duration")) {
                    Picker("Duration", selection: $duration) {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(TimeInterval(minutes * 60))
                        }
                    }
                }
                
                Section(header: Text("Intensity")) {
                    Picker("Intensity", selection: $intensity) {
                        ForEach(WorkoutRecord.Intensity.allCases, id: \.self) { intensity in
                            Text(intensity.rawValue.capitalized).tag(intensity)
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextField("Add notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Quick Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let workout = WorkoutRecord(
                            type: selectedType,
                            duration: duration,
                            intensity: intensity,
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

#Preview {
    WorkoutLogView()
        .environmentObject(UserManager())
} 