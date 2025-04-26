import SwiftUI

struct WorkoutLogView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showingAddWorkout = false
    @State private var showingInsights = false
    @State private var showingTargetedWorkout = false
    @State private var selectedWorkout: WorkoutRecord?
    @State private var showingWorkoutDetail = false
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            workoutList
        }
    }
    
    private var workoutList: some View {
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
                    Button(action: { showingInsights = true }) {
                        Label("View Insights", systemImage: "chart.bar")
                    }
                    Button(action: { showingTargetedWorkout = true }) {
                        Label("Get Targeted Workout", systemImage: "figure.run")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddWorkout) {
            NavigationView {
                AddWorkoutSheet()
            }
        }
        .sheet(isPresented: $showingInsights) {
            NavigationView {
                WorkoutInsightsView()
            }
        }
        .sheet(isPresented: $showingTargetedWorkout) {
            NavigationView {
                TargetedWorkoutView()
            }
        }
        .sheet(isPresented: $showingWorkoutDetail, onDismiss: {
            selectedWorkout = nil
        }) {
            if let workout = selectedWorkout {
                NavigationView {
                    WorkoutDetailView(workout: workout)
                }
            }
        }
    }
    
    private var groupedWorkouts: [Date: [WorkoutRecord]] {
        Dictionary(grouping: userManager.user.workoutHistory) { workout in
            Calendar.current.startOfDay(for: workout.date)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct WorkoutRow: View {
    let workout: WorkoutRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.type.rawValue)
                    .font(.headline)
                
                Spacer()
                
                Text(formatDate(workout.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                Label(formatDuration(workout.duration), systemImage: "clock")
                    .foregroundColor(.secondary)
                
                if let calories = workout.caloriesBurned {
                    Label("\(Int(calories)) kcal", systemImage: "flame.fill")
                        .foregroundColor(.orange)
                }
                
                if let exercises = workout.exercises, !exercises.isEmpty {
                    Label("\(exercises.count) exercises", systemImage: "figure.run")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

struct WorkoutDetailView: View {
    let workout: WorkoutRecord
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: UserManager
    @State private var isEditing = false
    
    var body: some View {
        List {
            Section(header: Text("Workout Details")) {
                DetailRow(title: "Type", value: workout.type.rawValue)
                DetailRow(title: "Date", value: formatDate(workout.date))
                DetailRow(title: "Duration", value: formatDuration(workout.duration))
                DetailRow(title: "Intensity", value: workout.intensity.rawValue)
                if let calories = workout.caloriesBurned {
                    DetailRow(title: "Calories Burned", value: "\(Int(calories)) kcal")
                }
            }
            
            if let exercises = workout.exercises, !exercises.isEmpty {
                Section(header: Text("Exercises")) {
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
                                    Label(formatDuration(duration), systemImage: "clock")
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
                        .font(.body)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    userManager.deleteWorkout(workout)
                    dismiss()
                } label: {
                    Label("Delete Workout", systemImage: "trash")
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkoutLogView()
        .environmentObject(UserManager())
} 