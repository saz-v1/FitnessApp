import SwiftUI

struct WorkoutLogView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showingAddWorkout = false
    @State private var showingInsights = false
    @State private var showingTargetedWorkout = false
    @State private var selectedWorkout: WorkoutRecord?
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Overview
                    HStack(spacing: 20) {
                        // Total Workouts Card
                        WorkoutStatCard(
                            title: "Total Workouts",
                            value: "\(userManager.user.workoutHistory.count)",
                            icon: "figure.run",
                            color: .blue
                        )
                        
                        // This Week Card
                        WorkoutStatCard(
                            title: "This Week",
                            value: "\(workoutsThisWeek)",
                            icon: "calendar",
                            color: .green
                        )
                        
                        // Streak Card
                        WorkoutStatCard(
                            title: "Current Streak",
                            value: "\(currentStreak)",
                            icon: "flame.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Workout History
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Workout History")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        ForEach(groupedWorkouts.keys.sorted(by: >), id: \.self) { date in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(formatDate(date))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                ForEach(groupedWorkouts[date] ?? []) { workout in
                                    WorkoutCard(workout: workout, isEditing: isEditing) {
                                        if isEditing {
                                            userManager.deleteWorkout(workout)
                                        } else {
                                            selectedWorkout = workout
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
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
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            NavigationView {
                WorkoutDetailView(workout: workout)
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
    }
    
    private var groupedWorkouts: [Date: [WorkoutRecord]] {
        Dictionary(grouping: userManager.user.workoutHistory) { workout in
            Calendar.current.startOfDay(for: workout.date)
        }
    }
    
    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        return userManager.user.workoutHistory.filter { workout in
            workout.date >= startOfWeek && workout.date <= today
        }.count
    }
    
    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        while true {
            let hasWorkout = userManager.user.workoutHistory.contains { workout in
                calendar.isDate(workout.date, inSameDayAs: currentDate)
            }
            
            if hasWorkout {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct WorkoutStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WorkoutCard: View {
    let workout: WorkoutRecord
    let isEditing: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
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
            
            if isEditing {
                Button(action: onTap) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.body)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onTap()
            }
            onTap()
        }
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