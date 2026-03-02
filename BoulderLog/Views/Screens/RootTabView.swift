import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            LogTabScreen()
                .tabItem { Label("Log", systemImage: "book") }

            LibraryTabScreen()
                .tabItem { Label("Library", systemImage: "square.stack") }

            InsightsScreen()
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
