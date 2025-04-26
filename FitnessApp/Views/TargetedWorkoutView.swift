import SwiftUI

struct TargetedWorkoutView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var analyticsService = WorkoutAnalyticsService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var workout: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var focusArea: String = ""
    
    // Common focus areas for quick selection
    private let commonFocusAreas = [
        "Chest", "Back", "Legs", "Shoulders", 
        "Arms", "Core", "Full Body", "Cardio",
        "Flexibility", "Strength", "Endurance"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Focus Area Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Focus Area:")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(commonFocusAreas, id: \.self) { area in
                            Button(action: {
                                focusArea = area
                            }) {
                                Text(area)
                                    .font(.headline)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(focusArea == area ? Color.green : Color.gray.opacity(0.2))
                                    .foregroundColor(focusArea == area ? .white : .primary)
                                    .cornerRadius(20)
                            }
                            .frame(height: 44)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
            
            if isLoading {
                Spacer()
                ProgressView("Generating targeted workout...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .font(.headline)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text(error)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.red)
                    Button("Try Again") {
                        Task {
                            await generateWorkout()
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.headline)
                    .frame(height: 44)
                }
                .padding(24)
                Spacer()
            } else if !workout.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(workout)
                            .font(.body)
                            .padding(20)
                    }
                }
            } else {
                Spacer()
                ContentUnavailableView(
                    "No Targeted Workout Yet",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Select a focus area and tap generate to get a targeted workout")
                )
                .font(.headline)
                Spacer()
            }
        }
        .navigationTitle("Targeted Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await generateWorkout()
                    }
                }) {
                    Text("Generate")
                        .font(.headline)
                        .bold()
                }
                .disabled(focusArea.isEmpty || isLoading)
                .frame(height: 44)
            }
        }
    }
    
    private func generateWorkout() async {
        guard !focusArea.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            workout = try await analyticsService.getTargetedWorkoutSuggestion(
                for: userManager.user,
                focusArea: focusArea
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationView {
        TargetedWorkoutView()
            .environmentObject(UserManager())
    }
} 