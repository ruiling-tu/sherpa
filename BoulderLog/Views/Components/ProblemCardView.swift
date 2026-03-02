import SwiftUI

struct ProblemCard2DView: View {
    let entryID: UUID
    let holds: [HoldEntity]
    let sourceImage: UIImage?
    let grade: String
    var refreshTrigger: Int = 0
    let onTapHold: (HoldEntity) -> Void

    @AppStorage(AICardSettings.enabledKey) private var aiEnabled = true
    @AppStorage(AICardSettings.apiKeyKey) private var apiKey = AICardSettings.bundledDefaultAPIKey
    @AppStorage(AICardSettings.modelKey) private var model = AICardSettings.defaultModel

    @State private var aiImage: UIImage?
    @State private var isGenerating = false
    @State private var lastHandledRefreshTrigger = 0

    private var sortedHolds: [HoldEntity] {
        holds.sorted { ($0.orderIndex ?? 999) < ($1.orderIndex ?? 999) }
    }

    private var holdSpecs: [HoldRenderSpec] {
        sortedHolds.map {
            HoldRenderSpec(
                id: $0.id,
                x: $0.xNormalized,
                y: $0.yNormalized,
                radius: $0.radius,
                role: $0.role,
                orderIndex: $0.orderIndex
            )
        }
    }

    private var signature: String {
        "\(ProblemCardPromptFactory.signature(grade: grade, holds: holdSpecs))-\(model)"
    }

    private var aiTaskKey: String {
        "\(entryID.uuidString)-\(signature)-\(aiEnabled)-\(model)-\(refreshTrigger)-\(!apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)"
    }

    private var patches: [HoldPatch] {
        guard let sourceImage else { return [] }
        return HoldShapeRenderer.buildPatches(image: sourceImage, holds: sortedHolds)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.86))

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HoldShapeRenderer.frameColor(for: grade).opacity(0.82), lineWidth: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .inset(by: 4)
                            .stroke(HoldShapeRenderer.frameColor(for: grade).opacity(0.28), lineWidth: 1)
                    )

                if let aiImage {
                    aiCard(image: aiImage, geo: geo)
                } else {
                    ForEach(renderPatches) { patch in
                        let x = geo.size.width * patch.x
                        let y = geo.size.height * patch.y
                        let size = patchSize(for: patch, container: geo.size)

                        StylizedHoldShape(
                            patch: patch,
                            size: size,
                            isStart: patch.role == .start,
                            isFinish: patch.role == .finish
                        )
                        .position(x: x, y: y)
                        .onTapGesture {
                            if let hold = sortedHolds.first(where: { $0.id == patch.id }) {
                                onTapHold(hold)
                            }
                        }
                    }
                }

                if isGenerating, aiImage == nil {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, DojoSpace.sm)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.75))
                        )
                }
            }
        }
        .frame(height: 220)
        .task(id: aiTaskKey) {
            await resolveAICardIfNeeded()
        }
    }

    @ViewBuilder
    private func aiCard(image: UIImage, geo: GeometryProxy) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: geo.size.width - 18, height: geo.size.height - 18)

        ForEach(sortedHolds) { hold in
            let x = geo.size.width * hold.xNormalized
            let y = geo.size.height * hold.yNormalized
            let base = max(28, min(56, CGFloat(hold.radius) * min(geo.size.width, geo.size.height) * 2.5))

            ZStack {
                if let order = hold.orderIndex {
                    Text("\(order)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DojoTheme.textPrimary.opacity(0.72))
                        .padding(4)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.38))
                        )
                }

                Circle()
                    .fill(Color.clear)
                    .frame(width: base, height: base)
                    .contentShape(Circle())
            }
            .position(x: x, y: y)
            .onTapGesture {
                onTapHold(hold)
            }
        }
    }

    private var renderPatches: [HoldPatch] {
        if !patches.isEmpty {
            return patches
        }

        return sortedHolds.map {
            HoldPatch(
                id: $0.id,
                x: $0.xNormalized,
                y: $0.yNormalized,
                role: $0.role,
                orderIndex: $0.orderIndex,
                maskImage: nil,
                fillColor: .red,
                aspectRatio: 1
            )
        }
    }

    private func patchSize(for patch: HoldPatch, container: CGSize) -> CGSize {
        guard let hold = sortedHolds.first(where: { $0.id == patch.id }) else { return CGSize(width: 32, height: 32) }
        let base = max(20, min(58, CGFloat(hold.radius) * min(container.width, container.height) * 2.8))
        let ratio = min(max(patch.aspectRatio, 0.6), 1.7)

        if ratio >= 1 {
            return CGSize(width: base * ratio, height: base)
        }

        return CGSize(width: base, height: base / ratio)
    }

    @MainActor
    private func resolveAICardIfNeeded() async {
        if refreshTrigger > lastHandledRefreshTrigger {
            ProblemCardImageStore.invalidate(entryID: entryID)
            aiImage = nil
            lastHandledRefreshTrigger = refreshTrigger
        }

        aiImage = ProblemCardImageStore.load(entryID: entryID, signature: signature)
        guard aiImage == nil else { return }

        guard aiEnabled,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let sourceImage else {
            isGenerating = false
            return
        }

        isGenerating = true
        let generated = await ProblemCardImagePipeline.shared.loadOrGenerate(
            entryID: entryID,
            signature: signature,
            sourceImage: sourceImage,
            holds: holdSpecs,
            grade: grade
        )
        if let generated {
            aiImage = generated
        }
        isGenerating = false
    }
}

private struct StylizedHoldShape: View {
    let patch: HoldPatch
    let size: CGSize
    let isStart: Bool
    let isFinish: Bool

    var body: some View {
        ZStack {
            let fill = patch.fillColor

            Group {
                if let mask = patch.maskImage {
                    LinearGradient(
                        colors: [fill.opacity(0.98), fill.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .mask(
                        Image(uiImage: mask)
                            .resizable()
                            .scaledToFit()
                    )
                    .overlay(
                        Image(uiImage: mask)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.black.opacity(isFinish ? 0.16 : 0.1))
                            .blendMode(.multiply)
                    )
                } else {
                    RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.30, style: .continuous)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.30, style: .continuous)
                                .stroke(DojoTheme.textPrimary.opacity(isFinish ? 0.35 : 0.2), lineWidth: isFinish ? 2 : 1)
                        )
                }
            }

            if isStart {
                RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.20, style: .continuous)
                    .inset(by: 3)
                    .stroke(DojoTheme.accentSecondary.opacity(0.8), lineWidth: 1)
            }

            if let order = patch.orderIndex {
                Text("\(order)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}
