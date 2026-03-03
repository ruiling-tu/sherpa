import SwiftUI

struct SettingsScreen: View {
    @AppStorage(AICardSettings.enabledKey) private var aiEnabled = true
    @AppStorage(AICardSettings.apiKeyKey) private var openAIKey = AICardSettings.bundledDefaultAPIKey
    @AppStorage(AICardSettings.modelKey) private var model = AICardSettings.defaultModel

    @State private var revealKey = false

    var body: some View {
        NavigationStack {
            DojoScreen {
                ScrollView {
                    VStack(spacing: DojoSpace.lg) {
                        DojoSurface {
                            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                                DojoSectionHeader(title: "BoulderLog")
                                Text("Manual hold marking always works, even when AI is disabled.")
                                    .font(DojoType.body)
                                Text("AI rendering is optional and used only for generating collectible 2D problem cards.")
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.textSecondary)
                            }
                        }

                        DojoSurface {
                            VStack(alignment: .leading, spacing: DojoSpace.md) {
                                DojoSectionHeader(title: "AI Problem Cards", subtitle: "Optional image-to-image rendering")

                                Toggle("Enable AI card generation", isOn: $aiEnabled)
                                    .tint(DojoTheme.accentPrimary)
                                    .font(DojoType.body)

                                VStack(alignment: .leading, spacing: DojoSpace.xs) {
                                    Text("OpenAI API Key (Preconfigured, Optional Override)")
                                        .font(DojoType.caption)
                                        .foregroundStyle(DojoTheme.textSecondary)
                                    Group {
                                        if revealKey {
                                            TextField("sk-...", text: $openAIKey)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                        } else {
                                            SecureField("sk-...", text: $openAIKey)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                        }
                                    }
                                    .font(DojoType.caption)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.white.opacity(0.75))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(DojoTheme.divider, lineWidth: 0.8)
                                            )
                                    )

                                    Button(revealKey ? "Hide key" : "Show key") {
                                        revealKey.toggle()
                                    }
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.textSecondary)
                                }

                                Menu {
                                    ForEach(AICardSettings.modelPresets) { option in
                                        Button(model == option.id ? "\(option.title) ✓" : option.title) {
                                            model = option.id
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Model")
                                            .font(DojoType.caption)
                                            .foregroundStyle(DojoTheme.textSecondary)
                                        Spacer()
                                        Text(AICardSettings.title(for: model))
                                            .font(DojoType.caption)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.white.opacity(0.75))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(DojoTheme.divider, lineWidth: 0.8)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)

                                DojoButtonSecondary(title: "Clear Generated Card Cache") {
                                    ProblemCardImageStore.clearAll()
                                }
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
}
