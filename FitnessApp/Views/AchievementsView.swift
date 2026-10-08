import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var userManager: UserManager
    @StateObject private var manager: AchievementManager
    init(userManager: UserManager) { _manager = StateObject(wrappedValue: AchievementManager(userManager: userManager)) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    Label("LEVEL \(manager.currentLevel)", systemImage: "rosette").font(.subheadline.weight(.semibold))
                    Text(manager.levelTitle()).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("\(manager.totalPoints) points earned").font(.headline)
                    let denominator = manager.pointsInCurrentLevel + manager.pointsToNextLevel
                    ProgressView(value: denominator > 0 ? Double(manager.pointsInCurrentLevel) / Double(denominator) : 1)
                        .tint(Color(red: 0.76, green: 0.94, blue: 0.60))
                    Text(manager.pointsToNextLevel > 0 ? "\(manager.pointsToNextLevel) points to the next level" : "You've reached the highest level.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.white).background(AppTheme.hero, in: RoundedRectangle(cornerRadius: 28))
                AppSectionTitle(title: "Celebrate the small wins", subtitle: "Build habits at your own pace.")
                ForEach(Achievement.Category.allCases, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(category.rawValue).font(.headline).foregroundStyle(AppTheme.accent)
                        ForEach(manager.achievements.filter { $0.category == category }) { AchievementCard(achievement: $0) }
                    }
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Achievements").appScreen()
        .onAppear { manager.checkAchievements() }
        .onChange(of: userManager.user) { _, _ in manager.checkAchievements() }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 16) {
                IconBadge(icon: achievement.icon, color: achievement.isUnlocked ? AppTheme.warm : .secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text(achievement.title).font(.headline)
                    Text(achievement.description).font(.subheadline).foregroundStyle(.secondary)
                    if achievement.isUnlocked {
                        Label("Unlocked · \(achievement.points) points", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.accent)
                    } else {
                        ProgressView(value: min(max(achievement.progress, 0), 1)).tint(AppTheme.accent)
                        Text("\(achievement.points) points · \(Int(min(max(achievement.progress, 0), 1) * 100))% complete")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

extension Achievement.Category: CaseIterable {
    static var allCases: [Achievement.Category] = [.weight, .calories, .consistency, .milestones]
}
