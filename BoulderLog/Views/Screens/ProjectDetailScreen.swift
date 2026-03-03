import SwiftUI
import SwiftData

struct ProjectDetailScreen: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: ProjectEntryEntity

    @State private var showOverlay = true
    @State private var selectedHold: HoldEntity?
    @State private var cardRefreshToken = 0
    private let cardAspectRatio: CGFloat = 2.0 / 3.0

    var body: some View {
        DojoScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DojoSpace.lg) {
                    DojoSectionHeader(title: entry.name.isEmpty ? "Project Detail" : entry.name)

                    if let image = sourceImage {
                        DojoSurface {
                            VStack(alignment: .leading, spacing: DojoSpace.md) {
                                HStack(alignment: .center, spacing: DojoSpace.sm) {
                                    DojoSectionHeader(title: "Route Visuals", subtitle: "Original and 2D card")
                                    Spacer()
                                    Button("Regenerate") {
                                        cardRefreshToken += 1
                                    }
                                    .font(DojoType.caption)
                                    .foregroundStyle(DojoTheme.accentPrimary)
                                }

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: DojoSpace.md),
                                        GridItem(.flexible(), spacing: DojoSpace.md)
                                    ],
                                    spacing: DojoSpace.md
                                ) {
                                    projectMediaCard(title: showOverlay ? "Original + Markers" : "Original") {
                                        OverlayImageView(image: image, holds: entry.holds, showOverlay: showOverlay, fillsBounds: true)
                                    }

                                    projectMediaCard(title: "2D Problem Card") {
                                        ProblemCard2DView(
                                            entryID: entry.id,
                                            holds: sortedHolds,
                                            sourceImage: image,
                                            grade: entry.grade,
                                            routeColor: entry.routeColor,
                                            refreshTrigger: cardRefreshToken
                                        ) { hold in
                                            selectedHold = hold
                                        }
                                    }
                                }

                                Toggle("Show hold overlay on original", isOn: $showOverlay)
                                    .tint(DojoTheme.accentPrimary)
                                    .font(DojoType.body)
                            }
                        }
                    }

                    DojoSurface {
                        VStack(alignment: .leading, spacing: DojoSpace.md) {
                            DojoSectionHeader(title: "Route Metadata")

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: DojoSpace.sm), GridItem(.flexible(), spacing: DojoSpace.sm)],
                                spacing: DojoSpace.sm
                            ) {
                                metricCard(title: "Grade", value: entry.grade)
                                metricCard(title: "Route Color", value: entry.routeColor.title)
                                metricCard(title: "Status", value: entry.status.title)
                                metricCard(title: "Wall", value: entry.wallAngle.title)
                                metricCard(title: "Attempts", value: "\(entry.attempts)")
                            }

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: DojoSpace.sm), GridItem(.flexible(), spacing: DojoSpace.sm)],
                                spacing: DojoSpace.sm
                            ) {
                                tagCard(title: "Style", tags: entry.styleTags.map(\.title))
                                tagCard(title: "Hold Type", tags: entry.holdTypeTags.map(\.title))
                                tagCard(title: "Technique", tags: entry.techniqueTags.map(\.title))
                                notesCard
                                    .gridCellColumns(2)
                            }
                        }
                    }

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

    private var sourceImage: UIImage? {
        ImageStore.load(path: entry.imagePath)
    }

    private func projectMediaCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
                .lineLimit(1)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.42))
                content()
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(cardAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DojoTheme.divider, lineWidth: 0.8)
            )
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            Text(value)
                .font(DojoType.body.weight(.medium))
                .foregroundStyle(DojoTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(DojoSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.68))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
        )
    }

    private func tagCard(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: DojoSpace.sm) {
            Text(title)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
            if tags.isEmpty {
                Text("None")
                    .font(DojoType.caption)
                    .foregroundStyle(DojoTheme.textSecondary)
            } else {
                FlowTags(tags: tags)
            }
        }
        .padding(DojoSpace.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.68))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
        )
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: DojoSpace.xs) {
            Text("Notes")
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)

            Text(entry.notes.isEmpty ? "No notes yet." : entry.notes)
                .font(DojoType.body)
                .foregroundStyle(DojoTheme.textPrimary)
                .lineLimit(entry.notes.isEmpty ? 1 : nil)
        }
        .padding(DojoSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.68))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
        )
    }
}

private struct OverlayImageView: View {
    let image: UIImage
    let holds: [HoldEntity]
    let showOverlay: Bool
    var fillsBounds: Bool = false

    var body: some View {
        GeometryReader { geo in
            let imageRect = fillsBounds
                ? ImageSpaceTransform.filledRect(imageSize: image.size, in: geo.size)
                : ImageSpaceTransform.fittedRect(imageSize: image.size, in: geo.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fillsBounds ? .fill : .fit)
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
