import SwiftUI

struct QuickWorkoutView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var analyticsService = WorkoutAnalyticsService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var workout: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if isLoading {
                    Spacer()
                    ProgressView("Generating quick workout...")
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
                        "No Quick Workout Yet",
                        systemImage: "figure.run",
                        description: Text("Tap generate to get a quick workout suggestion")
                    )
                    Spacer()
                }
            }
            .navigationTitle("Quick Workout")
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
                    .disabled(isLoading)
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
        isLoading = true
        errorMessage = nil
        
        do {
            workout = try await analyticsService.getQuickWorkoutSuggestion(for: userManager.user)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    QuickWorkoutView()
        .environmentObject(UserManager())
} 