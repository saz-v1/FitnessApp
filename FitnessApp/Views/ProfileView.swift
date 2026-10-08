import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.locale) private var locale
    @FocusState private var focused: Field?
    @State private var editor: ProfileEditor?
    @State private var savedMessage: String?
    @State private var confirmingReset = false
    private enum Field { case height, weight, age, goal }
    private var hasChanges: Bool { editor?.hasChanges(comparedTo: userManager.user) ?? false }
    private var candidate: User? { editor?.candidate }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AppScreenHeader(title: "Make it yours",
                        subtitle: "Your details shape your daily estimates.", icon: "person.crop.circle")
                }.listRowBackground(AppTheme.surface)
                Section {
                    NavigationLink { SettingsView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape").foregroundStyle(AppTheme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("App settings").font(.headline)
                                Text("Reminders, appearance, Apple Health & privacy").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }.accessibilityIdentifier("profile-settings")
                }
                if let editor {
                    measurements(editor)
                    personal(editor)
                    goals(editor)
                }
                Section {
                    VStack(spacing: 10) {
                        Label(userManager.calculateDailyCalories() > 0 ? "\(Int(userManager.calculateDailyCalories())) kcal / day" : "Estimate unavailable",
                            systemImage: "flame").font(.title3.weight(.semibold)).foregroundStyle(AppTheme.accent)
                        if let goal = userManager.calculateWeeklyCalorieTarget() {
                            Text("With your saved goal: \(Int(goal)) kcal / day").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text("Based on your saved profile. Save changes to update this estimate.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 8)
                } header: { Text("Your daily estimate") } footer: {
                    Text("General adult fitness estimate, not a prescribed calorie intake. Needs vary by person.")
                }
                if editor != nil && candidate == nil {
                    Section {
                        Label("Check your measurements and age. Use valid numbers; goal weight can be left blank.",
                            systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(.red)
                    }
                }
                if let error = userManager.persistenceError {
                    Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
            }
            .appForm().navigationTitle("Profile").appScreen()
            .safeAreaInset(edge: .bottom) {
                if let savedMessage {
                    Label(savedMessage, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                        .padding(14).frame(maxWidth: .infinity).background(AppTheme.softAccent)
                } else if hasChanges {
                    HStack {
                        Text("Unsaved changes").font(.subheadline)
                        Spacer()
                        Button("Discard") { confirmingReset = true }.font(.subheadline.weight(.semibold))
                    }.padding(14).background(AppTheme.surface)
                }
            }
            .onAppear { if editor == nil { editor = ProfileEditor(user: userManager.user, locale: locale) } }
            .onChange(of: hasChanges) { _, changed in if changed { savedMessage = nil } }
            .onChange(of: userManager.user) { old, new in
                if editor?.hasChanges(comparedTo: old) == false {
                    editor = ProfileEditor(user: new, locale: locale)
                }
            }
            .onChange(of: locale) { _, new in
                if let candidate { editor = ProfileEditor(user: candidate, locale: new) }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(candidate == nil).accessibilityIdentifier("profile-save")
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = nil } }
            }
            .confirmationDialog("Discard unsaved profile changes?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) {
                    focused = nil; editor = ProfileEditor(user: userManager.user, locale: locale); savedMessage = nil
                }
                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    private func measurements(_ value: ProfileEditor) -> some View {
        Section {
            Picker("Units", selection: Binding(get: { editor?.profile.usesMetric ?? true }, set: { metric in
                editor?.setMetric(metric)
            })) {
                Text("Metric").tag(true); Text("Imperial").tag(false)
            }.pickerStyle(.segmented).disabled(candidate == nil).accessibilityIdentifier("profile-units")
            numericRow("Height", text: text(\.height), field: .height, unit: value.profile.usesMetric ? "cm" : "in",
                identifier: "profile-height", unitIdentifier: "profile-height-unit")
            numericRow("Weight", text: text(\.weight), field: .weight, unit: value.profile.usesMetric ? "kg" : "lbs",
                identifier: "profile-weight", unitIdentifier: "profile-weight-unit")
        } header: { Text("Measurements") } footer: { Text("Units apply to measurements and your weight goal.") }
    }
    private func personal(_ value: ProfileEditor) -> some View {
        Section("Personal details") {
            Picker("Gender", selection: Binding(get: { editor?.profile.gender ?? .other }, set: { editor?.profile.gender = $0 })) {
                ForEach(User.Gender.allCases) { Text($0.rawValue).tag($0) }
            }
            numericRow("Age", text: text(\.age), field: .age, unit: "years", identifier: "profile-age", decimal: false)
            NavigationLink {
                List(User.ActivityLevel.allCases) { level in
                    Button {
                        editor?.profile.activityLevel = level
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(level.rawValue).foregroundStyle(.primary)
                                Text(level.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if editor?.profile.activityLevel == level {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.accent)
                            }
                        }.padding(.vertical, 6)
                    }.buttonStyle(.plain)
                }.appForm().navigationTitle("Activity Level").appScreen()
            } label: {
                HStack {
                    Text("Activity Level")
                    Spacer()
                    Text(value.profile.activityLevel.rawValue).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                }
            }
        }
    }
    private func goals(_ value: ProfileEditor) -> some View {
        Section {
            numericRow("Goal Weight", text: text(\.goal), field: .goal, unit: value.profile.usesMetric ? "kg" : "lbs",
                identifier: "profile-goal", placeholder: "Optional")
            if !value.goal.isEmpty {
                Button("Remove weight goal") { editor?.goal = "" }
            }
        } header: { Text("Weight goal") } footer: { Text("Optional. Leave this blank to focus on maintaining your habits.") }
    }
    private func text(_ keyPath: WritableKeyPath<ProfileEditor, String>) -> Binding<String> {
        Binding(get: { editor?[keyPath: keyPath] ?? "" }, set: { editor?[keyPath: keyPath] = $0 })
    }
    private func numericRow(_ title: String, text: Binding<String>, field: Field, unit: String,
                            identifier: String, unitIdentifier: String? = nil, decimal: Bool = true,
                            placeholder: String = "Amount") -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            TextField(placeholder, text: text).keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing).focused($focused, equals: field)
                .frame(minWidth: 70, maxWidth: 140).accessibilityLabel(title).accessibilityIdentifier(identifier)
            Text(unit).foregroundStyle(.secondary).accessibilityIdentifier(unitIdentifier ?? identifier + "-unit")
        }
    }
    private func save() {
        focused = nil
        guard let candidate, userManager.updateProfile(candidate) else { return }
        editor = ProfileEditor(user: userManager.user, locale: locale)
        savedMessage = "Profile saved."
    }
}

extension User.ActivityLevel {
    var description: String {
        switch self {
        case .sedentary: return "Daily activities with little planned exercise"
        case .lightlyActive: return "Light exercise 1–3 times per week"
        case .moderatelyActive: return "Moderate exercise 3–5 times per week"
        case .veryActive: return "Hard exercise 6–7 times per week"
        case .extraActive: return "Very hard exercise and a physically active job"
        }
    }
}
