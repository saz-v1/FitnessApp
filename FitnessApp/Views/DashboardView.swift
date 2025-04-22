import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showingBMIDetail = false
    @State private var showingCalorieDetail = false
    @State private var showingWeightDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Add this new section
                    NavigationLink {
                        HealthDataView()
                    } label: {
                        HealthDataSummaryCard()
                    }
                    .buttonStyle(.plain)
                    
                    // Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "BMI",
                            value: String(format: "%.1f", userManager.calculateBMI()),
                            icon: "figure.arms.open"
                        ) {
                            showingBMIDetail = true
                        }
                        
                        StatCard(
                            title: "Daily Calories",
                            value: String(format: "%.0f", userManager.calculateDailyCalories()),
                            icon: "flame.fill"
                        ) {
                            showingCalorieDetail = true
                        }
                    }
                    .padding(.horizontal)
                    
                    // Weight Chart
                    Button(action: { showingWeightDetail = true }) {
                        WeightChartView()
                            .frame(height: 200)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Calorie Chart
                    Button(action: { showingCalorieDetail = true }) {
                        CalorieChartView()
                            .frame(height: 200)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Recent Workouts
                    RecentWorkoutsView()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingBMIDetail) {
                NavigationView {
                    BMIDetailView()
                }
            }
            .sheet(isPresented: $showingCalorieDetail) {
                NavigationView {
                    CalorieDetailView()
                }
            }
            .sheet(isPresented: $showingWeightDetail) {
                NavigationView {
                    WeightDetailView()
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.green)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct HealthDataSummaryCard: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundColor(.green)
                
                Text("Today's Activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                // Steps
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.green)
                    Text("\(healthKitManager.steps)")
                        .font(.title2)
                        .bold()
                    Text("steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Calories
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.green)
                    Text(String(format: "%.0f", healthKitManager.activeEnergy))
                        .font(.title2)
                        .bold()
                    Text("kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .task {
            await healthKitManager.fetchTodaysHealthData()
        }
    }
} 