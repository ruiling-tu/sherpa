import SwiftUI
import SwiftData

struct LibraryTabScreen: View {
    @Query(sort: \ProjectEntryEntity.updatedAt, order: .reverse) private var entries: [ProjectEntryEntity]

    @State private var query = ""
    @State private var selectedGrades: Set<String> = []
    @State private var selectedStatuses: Set<EntryStatus> = []
    @State private var selectedAngles: Set<WallAngle> = []
    @State private var selectedGym: String?
    @State private var selectedTags: Set<String> = []
    @State private var startDate = Date.distantPast
    @State private var endDate = Date.distantFuture
    @State private var showFilters = false
    @State private var didSeedDateRange = false

    private let grid = [GridItem(.flexible(), spacing: DojoSpace.md), GridItem(.flexible(), spacing: DojoSpace.md)]

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
                            LazyVGrid(columns: grid, spacing: DojoSpace.md) {
                                ForEach(filteredEntries) { entry in
                                    NavigationLink {
                                        ProjectDetailScreen(entry: entry)
                                    } label: {
                                        LibraryCard(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, DojoSpace.xl)
                        }
                    }
                }
                .padding(.vertical, DojoSpace.md)
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search notes")
            .toolbarBackground(DojoTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                seedDateRangeIfNeeded()
            }
            .onChange(of: entries.count) { _, _ in
                seedDateRangeIfNeeded()
            }
        }
    }

    private var allGyms: [String] {
        Array(Set(entries.map(\.gym).filter { !$0.isEmpty })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var allTags: [String] {
        let tags = entries.flatMap { entry in
            entry.styleTags.map(\.rawValue) + entry.holdTypeTags.map(\.rawValue) + entry.techniqueTags.map(\.rawValue)
        }
        return Array(Set(tags)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var filteredEntries: [ProjectEntryEntity] {
        entries.filter { entry in
            let gradeOK = selectedGrades.isEmpty || selectedGrades.contains(entry.grade)
            let statusOK = selectedStatuses.isEmpty || selectedStatuses.contains(entry.status)
            let angleOK = selectedAngles.isEmpty || selectedAngles.contains(entry.wallAngle)
            let gymOK = selectedGym == nil || entry.gym == selectedGym
            let dateOK = entry.createdAt >= startDate && entry.createdAt <= endDate
            let searchOK = query.isEmpty || entry.notes.localizedCaseInsensitiveContains(query)

            let entryTags = Set(entry.styleTags.map(\.rawValue) + entry.holdTypeTags.map(\.rawValue) + entry.techniqueTags.map(\.rawValue))
            let tagsOK = selectedTags.isEmpty || !entryTags.intersection(selectedTags).isEmpty

            return gradeOK && statusOK && angleOK && gymOK && dateOK && searchOK && tagsOK
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

            HStack(spacing: DojoSpace.md) {
                Menu {
                    Button(selectedGym == nil ? "All Gyms ✓" : "All Gyms") {
                        selectedGym = nil
                    }
                    Divider()
                    ForEach(allGyms, id: \.self) { gym in
                        Button(selectedGym == gym ? "\(gym) ✓" : gym) {
                            selectedGym = gym
                        }
                    }
                } label: {
                    filterPill(title: "Gym", value: selectedGym ?? "All Gyms")
                }

                Menu {
                    Button(selectedTags.isEmpty ? "All Tags ✓" : "All Tags") {
                        selectedTags.removeAll()
                    }
                    Divider()
                    ForEach(allTags, id: \.self) { tag in
                        Button(selectedTags.contains(tag) ? "\(tag) ✓" : tag) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }
                } label: {
                    filterPill(title: "Tags", value: selectedTags.isEmpty ? "All Tags" : "\(selectedTags.count) selected")
                }
            }

            DatePicker("From", selection: $startDate, displayedComponents: .date)
                .font(DojoType.caption)
            DatePicker("To", selection: $endDate, displayedComponents: .date)
                .font(DojoType.caption)
        }
    }

    private func filterPill(title: String, value: String) -> some View {
        HStack(spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            Text(value)
                .font(DojoType.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, DojoSpace.sm)
        .padding(.vertical, DojoSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
        )
    }

    private func toggleGrade(_ grade: String) {
        if selectedGrades.contains(grade) { selectedGrades.remove(grade) } else { selectedGrades.insert(grade) }
    }

    private func toggleStatus(_ status: EntryStatus) {
        if selectedStatuses.contains(status) { selectedStatuses.remove(status) } else { selectedStatuses.insert(status) }
    }

    private func toggleAngle(_ angle: WallAngle) {
        if selectedAngles.contains(angle) { selectedAngles.remove(angle) } else { selectedAngles.insert(angle) }
    }

    private func seedDateRangeIfNeeded() {
        guard !didSeedDateRange, !entries.isEmpty else { return }
        let minDate = entries.map(\.createdAt).min() ?? Date()
        let maxDate = entries.map(\.createdAt).max() ?? Date()
        startDate = Calendar.current.startOfDay(for: minDate)
        endDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: maxDate) ?? maxDate
        didSeedDateRange = true
    }
}

private struct LibraryCard: View {
    let entry: ProjectEntryEntity

    var body: some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                ProblemCard2DView(
                    entryID: entry.id,
                    holds: entry.holds,
                    sourceImage: ImageStore.load(path: entry.imagePath),
                    grade: entry.grade,
                    routeColor: entry.routeColor,
                    onTapHold: { _ in }
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(entry.name.isEmpty ? "Untitled" : entry.name)
                    .font(DojoType.section)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.9)

                HStack(spacing: DojoSpace.sm) {
                    DojoTagChip(title: entry.grade, selected: true)
                    DojoTagChip(title: entry.status.title, selected: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
