import SwiftUI

struct HealthDataView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Today's Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Summary")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: columns, spacing: 16) {
                        // Steps Card
                        HealthDataCard(
                            title: "Steps",
                            value: healthKitManager.steps.formatted(),
                            subtitle: "Today",
                            icon: "figure.walk",
                            color: .green
                        )
                        
                        // Active Energy Card
                        HealthDataCard(
                            title: "Active Energy",
                            value: String(format: "%.0f", healthKitManager.activeEnergy),
                            subtitle: "kcal today",
                            icon: "flame.fill",
                            color: .green
                        )
                        
                        // Heart Rate Card
                        HealthDataCard(
                            title: "Heart Rate",
                            value: healthKitManager.heartRate > 0 
                                ? String(format: "%.0f", healthKitManager.heartRate)
                                : "No data",
                            subtitle: healthKitManager.heartRate > 0 
                                ? "BPM • \(formatTimestamp(healthKitManager.heartRateTimestamp))"
                                : "Check your Apple Watch",
                            icon: "heart.fill",
                            color: .green
                        )
                        
                        // Sleep Card
                        HealthDataCard(
                            title: "Sleep",
                            value: String(format: "%.1f", healthKitManager.sleepHours),
                            subtitle: "hours",
                            icon: "bed.double.fill",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Health Data")
        .task {
            await healthKitManager.fetchTodaysHealthData()
        }
    }
    
    private func formatTimestamp(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let now = Date()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

struct HealthDataCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon at the top
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            // Title
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Value and subtitle
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .bold()
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140) // Fixed height for consistency
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        // Make tap target at least 44x44 points
        .contentShape(Rectangle())
    }
}

// Preview provider for SwiftUI canvas
#Preview {
    NavigationView {
        HealthDataView()
    }
} 