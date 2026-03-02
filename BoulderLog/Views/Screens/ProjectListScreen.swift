import SwiftUI
import SwiftData

struct LogTabScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SessionEntity.date, order: .reverse) private var sessions: [SessionEntity]

    @State private var showCreateSession = false

    var body: some View {
        NavigationStack {
            DojoScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: DojoSpace.lg) {
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
                    .padding(.vertical, DojoSpace.lg)
                }
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSession = true
                    } label: {
                        Text("New Session")
                    }
                    .foregroundStyle(DojoTheme.accentPrimary)
                }
            }
            .sheet(isPresented: $showCreateSession) {
                CreateSessionSheet()
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
