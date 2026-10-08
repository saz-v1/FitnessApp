import SwiftUI

struct WorkoutLogView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingAddWorkout = false
    @State private var showingInsights = false
    @State private var selectedWorkout: WorkoutRecord?
    @State private var isEditing = false
    @State private var searchText = ""

    private func dayGroups(for workouts: [WorkoutRecord], calendar: Calendar) -> [WorkoutDayGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = workouts.filter {
            query.isEmpty || $0.type.rawValue.localizedCaseInsensitiveContains(query) ||
            ($0.notes?.localizedCaseInsensitiveContains(query) ?? false) ||
            ($0.exercises?.contains { $0.name.localizedCaseInsensitiveContains(query) } ?? false)
        }.sorted { $0.date > $1.date }
        let groups = Dictionary(grouping: matches) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { WorkoutDayGroup(date: $0, records: groups[$0] ?? []) }
    }

    var body: some View {
        let workouts = userManager.user.workoutHistory
        let calendar = Calendar.current
        let now = Date()
        // Reuse one sorted/grouped snapshot for every visible history row.
        let groups = dayGroups(for: workouts, calendar: calendar)
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let workoutsThisWeek = workouts.reduce(0) { $0 + ($1.date >= start && $1.date <= now ? 1 : 0) }
        let streak = FitnessMetrics.streak(dates: workouts.map(\.date), now: now, calendar: calendar)

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Move at your own pace. Every session counts.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    statistics(sessions: workouts.count, thisWeek: workoutsThisWeek, streak: streak)
                    Button { showingAddWorkout = true } label: { Label("Log a workout", systemImage: "plus") }
                        .buttonStyle(AppPrimaryButtonStyle()).accessibilityIdentifier("add-workout")
                    Button { showingInsights = true } label: {
                        AppCard {
                            HStack(spacing: 14) {
                                IconBadge(icon: "chart.xyaxis.line")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your workout patterns").font(.headline).foregroundStyle(.primary)
                                    Text("Frequency, duration and consistency").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.buttonStyle(.plain)
                    if workouts.isEmpty {
                        AppEmptyState(title: "Your next chapter starts here",
                            message: "A walk, a stretch, a gym session. Log your first workout and watch your progress build.",
                            icon: "figure.walk")
                    } else if groups.isEmpty {
                        AppEmptyState(title: "No matching workouts",
                            message: "Try a different type, exercise or note.", icon: "magnifyingglass")
                    } else {
                        AppSectionTitle(title: "Workout history")
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(groups) { group in
                                Section {
                                    ForEach(group.records) { record in
                                        WorkoutCard(workout: record, isEditing: isEditing) {
                                            if isEditing { userManager.deleteWorkout(record) }
                                            else { selectedWorkout = record }
                                        }
                                    }
                                } header: {
                                    Text(group.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                        .padding(.top, group.id == groups.first?.id ? 0 : 12)
                                }
                            }
                        }
                    }
                }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .navigationTitle("Workouts")
            .searchable(text: $searchText, prompt: "Find a workout")
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !workouts.isEmpty {
                        Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
                    }
                }
            }
            .sheet(item: $selectedWorkout) { workout in NavigationStack { WorkoutDetailView(workout: workout) } }
            .sheet(isPresented: $showingAddWorkout) { AddWorkoutSheet() }
            .sheet(isPresented: $showingInsights) { NavigationStack { WorkoutInsightsView() } }
            .onChange(of: workouts.isEmpty) { _, isEmpty in
                if isEmpty { isEditing = false }
            }
        }
    }

    private func statistics(sessions: Int, thisWeek: Int, streak: Int) -> some View {
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
            count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 10) {
            WorkoutStatCard(title: "Sessions", value: "\(sessions)", icon: "figure.run", color: AppTheme.accent)
            WorkoutStatCard(title: "This week", value: "\(thisWeek)", icon: "calendar", color: AppTheme.accent)
            WorkoutStatCard(title: "Day streak", value: "\(streak)", icon: "flame.fill", color: AppTheme.warm)
        }
    }
}

private struct WorkoutDayGroup: Identifiable {
    let date: Date
    let records: [WorkoutRecord]
    var id: Date { date }
}

struct WorkoutStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).accessibilityHidden(true)
            Text(value).font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
    }
}

struct WorkoutCard: View {
    let workout: WorkoutRecord
    let isEditing: Bool
    let onTap: () -> Void
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 12) {
            Button { if !isEditing { onTap() } } label: {
                AppCard {
                    HStack(alignment: .top, spacing: 14) {
                        IconBadge(icon: workout.type.symbol)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(workout.type.rawValue).font(.headline).foregroundStyle(.primary)
                            Text("\(workout.duration.workoutDuration) · \(workout.intensity.rawValue)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if let calories = workout.caloriesBurned {
                                Label("\(calories) kcal", systemImage: "flame").font(.caption).foregroundStyle(AppTheme.warm)
                            }
                            Text(workout.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if !isEditing { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }.buttonStyle(.plain).disabled(isEditing)
            if isEditing {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Image(systemName: "trash").frame(width: 44, height: 44)
                }.accessibilityLabel("Delete \(workout.type.rawValue) workout")
            }
        }
        .alert("Delete this workout?", isPresented: $confirmingDelete) {
            Button("Delete Workout", role: .destructive, action: onTap)
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the entry from FitSwift. Apple Health records are kept.") }
    }
}

struct WorkoutDetailView: View {
    let workout: WorkoutRecord
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    @State private var confirmingDelete = false
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    IconBadge(icon: workout.type.symbol)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.type.rawValue).font(.title2.weight(.bold))
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 10)
            }
            Section("Session") {
                DetailRow(title: "Duration", value: workout.duration.workoutDuration)
                DetailRow(title: "Intensity", value: workout.intensity.rawValue)
                if let calories = workout.caloriesBurned { DetailRow(title: "Energy", value: "\(calories) kcal") }
            }
            if let exercises = workout.exercises, !exercises.isEmpty {
                Section("Exercises") {
                    ForEach(exercises) { exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exercise.name).font(.headline)
                            if let sets = exercise.sets, let reps = exercise.reps {
                                Text("\(sets) sets × \(reps) reps").font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let weight = exercise.weight {
                                Text("\(userManager.displayWeight(weight).formatted(.number.precision(.fractionLength(0...1)))) \(userManager.weightUnit)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let duration = exercise.duration {
                                Text(duration.workoutDuration).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6)
                    }
                }
            }
            if let notes = workout.notes, !notes.isEmpty { Section("Notes") { Text(notes) } }
            Section {
                Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete Workout", systemImage: "trash") }
            }
            if let error = userManager.persistenceError { Section { Text(error).foregroundStyle(.red) } }
        }
        .appForm().navigationTitle("Workout").navigationBarTitleDisplayMode(.inline).appScreen()
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .alert("Delete this workout?", isPresented: $confirmingDelete) {
            Button("Delete Workout", role: .destructive) {
                if userManager.deleteWorkout(workout) { dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the entry from FitSwift. Apple Health records are kept.") }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }.padding(.vertical, 4)
    }
}

extension WorkoutRecord.WorkoutType {
    var symbol: String {
        switch self {
        case .cardio: return "figure.walk"
        case .strength: return "dumbbell"
        case .flexibility: return "figure.flexibility"
        case .hiit: return "bolt.heart"
        case .yoga: return "figure.yoga"
        case .other: return "figure.run"
        }
    }
}
private extension TimeInterval {
    var workoutDuration: String {
        let minutes = Int(self / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
