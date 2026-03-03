import SwiftUI
import SwiftData

@main
struct BoulderLogApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SessionEntity.self,
            ProjectEntryEntity.self,
            HoldEntity.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            AppLaunchView()
                .preferredColorScheme(.light)
                .onAppear {
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: AICardSettings.enabledKey)
                    let storedKey = defaults.string(forKey: AICardSettings.apiKeyKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if storedKey.isEmpty {
                        let fallback = AICardSettings.bundledDefaultAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !fallback.isEmpty {
                            defaults.set(fallback, forKey: AICardSettings.apiKeyKey)
                        }
                    }
                    if defaults.string(forKey: AICardSettings.modelKey)?.isEmpty ?? true {
                        defaults.set(AICardSettings.defaultModel, forKey: AICardSettings.modelKey)
                    }
                    SeedDataLoader.loadIfNeeded(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct AppLaunchView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootTabView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeInOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }
}

private struct SplashScreenView: View {
    var body: some View {
        ZStack {
            DojoTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [
                    DojoTheme.background,
                    DojoTheme.surface.opacity(0.86),
                    DojoTheme.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            DojoSurface(cornerRadius: 24) {
                VStack(spacing: DojoSpace.md) {
                    Image("LogoMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    Text("Boulder Log - Your Boulder Sherpa")
                        .font(DojoType.section)
                        .foregroundStyle(DojoTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Track projects. Learn patterns. Climb with intent.")
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, DojoSpace.xl)
        }
    }
}
