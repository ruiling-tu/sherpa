import SwiftUI

struct RootTabView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(DojoTheme.surface.opacity(0.85))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            LogTabScreen()
                .tabItem { Label("Sessions", systemImage: "book") }

            LibraryTabScreen()
                .tabItem { Label("Library", systemImage: "square.stack") }

            InsightsScreen()
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(DojoTheme.accentPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DojoTheme.background.ignoresSafeArea())
    }
}
