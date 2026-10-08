import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var manager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AppScreenHeader(title: "Build your own rhythm",
                    subtitle: "Choose when a gentle nudge works for you.", icon: "bell.badge")
                permissionCard
                ForEach(ReminderKind.allCases) { kind in
                    ReminderEditor(kind: kind, manager: manager)
                }
                AppCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Reminder sounds", isOn: Binding(get: { manager.soundEnabled }, set: manager.setSoundEnabled))
                            .accessibilityIdentifier("reminder-sounds")
                        Text("Times follow your device's local time. Messages keep your health details private.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                AppCard {
                    VStack(spacing: 12) {
                        Button {
                            Task { await manager.scheduleTestNotification() }
                        } label: {
                            Label(manager.isSendingSample ? "Scheduling…" : "Send a sample reminder", systemImage: "paperplane")
                        }.buttonStyle(AppSecondaryButtonStyle()).disabled(manager.isSendingSample)
                        if let message = manager.sampleMessage {
                            Text(message).font(.caption).foregroundStyle(AppTheme.accent).multilineTextAlignment(.center)
                        }
                        Text("A sample arrives in five seconds when notifications are allowed. Focus and iOS settings may delay or silence alerts.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                if let error = manager.errorMessage {
                    AppCard {
                        VStack(spacing: 12) {
                            Label(error, systemImage: "exclamationmark.circle").font(.subheadline)
                            Button("Retry scheduling") { Task { await manager.reconcileReminders() } }
                                .buttonStyle(AppSecondaryButtonStyle())
                        }
                    }
                }
                Button("Turn off all reminders", role: .destructive) { manager.removeAllNotifications() }
                    .padding(12)
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Reminders").appScreen()
        .task { await manager.reconcileReminders() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await manager.reconcileReminders() } } }
    }
    private var permissionCard: some View {
        AppCard {
            VStack(spacing: 12) {
                Label(permissionTitle, systemImage: manager.permission.canDeliver ? "checkmark.shield" : "bell.slash")
                    .font(.headline).foregroundStyle(AppTheme.accent)
                Text(permissionDetail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if manager.permission == .notRequested {
                    Button("Enable notifications") { Task { await manager.requestNotifications() } }
                        .buttonStyle(AppPrimaryButtonStyle())
                } else if manager.permission == .denied || manager.permission == .quiet {
                    Button("Open notification settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                    }.buttonStyle(AppSecondaryButtonStyle())
                }
                if manager.isUpdating { ProgressView("Updating reminders").font(.caption) }
            }.frame(maxWidth: .infinity)
        }
    }
    private var permissionTitle: String {
        switch manager.permission {
        case .notRequested: return "Notifications are optional"
        case .allowed: return "Notifications are allowed"
        case .quiet: return "Reminders deliver quietly"
        case .denied: return "Notifications are blocked by iOS"
        }
    }
    private var permissionDetail: String {
        switch manager.permission {
        case .notRequested: return "Set your schedule below. Permission is requested only when you enable a reminder."
        case .allowed: return "\(manager.enabledCount) reminder\(manager.enabledCount == 1 ? "" : "s") enabled. Tap a notification to start logging."
        case .quiet: return "iOS may place reminders in Notification Centre without a banner or sound."
        case .denied: return "Your chosen schedule is saved. Allow notifications in Settings to receive it."
        }
    }
}

private struct ReminderEditor: View {
    let kind: ReminderKind
    @ObservedObject var manager: NotificationManager
    @Environment(\.dynamicTypeSize) private var typeSize
    private var settings: ReminderSettings { manager.settings(for: kind) }
    private func edit(_ change: (inout ReminderSettings) -> Void) {
        var item = settings; change(&item); manager.update(item)
    }
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                Toggle(isOn: Binding(get: { settings.enabled }, set: { value in edit { $0.enabled = value } })) {
                    HStack(spacing: 12) {
                        IconBadge(icon: kind.symbol)
                        Text(kind.title).font(.headline)
                    }
                }.accessibilityIdentifier("reminder-\(kind.rawValue)-enabled")
                Divider()
                DatePicker("Time", selection: Binding(
                    get: { settings.date() },
                    set: { date in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                        edit { $0.hour = parts.hour ?? $0.hour; $0.minute = parts.minute ?? $0.minute }
                    }), displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier("reminder-\(kind.rawValue)-time")
                Picker("Repeat", selection: Binding(get: { repeatChoice }, set: { choice in
                    switch choice {
                    case "daily": edit { $0.weekdays = Set(1...7) }
                    case "weekdays": edit { $0.weekdays = Set(2...6) }
                    case "weekends": edit { $0.weekdays = [1, 7] }
                    default: edit {
                        if $0.weekdays == Set(1...7) || $0.weekdays == Set(2...6) || $0.weekdays == Set([1, 7]) {
                            $0.weekdays = [Calendar.current.component(.weekday, from: Date())]
                        }
                    }
                    }
                })) {
                    Text("Every day").tag("daily")
                    Text("Weekdays").tag("weekdays")
                    Text("Weekends").tag("weekends")
                    Text("Selected days").tag("custom")
                }.pickerStyle(.menu).accessibilityIdentifier("reminder-\(kind.rawValue)-repeat")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                    count: typeSize.isAccessibilitySize ? 3 : 7), spacing: 8) {
                    ForEach(orderedWeekdays, id: \.self) { day in
                        let selected = settings.weekdays.contains(day)
                        Button {
                            edit { item in
                                if selected && item.weekdays.count > 1 { item.weekdays.remove(day) }
                                else { item.weekdays.insert(day) }
                            }
                        } label: {
                            Text(Calendar.current.shortStandaloneWeekdaySymbols[day - 1])
                                .font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(selected ? AppTheme.background : AppTheme.accent)
                                .background(selected ? AppTheme.accent : AppTheme.softAccent, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                            .disabled(selected && settings.weekdays.count == 1)
                            .accessibilityLabel(Calendar.current.standaloneWeekdaySymbols[day - 1])
                            .accessibilityValue(selected ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("reminder-\(kind.rawValue)-day-\(day)")
                    }
                }
                Text("Choose at least one day.").font(.caption).foregroundStyle(.secondary)
                if settings.enabled {
                    if let next = manager.nextDates[kind] {
                        Label("Next: \(next.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                            .font(.caption).foregroundStyle(AppTheme.accent)
                    } else if !manager.permission.canDeliver {
                        Text("Saved · waiting for notification permission").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    private var repeatChoice: String {
        switch settings.weekdays {
        case Set(1...7): return "daily"
        case Set(2...6): return "weekdays"
        case Set([1, 7]): return "weekends"
        default: return "custom"
        }
    }
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }
}
