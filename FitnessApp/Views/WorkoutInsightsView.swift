import SwiftUI

struct WorkoutInsightsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var analyticsService = WorkoutAnalyticsService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var insights: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Tab Selection
                Picker("View Type", selection: $selectedTab) {
                    Text("Insights").tag(0)
                    Text("Quick Workout").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if isLoading {
                    Spacer()
                    ProgressView("Analyzing your workouts...")
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
                                await loadContent()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    Spacer()
                } else if !insights.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(insights)
                                .padding()
                        }
                    }
                } else {
                    Spacer()
                    ContentUnavailableView(
                        selectedTab == 0 ? "No Insights Yet" : "No Workout Yet",
                        systemImage: selectedTab == 0 ? "chart.bar" : "figure.run",
                        description: Text(selectedTab == 0 ? 
                            "Tap refresh to analyze your workout patterns" :
                            "Tap refresh to get a quick workout suggestion")
                    )
                    Spacer()
                }
            }
            .navigationTitle(selectedTab == 0 ? "Workout Insights" : "Quick Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadContent()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
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
        .task {
            await loadContent()
        }
    }
    
    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        do {
            switch selectedTab {
            case 0:
                insights = try await analyticsService.getWorkoutInsights(for: userManager.user)
            case 1:
                insights = try await analyticsService.getQuickWorkoutSuggestion(for: userManager.user)
            default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    WorkoutInsightsView()
        .environmentObject(UserManager())
} 