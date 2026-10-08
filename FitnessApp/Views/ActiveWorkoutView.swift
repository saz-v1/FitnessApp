import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: WorkoutSessionStore
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("keepWorkoutScreenAwake") private var keepScreenAwake = false
    @State private var title = ""
    @State private var type: WorkoutRecord.WorkoutType = .strength
    @State private var intensity: WorkoutRecord.Intensity = .moderate
    @State private var restSeconds = 60
    @State private var pickingExercise = false
    @State private var addingCustom = false
    @State private var finishing = false
    @State private var discarding = false
    @State private var removingExercise: UUID?
    @State private var inputsValid = true

    var body: some View {
        NavigationStack {
            Group {
                if let session = store.session { active(session) }
                else { setup }
            }.navigationTitle(store.session == nil ? "Start workout" : "Active workout").appScreen()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                    if store.session != nil {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(store.session?.finishedAt == nil ? "Finish" : "Retry save") { finishing = true }
                                .disabled(!inputsValid || !store.canEdit).accessibilityIdentifier("finish-active-workout")
                        }
                    }
                }
                .sheet(isPresented: $pickingExercise) { NavigationStack { ExerciseLibraryView { _ = store.addExercise($0) } } }
                .sheet(isPresented: $addingCustom) { CustomSessionExerciseSheet() }
                .alert("Finish this workout?", isPresented: $finishing) {
                    Button("Finish & Save") { if store.finish(userManager: userManager) { dismiss() } }
                    Button("Keep Working Out", role: .cancel) {}
                } message: { Text("Completed sets, laps and times will be saved. Current reps or a timed interval will also be included.") }
                .alert("Discard this workout?", isPresented: $discarding) {
                    Button("Discard Workout", role: .destructive) { if store.discard() { dismiss() } }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("This removes the unfinished session and its sets. Saved workout history is kept.") }
                .alert("Remove this exercise?", isPresented: Binding(get: { removingExercise != nil }, set: { if !$0 { removingExercise = nil } })) {
                    Button("Remove Exercise", role: .destructive) { if let id = removingExercise { store.removeExercise(id) }; removingExercise = nil }
                    Button("Cancel", role: .cancel) { removingExercise = nil }
                } message: { Text("Its completed sets in this session will be removed.") }
                .onAppear { updateScreenAwake() }
                .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
                .onChange(of: keepScreenAwake) { _, _ in updateScreenAwake() }
                .onChange(of: scenePhase) { _, _ in updateScreenAwake() }
                .onChange(of: store.session?.id) { _, _ in updateScreenAwake() }
                .onChange(of: store.session?.finishedAt) { _, _ in updateScreenAwake() }
        }
    }
    private var setup: some View {
        Form {
            Section { AppScreenHeader(title: "Ready when you are", subtitle: "Track your session, complete sets and time your rests.", icon: "stopwatch") }
            Section("Your session") {
                TextField("Workout name (optional)", text: $title).accessibilityIdentifier("active-workout-name")
                Picker("Type", selection: $type) { ForEach(WorkoutRecord.WorkoutType.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Intensity", selection: $intensity) { ForEach(WorkoutRecord.Intensity.allCases) { Text($0.rawValue).tag($0) } }
                restPicker(value: $restSeconds)
            }
            Section {
                Button {
                    _ = store.start(title: title, type: type, intensity: intensity, restSeconds: restSeconds)
                } label: { Label("Start session", systemImage: "play.fill") }
                    .buttonStyle(AppPrimaryButtonStyle()).disabled(title.count > 120 || !store.canEdit)
                    .accessibilityIdentifier("start-active-session")
            }.listRowBackground(Color.clear)
            Section {
                Text("Timers continue while you use another app or lock your phone. Pause stops elapsed time. Reps and laps are counted with your taps; no camera or motion access is needed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = store.errorMessage { Section { Text(error).foregroundStyle(.red); Button("Try again") { store.retryLoading() } } }
        }.appForm()
    }
    private func active(_ session: WorkoutSession) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                AppCard {
                    if session.selectedIndex != nil && session.finishedAt == nil && !typeSize.isAccessibilitySize {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title).font(.headline).lineLimit(2)
                                Text(session.type.rawValue).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            WorkoutTimerReadout(clock: session.clock, title: "Session", compact: true).fixedSize()
                            if session.hasRest { WorkoutTimerReadout(clock: session.restClock, title: "Rest", countdown: session.restSeconds, compact: true, accessibilityID: "rest-timer-summary").fixedSize() }
                            Button { store.togglePause() } label: {
                                Image(systemName: session.clock.isRunning ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
                                    .background(AppTheme.softAccent, in: RoundedRectangle(cornerRadius: 12))
                            }.accessibilityLabel(session.clock.isRunning ? "Pause workout" : "Resume workout")
                                .accessibilityIdentifier("pause-active-workout")
                        }
                    } else { VStack(spacing: 14) {
                        Text(session.title).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                        Text("\(session.type.rawValue) · \(session.intensity.rawValue)").font(.subheadline).foregroundStyle(.secondary)
                        WorkoutTimerReadout(clock: session.clock, title: "Session time")
                        if session.finishedAt == nil {
                            Button { store.togglePause() } label: {
                                Label(session.clock.isRunning ? "Pause workout" : "Resume workout", systemImage: session.clock.isRunning ? "pause.fill" : "play.fill")
                            }.buttonStyle(AppSecondaryButtonStyle()).accessibilityIdentifier("pause-active-workout")
                        } else { Text("Finished session kept until saving succeeds.").font(.caption).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity) }
                }
                if let error = store.errorMessage { Text(error).font(.subheadline).foregroundStyle(.red).multilineTextAlignment(.center) }
                if session.finishedAt == nil {
                    if session.selectedIndex == nil { movementButtons(session) }
                    if let index = session.selectedIndex {
                        TrackedExerciseControls(exercise: session.exercises[index], inputsValid: $inputsValid)
                            .id(session.exercises[index].id)
                    } else {
                        AppEmptyState(title: "Choose your first movement", message: "Select from the exercise library or add your own. You can also use the session timer on its own.", icon: "dumbbell")
                    }
                    restControls(session)
                    if session.selectedIndex != nil { movementButtons(session) }
                    if !session.exercises.isEmpty {
                        AppSectionTitle(title: "Your exercises", subtitle: "Tap to switch. Draft counts are kept.")
                        ForEach(session.exercises) { exercise in
                            AppCard {
                                HStack {
                                    Button { if inputsValid { store.selectExercise(exercise.id) } } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: session.selectedExerciseID == exercise.id ? "checkmark.circle.fill" : "circle").foregroundStyle(AppTheme.accent)
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(exercise.name).font(.headline).foregroundStyle(.primary)
                                                Text("\(exercise.completedSets.count) completed sets · \(exercise.tracking.rawValue)").font(.caption).foregroundStyle(.secondary)
                                            }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.plain).disabled(!inputsValid)
                                    Button(role: .destructive) { removingExercise = exercise.id } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                                        .accessibilityLabel("Remove \(exercise.name)")
                                }
                            }
                        }
                    }
                }
                Button(role: .destructive) { discarding = true } label: { Label("Discard session", systemImage: "trash") }.padding(.top, 8)
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
    }
    private func restControls(_ session: WorkoutSession) -> some View {
        AppCard {
            VStack(spacing: 14) {
                if session.hasRest { WorkoutTimerReadout(clock: session.restClock, title: "Rest time", countdown: session.restSeconds, accessibilityID: "rest-timer") }
                else { Label("Rest between sets", systemImage: "hourglass").font(.headline) }
                restPicker(value: Binding(get: { store.session?.restSeconds ?? 60 }, set: { store.setRestSeconds($0) }))
                HStack {
                    if session.hasRest {
                        Button("Skip rest") { store.skipRest() }.buttonStyle(AppSecondaryButtonStyle()).accessibilityIdentifier("skip-rest")
                    } else {
                        Button("Start rest") { store.startRest() }.buttonStyle(AppSecondaryButtonStyle())
                            .disabled(!session.clock.isRunning || session.restSeconds == 0)
                    }
                }
                Toggle("Alert when rest ends", isOn: Binding(get: { store.restAlertsEnabled }, set: { enabled in Task { await store.setRestAlerts(enabled) } }))
                    .font(.subheadline).accessibilityIdentifier("rest-alerts")
                Text("Optional local notification. Permission, Focus and sound settings apply.").font(.caption).foregroundStyle(.secondary)
                Toggle("Keep this screen awake", isOn: $keepScreenAwake).font(.subheadline)
                Text("Uses more battery. Applies only while the workout screen is open.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private func restPicker(value: Binding<Int>) -> some View {
        Picker("Rest after a set", selection: value) {
            Text("Off").tag(0)
            ForEach([15, 30, 45, 60, 90, 120, 180, 300], id: \.self) { Text("\($0) sec").tag($0) }
        }.accessibilityIdentifier("rest-duration")
    }
    private func movementButtons(_ session: WorkoutSession) -> some View {
        VStack(spacing: 14) {
            Button { pickingExercise = true } label: { Label("Choose exercise", systemImage: "plus") }
                .buttonStyle(AppPrimaryButtonStyle()).disabled(session.exercises.count >= 100 || !inputsValid)
                .accessibilityIdentifier("active-choose-exercise")
            Button("Add a custom movement") { addingCustom = true }.disabled(session.exercises.count >= 100 || !inputsValid)
        }
    }
    private func updateScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && scenePhase == .active && store.session != nil && store.session?.finishedAt == nil
    }
}

private struct WorkoutTimerReadout: View {
    let clock: WorkoutClock
    let title: String
    var countdown: Int? = nil
    var compact = false
    var accessibilityID = "session-timer"
    @State private var restEnded = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = clock.elapsed(at: context.date)
            let seconds = countdown.map { max(0, ceil(Double($0) - elapsed)) } ?? elapsed
            VStack(spacing: 6) {
                Text(countdown != nil && seconds == 0 ? (compact ? "Ready" : "Rest complete") : title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(seconds.timerText).font(.system(compact ? .title2 : .largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                    .contentTransition(.numericText()).accessibilityIdentifier(accessibilityID)
                if !clock.isRunning && seconds > 0 { Text("Paused").font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity)
                .onChange(of: seconds) { _, value in if countdown != nil && value == 0 { restEnded.toggle() } }
        }.sensoryFeedback(.success, trigger: restEnded)
    }
}

private struct TrackedExerciseControls: View {
    let exercise: TrackedExercise
    @Binding var inputsValid: Bool
    @EnvironmentObject private var store: WorkoutSessionStore
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.locale) private var locale
    @FocusState private var editingWeight: Bool
    @State private var weightText = ""
    @State private var viewingReference = false
    @StateObject private var catalog = ActivityCatalog.shared
    private var weightValid: Bool {
        weightText.isEmpty || LocalizedDecimal.parse(weightText, locale: locale).map {
            let kg = userManager.user.usesMetric ? $0 : $0 * 0.45359237
            return kg.isFinite && (0...2000).contains(kg)
        } == true
    }
    private var currentWeightText: String {
        exercise.weightKg.map { userManager.displayWeight($0).formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0...2))) } ?? ""
    }
    var body: some View {
        AppCard {
            VStack(spacing: 16) {
                Text(exercise.name).font(.title2.weight(.bold)).multilineTextAlignment(.center)
                Text("Set \(exercise.completedSets.count + 1)").font(.headline).foregroundStyle(AppTheme.accent)
                if let id = exercise.catalogID, catalog.exercise(id: id) != nil {
                    Button("Movement reference") { viewingReference = true }.font(.subheadline)
                }
                if exercise.tracking == .repetitions {
                    Text("\(exercise.repetitions)").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                        .accessibilityLabel("Current reps").accessibilityValue("\(exercise.repetitions)").accessibilityIdentifier("active-rep-count")
                    HStack(spacing: 12) {
                        Button { store.adjustReps(-1) } label: { Image(systemName: "minus").frame(minHeight: 30) }
                            .buttonStyle(AppSecondaryButtonStyle()).disabled(exercise.repetitions == 0 || store.session?.clock.isRunning != true)
                            .accessibilityLabel("Remove rep")
                        Button { store.adjustReps(1) } label: { Label("Rep", systemImage: "plus").frame(minHeight: 30) }
                            .buttonStyle(AppPrimaryButtonStyle()).disabled(exercise.repetitions >= 10000 || store.session?.clock.isRunning != true)
                            .accessibilityIdentifier("add-rep")
                    }
                    Menu("Set reps quickly") {
                        ForEach([5, 8, 10, 12, 15, 20], id: \.self) { count in Button("\(count) reps") { store.setReps(count) } }
                    }.disabled(store.session?.clock.isRunning != true)
                    HStack {
                        Text("Weight")
                        TextField("Optional", text: $weightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($editingWeight)
                            .accessibilityIdentifier("active-exercise-weight")
                        Text(userManager.weightUnit).foregroundStyle(.secondary)
                    }
                    if !weightValid { Text("Enter a valid weight or leave it blank.").font(.caption).foregroundStyle(.red) }
                } else {
                    WorkoutTimerReadout(clock: exercise.clock, title: "Interval time", accessibilityID: "exercise-timer")
                    Button { store.toggleExerciseTimer() } label: { Label(exercise.clock.isRunning ? "Pause interval" : "Start interval", systemImage: exercise.clock.isRunning ? "pause.fill" : "play.fill") }
                        .buttonStyle(AppSecondaryButtonStyle()).disabled(store.session?.clock.isRunning != true)
                        .accessibilityIdentifier("exercise-timer-toggle")
                    if exercise.tracking == .laps {
                        Button { store.recordLap() } label: { Label("Lap \(exercise.lapTimes.count + 1)", systemImage: "flag.fill") }
                            .buttonStyle(AppPrimaryButtonStyle()).disabled(!exercise.clock.isRunning || exercise.lapTimes.count >= 1000)
                            .accessibilityIdentifier("record-lap")
                        ForEach(exercise.lapTimes.indices, id: \.self) { index in
                            DetailRow(title: "Lap \(index + 1)", value: exercise.lapTimes[index].timerText)
                        }
                        if !exercise.lapTimes.isEmpty { Button("Undo last lap") { store.undoLap() } }
                    }
                }
                Button {
                    editingWeight = false
                    _ = store.completeSet()
                } label: { Label(exercise.tracking == .repetitions ? "Complete set" : "Complete interval", systemImage: "checkmark.circle.fill") }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(!weightValid || exercise.completedSets.count >= 1000 || (exercise.tracking == .repetitions ? exercise.repetitions == 0 : !exercise.clock.isRunning && exercise.clock.accumulated == 0))
                    .accessibilityIdentifier("complete-active-set")
                if !exercise.completedSets.isEmpty {
                    Divider()
                    ForEach(Array(exercise.completedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            CompletedSetSummary(set: set, number: index + 1)
                            Spacer()
                            Button(role: .destructive) { store.deleteSet(exerciseID: exercise.id, setID: set.id) } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
                                .accessibilityLabel("Remove set \(index + 1)")
                        }
                    }
                }
            }.frame(maxWidth: .infinity)
        }.onAppear { weightText = currentWeightText; inputsValid = true }
            .onChange(of: weightText) { _, text in
                inputsValid = weightValid
                guard weightValid, text != currentWeightText else { return }
                store.setWeight(text.isEmpty ? nil : LocalizedDecimal.parse(text, locale: locale).map { userManager.user.usesMetric ? $0 : $0 * 0.45359237 })
            }
            .onChange(of: userManager.user.usesMetric) { _, _ in weightText = currentWeightText }
            .onChange(of: locale) { _, _ in weightText = currentWeightText }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingWeight = false } } }
            .sensoryFeedback(.success, trigger: exercise.completedSets.count)
            .sheet(isPresented: $viewingReference) {
                if let id = exercise.catalogID, let entry = catalog.exercise(id: id) {
                    NavigationStack { ExerciseReferenceView(entry: entry).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { viewingReference = false } } } }
                }
            }.task { await catalog.load() }
    }
}

