import SwiftUI

struct BMIDetailView: View {
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    private var available: Bool { userManager.getBMICategory() != .unavailable }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppCard {
                    VStack(alignment: .leading, spacing: 16) {
                        IconBadge(icon: "figure.arms.open")
                        Text("Body mass index").font(.headline)
                        Text(available ? userManager.calculateBMI().formatted(.number.precision(.fractionLength(1))) : "—")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(userManager.getBMICategory().description).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if available {
                    AppCard {
                        VStack(alignment: .leading, spacing: 20) {
                            AppSectionTitle(title: "Adult BMI ranges")
                            BMIScaleView(currentBMI: userManager.calculateBMI())
                            DetailRow(title: "Underweight", value: "Below 18.5")
                            DetailRow(title: "Normal range", value: "18.5–24.9")
                            DetailRow(title: "Overweight", value: "25–29.9")
                            DetailRow(title: "Obese", value: "30 and above")
                        }
                    }
                }
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionTitle(title: "Your measurements")
                        DetailRow(title: "Height", value: "\(userManager.user.height.formatted(.number.precision(.fractionLength(0...1)))) \(userManager.heightUnit)")
                        DetailRow(title: "Weight", value: "\(userManager.user.weight.formatted(.number.precision(.fractionLength(0...1)))) \(userManager.weightUnit)")
                    }
                }
                Text("BMI is one general measure. It does not distinguish muscle from fat or replace personal health advice.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("BMI").navigationBarTitleDisplayMode(.inline).appScreen()
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

struct BMIScaleView: View {
    let currentBMI: Double
    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Color.blue.opacity(0.5).frame(width: geometry.size.width * 2 / 18.5)
                        AppTheme.accent.opacity(0.6).frame(width: geometry.size.width * 6.5 / 18.5)
                        Color.orange.opacity(0.5).frame(width: geometry.size.width * 5 / 18.5)
                        Color.red.opacity(0.4)
                    }.frame(height: 14).clipShape(Capsule())
                    Capsule().fill(.primary).frame(width: 4, height: 26)
                        .offset(x: CGFloat(min(max((currentBMI - 16.5) / 18.5, 0), 1)) * max(0, geometry.size.width - 4))
                }.frame(height: 26)
            }.frame(height: 26).accessibilityHidden(true)
            HStack { Text("16.5"); Spacer(); Text("35+") }.font(.caption).foregroundStyle(.secondary)
        }
    }
}
