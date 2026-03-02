import SwiftUI
import SwiftData

struct ProjectDetailScreen: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: ProjectEntryEntity

    @State private var showOverlay = true
    @State private var selectedHold: HoldEntity?
    @State private var cardRefreshToken = 0

    var body: some View {
        DojoScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DojoSpace.lg) {
                    DojoSectionHeader(title: entry.name.isEmpty ? "Project Detail" : entry.name)

                    DojoSurface {
                        VStack(alignment: .leading, spacing: DojoSpace.md) {
                            if let image = ImageStore.load(path: entry.imagePath) {
                                OverlayImageView(image: image, holds: entry.holds, showOverlay: showOverlay)
                                    .frame(height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }

                            Toggle("Show hold overlay", isOn: $showOverlay)
                                .tint(DojoTheme.accentPrimary)
                                .font(DojoType.body)

                            HStack {
                                DojoSectionHeader(title: "2D Problem Card")
                                Spacer()
                                Button("Regenerate") {
                                    cardRefreshToken += 1
                                }
                                .font(DojoType.caption)
                                .foregroundStyle(DojoTheme.accentPrimary)
                            }
                            ProblemCard2DView(entryID: entry.id, holds: sortedHolds, sourceImage: ImageStore.load(path: entry.imagePath), grade: entry.grade, refreshTrigger: cardRefreshToken) { hold in
                                selectedHold = hold
                            }
                        }
                    }

                    DojoSurface {
                        VStack(alignment: .leading, spacing: DojoSpace.sm) {
                            Text("\(entry.grade) • \(entry.status.title) • \(entry.wallAngle.title)")
                                .font(DojoType.body)
                            Text("Attempts: \(entry.attempts)")
                                .font(DojoType.body)
                                .foregroundStyle(DojoTheme.textSecondary)
                            if !entry.notes.isEmpty {
                                Text(entry.notes)
                                    .font(DojoType.body)
                                    .foregroundStyle(DojoTheme.textSecondary)
                            }
                        }
                    }

                    tagSection(title: "Style", tags: entry.styleTags.map(\.title))
                    tagSection(title: "Hold Type", tags: entry.holdTypeTags.map(\.title))
                    tagSection(title: "Technique", tags: entry.techniqueTags.map(\.title))

                    if let hold = selectedHold {
                        HoldEntityEditor(hold: hold) {
                            try? ProjectRepository(context: context).saveEntry(entry)
                        }
                    } else {
                        Text("Tap a hold in the 2D card to edit its note.")
                            .font(DojoType.caption)
                            .foregroundStyle(DojoTheme.textSecondary)
                    }
                }
                .padding(.vertical, DojoSpace.lg)
            }
        }
        .navigationTitle("Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DojoTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var sortedHolds: [HoldEntity] {
        entry.holds.sorted(by: { ($0.orderIndex ?? 999) < ($1.orderIndex ?? 999) })
    }

    private func tagSection(title: String, tags: [String]) -> some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                DojoSectionHeader(title: title)
                if tags.isEmpty {
                    Text("None")
                        .font(DojoType.caption)
                        .foregroundStyle(DojoTheme.textSecondary)
                } else {
                    FlowTags(tags: tags)
                }
            }
        }
    }
}

private struct OverlayImageView: View {
    let image: UIImage
    let holds: [HoldEntity]
    let showOverlay: Bool

    var body: some View {
        GeometryReader { geo in
            let imageRect = ImageSpaceTransform.fittedRect(imageSize: image.size, in: geo.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                if showOverlay {
                    ForEach(holds) { hold in
                        let center = ImageSpaceTransform.viewPoint(
                            from: CGPoint(x: hold.xNormalized, y: hold.yNormalized),
                            imageRect: imageRect
                        )
                        DojoHoldMarker(
                            role: hold.role,
                            diameter: max(12, hold.radius * imageRect.width * 2),
                            orderText: hold.orderIndex.map(String.init)
                        )
                        .position(center)
                    }
                }
            }
        }
    }
}

private struct HoldEntityEditor: View {
    @Bindable var hold: HoldEntity
    let onSave: () -> Void

    var body: some View {
        DojoSurface {
            VStack(alignment: .leading, spacing: DojoSpace.sm) {
                DojoSectionHeader(title: "Hold Detail")

                Picker("Role", selection: $hold.roleRaw) {
                    ForEach(HoldRole.allCases) { role in
                        Text(role.title).tag(role.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Hold Type", selection: $hold.holdTypeRaw) {
                    ForEach(HoldTypeTag.allCases) { tag in
                        Text(tag.title).tag(tag.rawValue)
                    }
                }

                TextField("Hold note", text: $hold.note, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                DojoButtonPrimary(title: "Save Hold") {
                    onSave()
                }
            }
        }
    }
}

private struct FlowTags: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: DojoSpace.sm)], alignment: .leading, spacing: DojoSpace.sm) {
            ForEach(tags, id: \.self) { tag in
                DojoTagChip(title: tag, selected: true)
            }
        }
    }
}
