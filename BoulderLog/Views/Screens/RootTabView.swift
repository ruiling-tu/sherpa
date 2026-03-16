import SwiftUI

enum AppTab: Hashable {
    case sessions
    case library
    case insights
    case guide
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .sessions

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(DojoTheme.surface.opacity(0.85))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LogTabScreen()
                .tag(AppTab.sessions)
                .tabItem { Label("Sessions", systemImage: "book") }

            LibraryTabScreen()
                .tag(AppTab.library)
                .tabItem { Label("Library", systemImage: "square.stack") }

            InsightsScreen()
                .tag(AppTab.insights)
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsScreen { tab in
                selectedTab = tab
            }
            .tag(AppTab.guide)
            .tabItem { Label("Guide", systemImage: "map") }
        }
        .tint(DojoTheme.accentPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DojoTheme.background.ignoresSafeArea())
    }
}
