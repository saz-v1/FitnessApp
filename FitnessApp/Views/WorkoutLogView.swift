import SwiftUI

struct WorkoutLogView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showingAddWorkout = false
    @State private var showingInsights = false
    @State private var showingQuickWorkout = false
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
                            
                            Button(action: { showingQuickWorkout = true }) {
                                Label("Quick Workout", systemImage: "figure.run")
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
            .sheet(isPresented: $showingQuickWorkout) {
                QuickWorkoutView()
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
        return Dictionary(grouping: userManager.user.workoutHistory) { workout in
            calendar.startOfDay(for: workout.date)
        }
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

#Preview {
    WorkoutLogView()
        .environmentObject(UserManager())
} 