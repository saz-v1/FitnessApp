import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingBMIDetail = false
    @State private var showingCalorieDetail = false
    @State private var showingWeightDetail = false
    @State private var showingAddMeal = false
    @State private var showingAddWeight = false

    var body: some View {
        let now = Date()
        let calories = FitnessMetrics.calorieSummary(records: userManager.user.calorieHistory, days: 7, now: now)
        let todaysCalories = calories.days.last?.calories ?? 0
        let dailyGoal = userManager.calculateWeeklyCalorieTarget() ?? userManager.calculateDailyCalories()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 5) {
                        Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.accent)
                        Text("A little progress, every day.").font(.title2.weight(.semibold))
                    }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    calorieOverview(todaysCalories: todaysCalories, dailyGoal: dailyGoal)
                    quickActions
                    NavigationLink { HealthDataView() } label: { HealthDataSummaryCard() }
                        .buttonStyle(.plain)
                    AppSectionTitle(title: "Your overview", subtitle: "See how your habits are taking shape.")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                        count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        overviewCard(title: "Weight", value: userManager.user.weight.formatted(.number.precision(.fractionLength(1))),
                            detail: userManager.weightUnit, icon: "scalemass", action: { showingWeightDetail = true })
                        overviewCard(title: "BMI", value: userManager.getBMICategory() == .unavailable ? "—" :
                            userManager.calculateBMI().formatted(.number.precision(.fractionLength(1))),
                            detail: "Adult estimate", icon: "figure.arms.open", action: { showingBMIDetail = true })
                    }
                    weeklySummary(calories: calories)
                    AchievementSummaryCard(userManager: userManager)
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .navigationTitle("Dashboard")
            .appScreen()
            .sheet(isPresented: $showingBMIDetail) { NavigationStack { BMIDetailView() } }
            .sheet(isPresented: $showingCalorieDetail) { NavigationStack { CalorieDetailView() } }
            .sheet(isPresented: $showingWeightDetail) { NavigationStack { WeightDetailView() } }
            .sheet(isPresented: $showingAddMeal) { AddCalorieSheet() }
            .sheet(isPresented: $showingAddWeight) { AddWeightSheet() }
        }
    }

    private func calorieOverview(todaysCalories: Double, dailyGoal: Double) -> some View {
        Button { showingCalorieDetail = true } label: {
            VStack(spacing: 22) {
                Label("Today's Calories", systemImage: "flame.fill").font(.headline)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) { Image(systemName: "arrow.up.right").accessibilityHidden(true) }
                if typeSize.isAccessibilitySize {
                    calorieNumbers(todaysCalories: todaysCalories, dailyGoal: dailyGoal)
                } else {
                    VStack(spacing: 16) {
                        ZStack {
                            calorieRing(todaysCalories: todaysCalories, dailyGoal: dailyGoal)
                            VStack(spacing: 4) {
                                Text(todaysCalories.formatted(.number.precision(.fractionLength(0))))
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                                    .lineLimit(1).minimumScaleFactor(0.6).frame(width: 116)
                                Text("kcal logged").font(.caption).foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        if dailyGoal > 0 {
                            Text("of \(Int(dailyGoal)) kcal").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                Text(dailyGoal > 0 ? "\(Int(max(0, dailyGoal - todaysCalories))) kcal remaining · estimated target" :
                    "Log meals to build your daily picture.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            }
            .multilineTextAlignment(.center).padding(24).frame(maxWidth: .infinity).foregroundStyle(.white)
            .background(AppTheme.hero, in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain).accessibilityIdentifier("dashboard-calories")
    }

    private func calorieNumbers(todaysCalories: Double, dailyGoal: Double) -> some View {
        VStack(spacing: 6) {
            Text(todaysCalories.formatted(.number.precision(.fractionLength(0))))
                .font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
            Text(dailyGoal > 0 ? "of \(Int(dailyGoal)) kcal" : "kcal logged")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
        }.frame(maxWidth: .infinity)
    }
    private func calorieRing(todaysCalories: Double, dailyGoal: Double) -> some View {
        let progress = dailyGoal > 0 ? min(max(todaysCalories / dailyGoal, 0), 1) : 0
        return ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: 9)
            Circle().trim(from: 0, to: progress).stroke(Color(red: 0.76, green: 0.94, blue: 0.60),
                style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
        }.frame(width: 148, height: 148).accessibilityHidden(true)
    }

    private var quickActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { mealButton; weightButton }
            VStack(spacing: 12) { mealButton; weightButton }
        }
    }
    private var mealButton: some View {
        Button { showingAddMeal = true } label: { Label("Log a meal", systemImage: "plus") }
            .buttonStyle(AppPrimaryButtonStyle()).accessibilityIdentifier("quick-add-meal")
    }
    private var weightButton: some View {
        Button { showingAddWeight = true } label: {
            Label("Log weight", systemImage: "scalemass")
        }.buttonStyle(AppSecondaryButtonStyle()).accessibilityIdentifier("quick-add-weight")
    }

    private func overviewCard(title: String, value: String, detail: String, icon: String,
        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            AppCard {
                VStack(spacing: 16) {
                    IconBadge(icon: icon).frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                    Text(title).font(.subheadline).foregroundStyle(.secondary)
                    Text(value).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
        }.buttonStyle(.plain)
    }

    private func weeklySummary(calories: FitnessMetrics.CalorieSummary) -> some View {
        AppCard {
            VStack(spacing: 16) {
                AppSectionTitle(title: "This week's nourishment")
                HStack(alignment: .firstTextBaseline) {
                    Text(calories.average.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
                    Text("kcal / day").font(.subheadline).foregroundStyle(.secondary)
                }
                Text("\(calories.loggedDays) of 7 days logged")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }
}

struct HealthDataSummaryCard: View {
    @AppStorage("healthIntegrationEnabled") private var enabled = false
    @StateObject private var health = HealthKitManager.shared
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    IconBadge(icon: "heart.fill")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(enabled ? "Today's activity" : "Connect Apple Health").font(.headline).foregroundStyle(.primary)
                        Text(enabled ? "From the data you share" : "Steps, movement and sleep, in one place")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                if enabled {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 24) { activityValues }
                        VStack(alignment: .leading, spacing: 12) { activityValues }
                    }
                }
            }
        }
    }
    @ViewBuilder private var activityValues: some View {
        Label("\(health.steps.formatted()) steps", systemImage: "figure.walk")
        Label("\(Int(health.activeEnergy)) active kcal", systemImage: "flame")
    }
}

struct WeightGoalView: View {
    let currentWeight: Double
    let goalWeight: Double
    let usesMetric: Bool
    var body: some View {
        let difference = goalWeight - currentWeight
        Text(abs(difference) < 0.05 ? "At your goal" :
            "\(String(format: "%.1f", abs(difference))) \(usesMetric ? "kg" : "lbs") to your goal")
            .font(.subheadline).foregroundStyle(.secondary)
    }
}

struct AchievementSummaryCard: View {
    @ObservedObject var userManager: UserManager
    @StateObject private var achievementManager: AchievementManager
    init(userManager: UserManager) {
        self.userManager = userManager
        _achievementManager = StateObject(wrappedValue: AchievementManager(userManager: userManager))
    }
    var body: some View {
        NavigationLink { AchievementsView(userManager: userManager) } label: {
            AppCard {
                HStack(spacing: 16) {
                    IconBadge(icon: "rosette", color: AppTheme.warm)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Small wins, big momentum").font(.headline).foregroundStyle(.primary)
                        Text("\(achievementManager.achievements.filter(\.isUnlocked).count) achievements · \(achievementManager.totalPoints) points")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.caption)
                }
            }
        }.buttonStyle(.plain)
            .onAppear { achievementManager.checkAchievements() }
            .onChange(of: userManager.user) { _, _ in achievementManager.checkAchievements() }
    }
}
