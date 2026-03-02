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
            RootTabView()
                .onAppear {
                    SeedDataLoader.loadIfNeeded(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
