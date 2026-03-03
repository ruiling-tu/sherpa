import SwiftUI
import SwiftData

struct SessionDetailScreen: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: SessionEntity
    @State private var showWizard = false
    @State private var entryToDelete: ProjectEntryEntity?

    var body: some View {
        DojoScreen {
            List {
                DojoSectionHeader(
                    title: session.title,
                    subtitle: session.date.formatted(.dateTime.weekday(.wide).month().day().year())
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: DojoSpace.md, leading: 0, bottom: DojoSpace.sm, trailing: 0))

                if session.entries.isEmpty {
                    DojoEmptyState(
                        title: "No project entries",
                        subtitle: "Tap Add Project to create your first one in this session.",
                        icon: "square.stack"
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: DojoSpace.sm, leading: 0, bottom: DojoSpace.sm, trailing: 0))
                } else {
                    ForEach(sortedEntries) { entry in
                        NavigationLink {
                            ProjectDetailScreen(entry: entry)
                        } label: {
                            SessionEntryCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                entryToDelete = entry
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: DojoSpace.sm, leading: 0, bottom: DojoSpace.sm, trailing: 0))
                    }
                }

                DojoButtonPrimary(title: "Add Project", icon: "plus") {
                    showWizard = true
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: DojoSpace.md, leading: 0, bottom: DojoSpace.md, trailing: 0))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DojoTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showWizard) {
            NewProjectWizardScreen(session: session)
        }
        .alert("Delete this project?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let entryToDelete else { return }
                try? ProjectRepository(context: context).deleteEntry(entryToDelete)
                self.entryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: {
            Text("This removes the project, its holds, and stored images.")
        }
    }

    private var sortedEntries: [ProjectEntryEntity] {
        session.entries.sorted(by: { $0.createdAt > $1.createdAt })
    }
}

private struct SessionEntryCard: View {
    let entry: ProjectEntryEntity

    var body: some View {
        DojoSurface {
            HStack(spacing: DojoSpace.md) {
                if let image = ImageStore.load(path: entry.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: DojoSpace.xs) {
                    Text(entry.name.isEmpty ? "Untitled Project" : entry.name)
                        .font(DojoType.section)
                    Text("\(entry.grade) • \(entry.status.title)")
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.textSecondary)
                }

                Spacer()
            }
        }
    }
}
