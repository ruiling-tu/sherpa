import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("BoulderLog") {
                    Text("Manual hold marking is enabled by default.")
                    Text("Auto-detection can be plugged in later via HoldDetectionService.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
