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
        NavigationView {
            VStack(spacing: 16) {
                // Focus Area Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Focus Area:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(commonFocusAreas, id: \.self) { area in
                                Button(action: {
                                    focusArea = area
                                }) {
                                    Text(area)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(focusArea == area ? Color.green : Color.gray.opacity(0.2))
                                        .foregroundColor(focusArea == area ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                
                if isLoading {
                    Spacer()
                    ProgressView("Generating targeted workout...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.red)
                        Button("Try Again") {
                            Task {
                                await generateWorkout()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    Spacer()
                } else if !workout.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(workout)
                                .padding()
                        }
                    }
                } else {
                    Spacer()
                    ContentUnavailableView(
                        "No Targeted Workout Yet",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Select a focus area and tap generate to get a targeted workout")
                    )
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
                    }
                    .disabled(isLoading || focusArea.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateWorkout() async {
        guard !focusArea.isEmpty else {
            errorMessage = "Please select a focus area"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            workout = try await analyticsService.getTargetedWorkoutSuggestion(for: userManager.user, focusArea: focusArea)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    TargetedWorkoutView()
        .environmentObject(UserManager())
} 