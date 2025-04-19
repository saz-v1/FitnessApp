import SwiftUI

struct WorkoutLogView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showingAddWorkout = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupedWorkouts.keys.sorted(by: >), id: \.self) { date in
                    Section(header: Text(formatDate(date))) {
                        ForEach(groupedWorkouts[date] ?? []) { workout in
                            WorkoutRow(workout: workout)
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
                    Button(action: { showingAddWorkout = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutSheet()
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
                
                if let notes = workout.notes {
                    Spacer()
                    Text(notes)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkoutLogView()
        .environmentObject(UserManager())
} 