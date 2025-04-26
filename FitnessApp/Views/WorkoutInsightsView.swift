import SwiftUI

struct WorkoutInsightsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var analyticsService = WorkoutAnalyticsService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var insights: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            if isLoading {
                Spacer()
                ProgressView("Analyzing your workouts...")
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
                            await loadInsights()
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.headline)
                    .frame(height: 44)
                }
                .padding(24)
                Spacer()
            } else if !insights.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(insights)
                            .font(.body)
                            .padding(20)
                    }
                }
            } else {
                Spacer()
                ContentUnavailableView(
                    "No Insights Yet",
                    systemImage: "chart.bar",
                    description: Text("Complete more workouts to get personalized insights")
                )
                .font(.headline)
                Spacer()
            }
        }
        .navigationTitle("Workout Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInsights()
        }
    }
    
    private func loadInsights() async {
        isLoading = true
        errorMessage = nil
        
        do {
            insights = try await analyticsService.getWorkoutInsights(for: userManager.user)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationView {
        WorkoutInsightsView()
            .environmentObject(UserManager())
    }
} 