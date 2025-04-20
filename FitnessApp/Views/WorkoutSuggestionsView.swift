import SwiftUI

struct WorkoutSuggestionsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var suggestionService = WorkoutSuggestionService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var suggestions: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Suggestion Type", selection: $selectedTab) {
                    Text("Quick Tips").tag(0)
                    Text("Exercise Guide").tag(1)
                    Text("12-Week Plan").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if isLoading {
                    ProgressView("Getting suggestions...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.red)
                        Button("Try Again") {
                            Task {
                                await loadSuggestions()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if !suggestions.isEmpty {
                    ScrollView {
                        Text(suggestions)
                            .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "No Suggestions Yet",
                        systemImage: "dumbbell",
                        description: Text("Tap the button below to get personalized workout suggestions")
                    )
                }
            }
            .navigationTitle("Workout Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadSuggestions()
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
            await loadSuggestions()
        }
    }
    
    private func loadSuggestions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            switch selectedTab {
            case 0:
                suggestions = try await suggestionService.getWorkoutSuggestions(for: userManager.user)
            case 1:
                suggestions = try await suggestionService.getExerciseSuggestions(for: .strength, user: userManager.user)
            case 2:
                suggestions = try await suggestionService.getWorkoutPlan(for: userManager.user)
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
    WorkoutSuggestionsView()
        .environmentObject(UserManager())
} 