import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            DojoScreen {
                ScrollView {
                    VStack(spacing: DojoSpace.lg) {
                        DojoSurface {
                            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                                DojoSectionHeader(title: "BoulderLog")
                                Text("Route blueprints are extracted locally from the cropped wall photo using the selected route color.")
                                    .font(DojoType.body)
                                Text("Each detected hold keeps its own outline, position, and wall relationship so you can correct the geometry before exporting a PNG.")
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.textSecondary)
                            }
                        }

                        DojoSurface {
                            VStack(alignment: .leading, spacing: DojoSpace.md) {
                                DojoSectionHeader(title: "Route Extraction", subtitle: "Current workflow")

                                settingRow(
                                    title: "Detection",
                                    detail: "Local color-based extraction from the cropped route photo."
                                )
                                settingRow(
                                    title: "Editing",
                                    detail: "Drag holds to fix spacing and drag wall corners to match the wall shape."
                                )
                                settingRow(
                                    title: "Export",
                                    detail: "Generate a PNG blueprint from the current route geometry and share or save it."
                                )
                            }
                        }
                    }
                    .padding(.vertical, DojoSpace.lg)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DojoTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func settingRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            Text(detail)
                .font(DojoType.body)
                .foregroundStyle(DojoTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
