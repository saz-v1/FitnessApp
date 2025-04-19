import SwiftUI

struct RecentWorkoutsView: View {
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
            
            if userManager.user.workoutHistory.isEmpty {
                Text("No workouts logged yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(Array(userManager.user.workoutHistory
                    .sorted(by: { $0.date > $1.date })
                    .prefix(3))) { workout in
                    WorkoutRow(workout: workout)
                }
            }
        }
    }
}

#Preview {
    RecentWorkoutsView()
        .environmentObject(UserManager())
        .padding()
} 