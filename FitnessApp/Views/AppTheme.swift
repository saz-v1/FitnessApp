import SwiftUI
import UIKit

enum AppTheme {
    static let accent = adaptive(light: 0x176A56, dark: 0x92D6B6)
    static let background = adaptive(light: 0xF4F6F2, dark: 0x141819)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x202728)
    static let softAccent = adaptive(light: 0xE5F1E8, dark: 0x293C36)
    static let warm = adaptive(light: 0x96600E, dark: 0xDFC38F)
    static let hero = LinearGradient(colors: [
        adaptive(light: UIColor(red: 0.08, green: 0.23, blue: 0.19, alpha: 1), dark: 0x244638),
        adaptive(light: UIColor(red: 0.14, green: 0.39, blue: 0.29, alpha: 1), dark: 0x304E43)
    ], startPoint: .topLeading, endPoint: .bottomTrailing)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        adaptive(light: color(light), dark: dark)
    }

    private static func adaptive(light: UIColor, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? color(dark) : light
        })
    }

    private static func color(_ rgb: UInt32) -> UIColor {
        UIColor(red: CGFloat((rgb >> 16) & 255) / 255,
            green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
}

struct AppCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.primary.opacity(0.04)) }
    }
}

struct IconBadge: View {
    let icon: String
    var color: Color = AppTheme.accent
    var body: some View {
        Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }
}

struct AppSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.weight(.bold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppEmptyState: View {
    let title: String
    let message: String
    let icon: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        AppCard {
            VStack(spacing: 16) {
                IconBadge(icon: icon)
                Text(title).font(.title3.weight(.bold))
                Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let actionTitle, let action {
                    Button(actionTitle, action: action).buttonStyle(AppPrimaryButtonStyle())
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 18).padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(enabled ? AppTheme.background : Color.secondary)
            .background(enabled ? AppTheme.accent : Color.secondary.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 18).padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 48).foregroundStyle(AppTheme.accent)
            .background(AppTheme.softAccent, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct AppScreenStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.background(AppTheme.background.ignoresSafeArea()).tint(AppTheme.accent)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
    }
}

extension View {
    func appScreen() -> some View { modifier(AppScreenStyle()) }
    func appForm() -> some View {
        scrollContentBackground(.hidden).background(AppTheme.background).tint(AppTheme.accent)
            .scrollDismissesKeyboard(.interactively)
    }
}
