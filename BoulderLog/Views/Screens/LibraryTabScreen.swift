import SwiftUI
import SwiftData

struct LibraryTabScreen: View {
    @Query(sort: \ProjectEntryEntity.updatedAt, order: .reverse) private var entries: [ProjectEntryEntity]

    @State private var query = ""
    @State private var selectedGrade = "All"
    @State private var selectedStatus: EntryStatus?
    @State private var selectedWallAngle: WallAngle?
    @State private var selectedGym = ""
    @State private var selectedTag = ""
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var endDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                filterPanel

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredEntries) { entry in
                            NavigationLink {
                                ProjectDetailScreen(entry: entry)
                            } label: {
                                LibraryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal)
            .navigationTitle("Library")
            .searchable(text: $query, prompt: "Search notes")
        }
    }

    private var filteredEntries: [ProjectEntryEntity] {
        entries.filter { entry in
            let gradeOK = selectedGrade == "All" || entry.grade == selectedGrade
            let statusOK = selectedStatus == nil || entry.status == selectedStatus
            let angleOK = selectedWallAngle == nil || entry.wallAngle == selectedWallAngle
            let gymOK = selectedGym.isEmpty || entry.gym.localizedCaseInsensitiveContains(selectedGym)
            let dateOK = entry.createdAt >= startDate && entry.createdAt <= endDate
            let searchOK = query.isEmpty || entry.notes.localizedCaseInsensitiveContains(query)
            let tags = entry.styleTags.map(\.rawValue) + entry.holdTypeTags.map(\.rawValue) + entry.techniqueTags.map(\.rawValue)
            let tagOK = selectedTag.isEmpty || tags.contains { $0.localizedCaseInsensitiveContains(selectedTag) }
            return gradeOK && statusOK && angleOK && gymOK && dateOK && searchOK && tagOK
        }
    }

    private var filterPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Grade", selection: $selectedGrade) {
                    Text("All").tag("All")
                    ForEach(GradeScale.presets, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                Picker("Status", selection: Binding<String>(
                    get: { selectedStatus?.rawValue ?? "all" },
                    set: { selectedStatus = EntryStatus(rawValue: $0) }
                )) {
                    Text("All").tag("all")
                    ForEach(EntryStatus.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.menu)

                Picker("Wall", selection: Binding<String>(
                    get: { selectedWallAngle?.rawValue ?? "all" },
                    set: { selectedWallAngle = WallAngle(rawValue: $0) }
                )) {
                    Text("All").tag("all")
                    ForEach(WallAngle.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.menu)
            }

            HStack {
                TextField("Gym", text: $selectedGym)
                    .textFieldStyle(.roundedBorder)
                TextField("Tag", text: $selectedTag)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }
            .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

private struct LibraryRow: View {
    let entry: ProjectEntryEntity

    var body: some View {
        HStack(spacing: 12) {
            if let image = ImageStore.load(path: entry.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name.isEmpty ? "Untitled" : entry.name).font(.headline)
                Text("\(entry.grade) • \(entry.status.title) • \(entry.wallAngle.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.notes)
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
