import SwiftUI
import SwiftData

struct LogTabScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SessionEntity.date, order: .reverse) private var sessions: [SessionEntity]

    @State private var showCreateSession = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailScreen(session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title).font(.headline)
                            Text(session.date, style: .date).foregroundStyle(.secondary)
                            if !session.gym.isEmpty {
                                Text(session.gym).font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(session.entries.count) entries").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSession = true
                    } label: {
                        Label("Create Session", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSession) {
                CreateSessionSheet()
            }
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        let repo = ProjectRepository(context: context)
        for idx in offsets {
            let session = sessions[idx]
            try? repo.deleteSession(session)
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
            Form {
                TextField("Session title", text: $title)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Gym", text: $gym)
            }
            .navigationTitle("Create Session")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let repo = ProjectRepository(context: context)
                        try? repo.createSession(title: title.isEmpty ? "New Session" : title, date: date, gym: gym)
                        dismiss()
                    }
                }
            }
        }
    }
}
