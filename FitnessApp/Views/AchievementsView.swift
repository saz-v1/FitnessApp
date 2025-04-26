import SwiftUI

// MARK: - View Modifiers
private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}

private struct StatCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}

// MARK: - Full Achievements View
struct AchievementsView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var achievementManager: AchievementManager
    
    init(userManager: UserManager) {
        _achievementManager = StateObject(wrappedValue: AchievementManager(userManager: userManager))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Overview
                HStack(spacing: 20) {
                    // Level Card
                    AchievementStatCard(
                        title: achievementManager.levelTitle(),
                        value: "\(achievementManager.currentLevel)",
                        subtitle: "\(achievementManager.pointsInCurrentLevel)/\(achievementManager.pointsToNextLevel) pts"
                    )
                    
                    // Points Card
                    AchievementStatCard(
                        title: "Total Points",
                        value: "\(achievementManager.totalPoints)"
                    )
                    
                    // Current Streak Card
                    AchievementStatCard(
                        title: "Day Streak",
                        value: "\(achievementManager.currentStreak)"
                    )
                }
                .padding(.horizontal)
                
                // Achievement Categories
                ForEach(Achievement.Category.allCases, id: \.self) { category in
                    AchievementCategorySection(
                        category: category,
                        achievements: achievementManager.achievements.filter { $0.category == category }
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Achievements")
        .onAppear {
            achievementManager.checkAchievements()
        }
    }
}

// MARK: - Supporting Views
private struct AchievementStatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title)
                .bold()
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .modifier(StatCardStyle())
    }
}

private struct AchievementCategorySection: View {
    let category: Achievement.Category
    let achievements: [Achievement]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.rawValue)
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(achievements) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.green.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(achievement.isUnlocked ? .green : .secondary)
            }
            
            // Title and Description
            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline)
                    .bold()
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 50)
            
            // Progress or Points
            VStack(spacing: 4) {
                Text("\(achievement.points) pts")
                    .font(.caption)
                    .bold()
                    .foregroundColor(achievement.isUnlocked ? .green : .secondary)
                
                if !achievement.isUnlocked {
                    ProgressView(value: achievement.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 60)
                }
            }
        }
        .frame(width: 120, height: 180)
        .modifier(CardStyle())
    }
}

// MARK: - Category Extension
extension Achievement.Category: CaseIterable {
    static var allCases: [Achievement.Category] = [.weight, .calories, .consistency, .milestones]
}

#Preview {
    NavigationView {
        AchievementsView(userManager: UserManager())
    }
} 