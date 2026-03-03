import SwiftUI
import SwiftData

struct LogTabScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SessionEntity.date, order: .reverse) private var sessions: [SessionEntity]

    @State private var showCreateSession = false
    @State private var showDeleteSessionPicker = false

    var body: some View {
        NavigationStack {
            DojoScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: DojoSpace.md) {
                        DojoButtonPrimary(title: "New Session", icon: "plus") {
                            showCreateSession = true
                        }

                        if sessions.isEmpty {
                            DojoEmptyState(
                                title: "No sessions yet",
                                subtitle: "Create a session to start logging your projects.",
                                icon: "calendar"
                            )
                        } else {
                            ForEach(sessions) { session in
                                NavigationLink {
                                    SessionDetailScreen(session: session)
                                } label: {
                                    SessionCard(session: session)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        let repo = ProjectRepository(context: context)
                                        try? repo.deleteSession(session)
                                    } label: {
                                        Label("Delete Session", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, DojoSpace.md)
                }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteSessionPicker = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(DojoTheme.textSecondary)
                    }
                    .disabled(sessions.isEmpty)
                }
            }
            .toolbarBackground(DojoTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showCreateSession) {
                CreateSessionSheet()
            }
            .sheet(isPresented: $showDeleteSessionPicker) {
                DeleteSessionSheet()
            }
        }
    }
}

private struct SessionCard: View {
    let session: SessionEntity

    var body: some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                Text(session.date.formatted(.dateTime.month(.wide).day().year()))
                    .font(DojoType.title)
                    .foregroundStyle(DojoTheme.textPrimary)

                Text(session.title)
                    .font(DojoType.section)

                HStack(spacing: DojoSpace.md) {
                    if !session.gym.isEmpty {
                        Text(session.gym)
                            .font(DojoType.caption)
                            .foregroundStyle(DojoTheme.textSecondary)
                    }
                    Text("\(session.entries.count) projects")
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CreateSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var date = Date()
    @State private var gym = ""

    var body: some View {
        NavigationStack {
            DojoScreen {
                VStack(spacing: DojoSpace.lg) {
                    DojoSurface {
                        VStack(alignment: .leading, spacing: DojoSpace.md) {
                            DojoSectionHeader(title: "Create Session")
                            TextField("Session title", text: $title)
                                .textFieldStyle(.roundedBorder)
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                            TextField("Gym", text: $gym)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    DojoButtonPrimary(title: "Save Session") {
                        let repo = ProjectRepository(context: context)
                        try? repo.createSession(title: title.isEmpty ? "New Session" : title, date: date, gym: gym)
                        dismiss()
                    }

                    DojoButtonSecondary(title: "Cancel") {
                        dismiss()
                    }
                }
                .padding(.top, DojoSpace.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DeleteSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SessionEntity.date, order: .reverse) private var sessions: [SessionEntity]

    @State private var sessionToDelete: SessionEntity?

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    Text("No sessions to delete")
                        .font(DojoType.body)
                        .foregroundStyle(DojoTheme.textSecondary)
                } else {
                    ForEach(sessions) { session in
                        Button(role: .destructive) {
                            sessionToDelete = session
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .font(DojoType.body)
                                Text(session.date.formatted(.dateTime.month(.wide).day().year()))
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Delete Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete this session?", isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let sessionToDelete {
                        let repo = ProjectRepository(context: context)
                        try? repo.deleteSession(sessionToDelete)
                    }
                    self.sessionToDelete = nil
                    if sessions.count <= 1 {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {
                    sessionToDelete = nil
                }
            } message: {
                Text("This removes all projects, holds, and stored images in the selected session.")
            }
        }
    }
}
