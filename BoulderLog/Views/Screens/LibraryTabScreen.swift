import SwiftUI
import SwiftData

struct LibraryTabScreen: View {
    @Query(sort: \ProjectEntryEntity.updatedAt, order: .reverse) private var entries: [ProjectEntryEntity]

    @State private var query = ""
    @State private var selectedGrades: Set<String> = []
    @State private var selectedStatuses: Set<EntryStatus> = []
    @State private var selectedAngles: Set<WallAngle> = []
    @State private var selectedGym = ""
    @State private var selectedTag = ""
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            DojoScreen {
                VStack(spacing: DojoSpace.md) {
                    DojoSurface {
                        VStack(alignment: .leading, spacing: DojoSpace.sm) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showFilters.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Filters")
                                        .font(DojoType.section)
                                    Spacer()
                                    Image(systemName: showFilters ? "chevron.up" : "chevron.down")
                                        .foregroundStyle(DojoTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if showFilters {
                                filterPanel
                            }
                        }
                    }

                    if filteredEntries.isEmpty {
                        DojoEmptyState(title: "No matches", subtitle: "Adjust filters or search text to see projects.", icon: "line.3.horizontal.decrease.circle")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DojoSpace.md) {
                                ForEach(filteredEntries) { entry in
                                    NavigationLink {
                                        ProjectDetailScreen(entry: entry)
                                    } label: {
                                        LibraryRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, DojoSpace.xl)
                        }
                    }
                }
                .padding(.vertical, DojoSpace.lg)
            }
            .navigationTitle("Library")
            .searchable(text: $query, prompt: "Search notes")
        }
    }

    private var filteredEntries: [ProjectEntryEntity] {
        entries.filter { entry in
            let gradeOK = selectedGrades.isEmpty || selectedGrades.contains(entry.grade)
            let statusOK = selectedStatuses.isEmpty || selectedStatuses.contains(entry.status)
            let angleOK = selectedAngles.isEmpty || selectedAngles.contains(entry.wallAngle)
            let gymOK = selectedGym.isEmpty || entry.gym.localizedCaseInsensitiveContains(selectedGym)
            let dateOK = entry.createdAt >= startDate && entry.createdAt <= endDate
            let searchOK = query.isEmpty || entry.notes.localizedCaseInsensitiveContains(query)
            let tags = entry.styleTags.map(\.rawValue) + entry.holdTypeTags.map(\.rawValue) + entry.techniqueTags.map(\.rawValue)
            let tagOK = selectedTag.isEmpty || tags.contains { $0.localizedCaseInsensitiveContains(selectedTag) }
            return gradeOK && statusOK && angleOK && gymOK && dateOK && searchOK && tagOK
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: DojoSpace.md) {
            Text("Grade")
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DojoSpace.sm) {
                    ForEach(GradeScale.presets, id: \.self) { grade in
                        DojoTagChip(title: grade, selected: selectedGrades.contains(grade)) {
                            toggleGrade(grade)
                        }
                    }
                }
            }

            Text("Status")
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            HStack(spacing: DojoSpace.sm) {
                ForEach(EntryStatus.allCases) { status in
                    DojoTagChip(title: status.title, selected: selectedStatuses.contains(status)) {
                        toggleStatus(status)
                    }
                }
            }

            Text("Wall Angle")
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            HStack(spacing: DojoSpace.sm) {
                ForEach(WallAngle.allCases) { angle in
                    DojoTagChip(title: angle.title, selected: selectedAngles.contains(angle)) {
                        toggleAngle(angle)
                    }
                }
            }

            TextField("Gym", text: $selectedGym)
                .textFieldStyle(.roundedBorder)
            TextField("Tag", text: $selectedTag)
                .textFieldStyle(.roundedBorder)

            DatePicker("From", selection: $startDate, displayedComponents: .date)
                .font(DojoType.caption)
            DatePicker("To", selection: $endDate, displayedComponents: .date)
                .font(DojoType.caption)
        }
    }

    private func toggleGrade(_ grade: String) {
        if selectedGrades.contains(grade) {
            selectedGrades.remove(grade)
        } else {
            selectedGrades.insert(grade)
        }
    }

    private func toggleStatus(_ status: EntryStatus) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
    }

    private func toggleAngle(_ angle: WallAngle) {
        if selectedAngles.contains(angle) {
            selectedAngles.remove(angle)
        } else {
            selectedAngles.insert(angle)
        }
    }
}

private struct LibraryRow: View {
    let entry: ProjectEntryEntity

    var body: some View {
        DojoSurface {
            HStack(spacing: DojoSpace.md) {
                if let image = ImageStore.load(path: entry.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: DojoSpace.xs) {
                    Text(entry.name.isEmpty ? "Untitled" : entry.name)
                        .font(DojoType.section)
                    Text("\(entry.grade) • \(entry.status.title) • \(entry.wallAngle.title)")
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.textSecondary)
                    Text(entry.notes)
                        .font(DojoType.caption)
                        .lineLimit(2)
                        .foregroundStyle(DojoTheme.textSecondary)
                }
                Spacer()
            }
        }
    }
}
