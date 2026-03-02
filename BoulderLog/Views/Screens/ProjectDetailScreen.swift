import SwiftUI
import SwiftData

struct ProjectDetailScreen: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: ProjectEntryEntity

    @State private var showOverlay = true
    @State private var selectedHold: HoldEntity?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = ImageStore.load(path: entry.imagePath) {
                    VStack(alignment: .leading) {
                        Toggle("Show hold overlay", isOn: $showOverlay)
                        OverlayImageView(image: image, holds: entry.holds, showOverlay: showOverlay)
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("2D Problem Card").font(.headline)
                    ProblemCard2DView(holds: entry.holds.sorted(by: { ($0.orderIndex ?? 999) < ($1.orderIndex ?? 999) })) { hold in
                        selectedHold = hold
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.name.isEmpty ? "Untitled" : entry.name).font(.title3.bold())
                    Text("\(entry.grade) • \(entry.status.title) • \(entry.wallAngle.title)")
                    Text("Attempts: \(entry.attempts)")
                    if !entry.notes.isEmpty {
                        Text(entry.notes).foregroundStyle(.secondary)
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
                    Text("Tap a hold in the 2D card to edit its note/type.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(entry.name.isEmpty ? "Project Detail" : entry.name)
    }

    private func tagSection(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.bold())
            if tags.isEmpty {
                Text("None").foregroundStyle(.secondary)
            } else {
                Text(tags.joined(separator: ", "))
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
                        let center = ImageSpaceTransform.viewPoint(from: CGPoint(x: hold.xNormalized, y: hold.yNormalized), imageRect: imageRect)
                        Circle()
                            .stroke(color(for: hold.role), lineWidth: 2)
                            .frame(width: max(12, hold.radius * imageRect.width * 2), height: max(12, hold.radius * imageRect.width * 2))
                            .overlay {
                                if let idx = hold.orderIndex {
                                    Text("\(idx)").font(.caption2.bold()).foregroundStyle(.white)
                                }
                            }
                            .position(center)
                    }
                }
            }
        }
    }

    private func color(for role: HoldRole) -> Color {
        switch role {
        case .normal: return .blue
        case .start: return .green
        case .finish: return .red
        }
    }
}

private struct HoldEntityEditor: View {
    @Bindable var hold: HoldEntity
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hold Detail").font(.headline)
            Picker("Role", selection: $hold.roleRaw) {
                ForEach(HoldRole.allCases) { role in
                    Text(role.title).tag(role.rawValue)
                }
            }
            Picker("Hold Type", selection: $hold.holdTypeRaw) {
                ForEach(HoldTypeTag.allCases) { tag in
                    Text(tag.title).tag(tag.rawValue)
                }
            }
            TextField("Hold note", text: $hold.note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            Button("Save Hold") { onSave() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