struct CompletedSetSummary: View {
    let set: CompletedWorkoutSet
    let number: Int
    @EnvironmentObject private var userManager: UserManager
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set \(number)").font(.subheadline.weight(.semibold))
            Text(details).font(.caption).foregroundStyle(.secondary)
            if let laps = set.lapTimes, !laps.isEmpty {
                Text(laps.enumerated().map { "Lap \($0.offset + 1): \($0.element.timerText)" }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
    private var details: String {
        var parts: [String] = []
        if let reps = set.repetitions { parts.append("\(reps) \(reps == 1 ? "rep" : "reps")") }
        if let kg = set.weightKg { parts.append("\(userManager.displayWeight(kg).formatted(.number.precision(.fractionLength(0...2)))) \(userManager.weightUnit)") }
        if let duration = set.duration { parts.append(duration.timerText) }
        if let laps = set.lapTimes { parts.append("\(laps.count) \(laps.count == 1 ? "lap" : "laps")") }
        return parts.joined(separator: " · ")
    }
}

private struct CustomSessionExerciseSheet: View {
    @EnvironmentObject private var store: WorkoutSessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var tracking = ExerciseTracking.repetitions
    var body: some View {
        NavigationStack {
            Form {
                Section("Your movement") {
                    TextField("Exercise name", text: $name)
                    Picker("Track", selection: $tracking) { ForEach(ExerciseTracking.allCases) { Text($0.rawValue).tag($0) } }
                }
            }.appForm().navigationTitle("Custom exercise").appScreen()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add") { if store.addCustomExercise(name: name, tracking: tracking) { dismiss() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 200) }
                }
        }
    }
}
