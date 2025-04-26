import SwiftUI

struct HealthDataView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Today's Summary
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today's Summary")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: columns, spacing: 20) {
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
                            color: .orange
                        )
                        
                        // Heart Rate Card
                        HealthDataCard(
                            title: "Heart Rate",
                            value: String(format: "%.0f", healthKitManager.heartRate),
                            subtitle: "bpm",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        // Sleep Card
                        HealthDataCard(
                            title: "Sleep",
                            value: String(format: "%.1f", healthKitManager.sleepHours),
                            subtitle: "hours",
                            icon: "bed.double.fill",
                            color: .blue
                        )
                        
                        // Stand Hours Card
                        HealthDataCard(
                            title: "Stand Hours",
                            value: String(format: "%.0f", healthKitManager.standHours),
                            subtitle: "hours",
                            icon: "figure.stand",
                            color: .purple
                        )
                        
                        // Exercise Minutes Card
                        HealthDataCard(
                            title: "Exercise",
                            value: String(format: "%.0f", healthKitManager.exerciseMinutes),
                            subtitle: "minutes",
                            icon: "figure.run",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 24)
        }
        .navigationTitle("Health Data")
        .task {
            await healthKitManager.fetchTodaysHealthData()
        }
    }
}

struct HealthDataCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon at the top
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            // Title
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Value and subtitle
            VStack(spacing: 8) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

#Preview {
    NavigationView {
        HealthDataView()
    }
} 