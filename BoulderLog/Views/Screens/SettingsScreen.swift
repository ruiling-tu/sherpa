import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            DojoScreen {
                VStack(spacing: DojoSpace.lg) {
                    DojoSurface {
                        VStack(alignment: .leading, spacing: DojoSpace.sm) {
                            DojoSectionHeader(title: "BoulderLog")
                            Text("Manual hold marking is enabled by default.")
                                .font(DojoType.body)
                            Text("Auto-detection can be plugged in through HoldDetectionService when you decide to enable it.")
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, DojoSpace.lg)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DojoTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
