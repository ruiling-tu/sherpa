import SwiftUI
import SwiftData

struct SessionDetailScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: SessionEntity
    @State private var showWizard = false
    @State private var showDeleteConfirm = false

    var body: some View {
        DojoScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DojoSpace.lg) {
                    DojoSectionHeader(
                        title: session.title,
                        subtitle: session.date.formatted(.dateTime.weekday(.wide).month().day().year())
                    )

                    if session.entries.isEmpty {
                        DojoEmptyState(
                            title: "No project entries",
                            subtitle: "Tap Add Project to create your first one in this session.",
                            icon: "square.stack"
                        )
                    } else {
                        ForEach(sortedEntries) { entry in
                            NavigationLink {
                                ProjectDetailScreen(entry: entry)
                            } label: {
                                SessionEntryCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    DojoButtonPrimary(title: "Add Project", icon: "plus") {
                        showWizard = true
                    }
                }
                .padding(.vertical, DojoSpace.md)
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DojoTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Session", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(DojoTheme.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showWizard) {
            NewProjectWizardScreen(session: session)
        }
        .alert("Delete this session?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                let repo = ProjectRepository(context: context)
                try? repo.deleteSession(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all projects, holds, and stored images in this session.")
        }
    }

    private var sortedEntries: [ProjectEntryEntity] {
        session.entries.sorted(by: { $0.createdAt > $1.createdAt })
    }
}

private struct SessionEntryCard: View {
    @Environment(\.modelContext) private var context
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

                Menu {
                    Button(role: .destructive) {
                        try? ProjectRepository(context: context).deleteEntry(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(DojoTheme.textSecondary)
                }
            }
        }
    }
}
