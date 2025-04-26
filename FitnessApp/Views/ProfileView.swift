import SwiftUI

/// A view that displays and manages the user's profile information, including measurements,
/// personal details, goals, and HealthKit integration settings.
struct ProfileView: View {
    // MARK: - Properties
    
    /// Reference to the user manager for accessing and modifying user data
    @EnvironmentObject var userManager: UserManager
    
    /// Tracks which text field is currently focused for keyboard management
    @FocusState private var focusedField: Field?
    
    /// Manages HealthKit authorization and data access
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    /// Service for syncing data with HealthKit
    @StateObject private var healthKitService = HealthKitService.shared
    
    /// Enum defining the focusable fields in the profile form
    enum Field {
        case height, weight, goalWeight, age
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                notificationsSection
                measurementsSection
                personalSection
                goalsSection
                calorieTargetSection
                syncSection
            }
            .navigationTitle("Profile")
            .onChange(of: userManager.user) { _, _ in
                userManager.saveUser()
            }
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    /// Section for managing app notifications
    private var notificationsSection: some View {
        Section {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("Notifications")
                }
            }
        } header: {
            Text("App Settings")
        } footer: {
            Text("Manage your notification preferences to stay on track with your fitness goals.")
        }
    }
    
    /// Section containing user's height and weight measurements with unit system toggle
    private var measurementsSection: some View {
        Section("Measurements") {
            Toggle("Use Metric System", isOn: Binding(
                get: { userManager.user.usesMetric },
                set: { _ in userManager.toggleUnits() }
            ))
            
            HStack {
                Text("Height")
                Spacer()
                TextField("Height", value: $userManager.user.height, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .height)
                    .frame(width: 80)
                Text(userManager.heightUnit)
            }
            
            HStack {
                Text("Weight")
                Spacer()
                TextField("Weight", value: $userManager.user.weight, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .frame(width: 80)
                Text(userManager.weightUnit)
            }
        }
    }
    
    /// Section containing personal information including gender, age, and activity level
    private var personalSection: some View {
        Section("Personal") {
            Picker("Gender", selection: $userManager.user.gender) {
                ForEach(User.Gender.allCases) { gender in
                    Text(gender.rawValue)
                        .tag(gender)
                }
            }
            .pickerStyle(.menu)
            
            HStack {
                Text("Age")
                Spacer()
                TextField("Age", value: $userManager.user.age, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .age)
                    .frame(width: 80)
                Text("years")
            }
            
            NavigationLink {
                List(User.ActivityLevel.allCases) { level in
                    Button {
                        userManager.user.activityLevel = level
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(level.rawValue)
                                    .foregroundColor(.primary)
                                Text(getActivityLevelDescription(level))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if userManager.user.activityLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .navigationTitle("Activity Level")
            } label: {
                HStack {
                    Text("Activity Level")
                    Spacer()
                    Text(userManager.user.activityLevel.rawValue)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    /// Section for setting weight goals and displaying calorie recommendations
    private var goalsSection: some View {
        Section("Goals") {
            HStack {
                Text("Goal Weight")
                Spacer()
                TextField("Goal Weight", value: $userManager.user.goalWeight, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .goalWeight)
                    .frame(width: 80)
                Text(userManager.weightUnit)
            }
            
            if let weeklyTarget = userManager.calculateWeeklyCalorieTarget() {
                Text("Suggested daily calories: \(Int(weeklyTarget)) kcal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Section displaying the calculated daily calorie target based on user's goals
    private var calorieTargetSection: some View {
        Section("Daily Calorie Target") {
            Text("\(Int(userManager.calculateDailyCalories())) kcal")
                .bold()
        }
    }
    
    /// Section for managing HealthKit integration and data synchronization
    private var syncSection: some View {
        Section {
            Button(action: {
                Task {
                    await healthKitService.syncWithHealthKit()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync with Health")
                    Spacer()
                    if healthKitService.isSyncing {
                        ProgressView()
                    }
                }
            }
            .disabled(healthKitService.isSyncing)
            
            if let lastSync = healthKitService.lastSyncDate {
                Text("Last synced: \(lastSync.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let error = healthKitService.syncError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Text("Health Integration")
        } footer: {
            Text("Sync your weight data with Apple Health to keep your records up to date.")
        }
    }
}

// MARK: - Helper Functions

/// Returns a descriptive text for each activity level
/// - Parameter level: The activity level to get the description for
/// - Returns: A string describing the activity level
private func getActivityLevelDescription(_ level: User.ActivityLevel) -> String {
    switch level {
    case .sedentary:
        return "Daily activities only"
    case .lightlyActive:
        return "Light exercise 1-3 times/week"
    case .moderatelyActive:
        return "Moderate exercise 3-5 times/week"
    case .veryActive:
        return "Hard exercise 6-7 times/week"
    case .extraActive:
        return "Very hard exercise & physical job"
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserManager())
} 
