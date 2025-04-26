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
                    // Health Data Summary
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
                        // BMI Card
                        StatCard(
                            title: "BMI",
                            value: String(format: "%.1f", userManager.calculateBMI()),
                            icon: "figure.arms.open"
                        ) {
                            showingBMIDetail = true
                        }
                        
                        // Today's Calories Card
                        Button(action: { showingCalorieDetail = true }) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                    Text("Today's Calories")
                                        .font(.headline)
                                }
                                
                                // Today's intake and progress
                                VStack(alignment: .leading, spacing: 8) {
                                    let todayCalories = userManager.user.calorieHistory
                                        .filter { Calendar.current.isDateInToday($0.date) }
                                        .reduce(0) { $0 + $1.calories }
                                    
                                    let dailyGoal = userManager.calculateDailyCalories()
                                    let progress = min(todayCalories / dailyGoal, 1.0)
                                    let remaining = max(dailyGoal - todayCalories, 0)
                                    
                                    // Progress bar
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(Color(.systemGray5))
                                                .frame(height: 8)
                                                .cornerRadius(4)
                                            
                                            Rectangle()
                                                .fill(progress > 1.0 ? .orange : .green)
                                                .frame(width: geometry.size.width * progress, height: 8)
                                                .cornerRadius(4)
                                        }
                                    }
                                    .frame(height: 8)
                                    
                                    // Calorie numbers
                                    HStack(alignment: .bottom, spacing: 4) {
                                        Text("\(Int(todayCalories))")
                                            .font(.title2)
                                            .bold()
                                        Text("/ \(Int(dailyGoal))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("kcal")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Remaining calories
                                    Text("\(Int(remaining)) kcal remaining")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 120)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Weight Summary Card
                        Button(action: { showingWeightDetail = true }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "scalemass.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                    Text("Weight")
                                        .font(.headline)
                                }
                                
                                HStack(alignment: .bottom, spacing: 4) {
                                    Text(String(format: "%.1f", userManager.user.weight))
                                        .font(.title2)
                                        .bold()
                                    Text(userManager.user.usesMetric ? "kg" : "lbs")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let goalWeight = userManager.user.goalWeight {
                                    let difference = goalWeight - userManager.user.weight
                                    Text(difference > 0 ? "Need to gain" : "Need to lose")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    + Text(" \(String(format: "%.1f", abs(difference))) \(userManager.user.usesMetric ? "kg" : "lbs")")
                                        .font(.caption)
                                        .bold()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 120)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Calorie Summary Card
                        Button(action: { showingCalorieDetail = true }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                    Text("Weekly Summary")
                                        .font(.headline)
                                }
                                
                                // Weekly average and total
                                let calendar = Calendar.current
                                let today = Date()
                                let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
                                
                                let weeklyRecords = userManager.user.calorieHistory
                                    .filter { record in
                                        record.date >= weekStart && record.date <= today
                                    }
                                
                                let weeklyTotal = weeklyRecords.reduce(0) { $0 + $1.calories }
                                let weeklyAverage = weeklyTotal / max(Double(weeklyRecords.count), 1)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .bottom, spacing: 4) {
                                        Text(String(format: "%.0f", weeklyAverage))
                                            .font(.title2)
                                            .bold()
                                        Text("avg kcal/day")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text("\(weeklyRecords.count) days tracked")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let goalTarget = userManager.calculateWeeklyCalorieTarget() {
                                        let difference = weeklyAverage - goalTarget
                                        Text(difference > 0 ? "Above goal by" : "Below goal by")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        + Text(" \(Int(abs(difference))) kcal")
                                            .font(.caption)
                                            .bold()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 120)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
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
            .frame(height: 120)
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