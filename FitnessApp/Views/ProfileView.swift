import SwiftUI

/// A view that displays and manages the user's profile information, including measurements,
/// personal details, goals, and HealthKit integration settings.
struct ProfileView: View {
    // MARK: - Properties
    
    /// Reference to the user manager for accessing and modifying user data
    @EnvironmentObject var userManager: UserManager
    
    /// Tracks which text field is currently focused for keyboard management
    @FocusState private var focusedField: Field?
    @State private var draft = User(height: 170, weight: 70, age: 25, gender: .other, usesMetric: true,
        activityLevel: .moderatelyActive, weightHistory: [], workoutHistory: [], calorieHistory: [])
    @AppStorage("healthIntegrationEnabled") private var healthIntegrationEnabled = false
    @State private var isLoaded = false
    @State private var savedMessage: String?
    
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
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        IconBadge(icon: "person.crop.circle")
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Make it yours").font(.title3.weight(.bold))
                            Text("Your details help shape your daily estimates.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                }.listRowBackground(AppTheme.surface)
                if isLoaded && !draft.hasValidMeasurements {
                    Text("Enter valid height, weight, goal weight and age before saving.").font(.caption).foregroundColor(.red)
                }
                measurementsSection
                personalSection
                goalsSection
                calorieTargetSection
                syncSection
                notificationsSection
                privacySection
                if let error = userManager.persistenceError {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .appForm()
            .safeAreaInset(edge: .bottom) {
                if let savedMessage {
                    Label(savedMessage, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                        .padding(14).frame(maxWidth: .infinity)
                        .background(AppTheme.softAccent)
                }
            }
            .navigationTitle("Profile")
            .appScreen()
            .onAppear {
                if !isLoaded { draft = userManager.user; isLoaded = true }
            }
            .onChange(of: draft) { _, _ in
                if !draft.hasSameProfile(as: userManager.user) { savedMessage = nil }
            }
            .onChange(of: userManager.user) { old, new in
                if draft.hasSameProfile(as: old) {
                    draft = new
                } else {
                    draft.weightHistory = new.weightHistory
                    draft.workoutHistory = new.workoutHistory
                    draft.calorieHistory = new.calorieHistory
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        focusedField = nil
                        if userManager.updateProfile(draft) {
                            draft = userManager.user
                            savedMessage = "Profile saved."
                        }
                    }
                    .disabled(!draft.hasValidMeasurements)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func measurementBinding(_ keyPath: WritableKeyPath<User, Double>) -> Binding<Double> {
        Binding(get: { draft[keyPath: keyPath] }, set: { value in
            draft[keyPath: keyPath] = value
        })
    }

    private var privacySection: some View {
        Section("Privacy & Health Information") {
            Text("Your journal stays on this device. No account or internet connection is needed.")
                .font(.caption).foregroundColor(.secondary)
            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
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
            Picker("Units", selection: Binding(
                get: { draft.usesMetric },
                set: { value in if value != draft.usesMetric { draft.toggleUnits() } }
            )) {
                Text("Metric").tag(true)
                Text("Imperial").tag(false)
            }.pickerStyle(.segmented).accessibilityIdentifier("profile-units")
            
            HStack {
                Text("Height")
                Spacer()
                TextField("Height", value: measurementBinding(\.height), format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .height)
                    .frame(width: 80)
                Text(draft.usesMetric ? "cm" : "in").foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile-height-unit")
            }
            
            HStack {
                Text("Weight")
                Spacer()
                TextField("Weight", value: measurementBinding(\.weight), format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .frame(width: 80)
                Text(draft.usesMetric ? "kg" : "lbs").foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile-weight-unit")
            }
        }
    }
    
    /// Section containing personal information including gender, age, and activity level
    private var personalSection: some View {
        Section("Personal") {
            Picker("Gender", selection: $draft.gender) {
                ForEach(User.Gender.allCases) { gender in
                    Text(gender.rawValue)
                        .tag(gender)
                }
            }
            .pickerStyle(.menu)
            
            HStack {
                Text("Age")
                Spacer()
                TextField("Age", value: $draft.age, format: .number)
                    .accessibilityIdentifier("profile-age")
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .age)
                    .frame(width: 80)
                Text("years")
            }
            
            NavigationLink {
                List(User.ActivityLevel.allCases) { level in
                    Button {
                        draft.activityLevel = level
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
                            
                            if draft.activityLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                    }
                }
                .navigationTitle("Activity Level")
                .appForm()
            } label: {
                HStack {
                    Text("Activity Level")
                    Spacer()
                    Text(draft.activityLevel.rawValue)
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
                TextField("Optional", value: $draft.goalWeight, format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .goalWeight)
                    .frame(width: 80)
                Text(draft.usesMetric ? "kg" : "lbs").foregroundStyle(.secondary)
            }
            if draft.goalWeight != nil {
                Button("Remove weight goal", role: .destructive) { draft.goalWeight = nil }
            }
            
            if let weeklyTarget = userManager.calculateWeeklyCalorieTarget() {
                Text("Saved profile daily estimate: \(Int(weeklyTarget)) kcal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Section displaying the calculated daily calorie target based on user's goals
    private var calorieTargetSection: some View {
        Section("Saved Profile Calorie Estimate") {
            Label("\(Int(userManager.calculateDailyCalories())) kcal / day", systemImage: "flame")
                .font(.headline).foregroundStyle(AppTheme.accent)
        }
    }
    
    /// Section for managing HealthKit integration and data synchronization
    private var syncSection: some View {
        Section {
            Toggle("Connect Apple Health", isOn: $healthIntegrationEnabled)
                .onChange(of: healthIntegrationEnabled) { _, enabled in
                    if enabled { Task { await healthKitManager.fetchTodaysHealthData() } }
                }
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
            .disabled(healthKitService.isSyncing || !healthIntegrationEnabled)
            
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

private extension User {
    func hasSameProfile(as other: User) -> Bool {
        height == other.height && weight == other.weight && age == other.age &&
        gender == other.gender && usesMetric == other.usesMetric &&
        activityLevel == other.activityLevel && goalWeight == other.goalWeight
    }
}
