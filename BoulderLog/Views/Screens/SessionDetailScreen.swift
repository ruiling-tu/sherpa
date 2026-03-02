import SwiftUI
import SwiftData

struct SessionDetailScreen: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: SessionEntity
    @State private var showWizard = false

    var body: some View {
        List {
            if session.entries.isEmpty {
                ContentUnavailableView("No entries", systemImage: "square.stack", description: Text("Add a project to this session."))
            }

            ForEach(session.entries.sorted(by: { $0.createdAt > $1.createdAt })) { entry in
                NavigationLink {
                    ProjectDetailScreen(entry: entry)
                } label: {
                    HStack(spacing: 10) {
                        if let image = ImageStore.load(path: entry.imagePath) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        VStack(alignment: .leading) {
                            Text(entry.name.isEmpty ? "Untitled" : entry.name)
                            Text("\(entry.grade) • \(entry.status.title)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteEntries)
        }
        .navigationTitle(session.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Project") { showWizard = true }
            }
        }
        .sheet(isPresented: $showWizard) {
            NewProjectWizardScreen(session: session)
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        let sorted = session.entries.sorted(by: { $0.createdAt > $1.createdAt })
        let repo = ProjectRepository(context: context)
        for idx in offsets {
            try? repo.deleteEntry(sorted[idx])
        }
    }
}
