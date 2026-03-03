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
    @State private var generationError: String?
    @State private var retryNonce = 0
    @State private var lastHandledRefreshTrigger = 0

    private var sortedHolds: [HoldEntity] {
        holds.sorted { ($0.orderIndex ?? 999) < ($1.orderIndex ?? 999) }
    }

    private var holdSpecs: [HoldRenderSpec] {
        HoldRenderSpec.fromEntities(sortedHolds)
    }

    private var signature: String {
        ProblemCardPromptFactory.cacheSignature(grade: grade, holds: holdSpecs, model: model)
    }

    private var aiTaskKey: String {
        "\(entryID.uuidString)-\(signature)-\(aiEnabled)-\(model)-\(refreshTrigger)-\(retryNonce)-\(!apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)"
    }

    var body: some View {
        GeometryReader { geo in
            let frame = HoldShapeRenderer.frameColor(for: grade)
            let frameTier = museumFrameTier
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.86))
                    .shadow(color: frame.opacity(frameTier >= 3 ? 0.24 : 0.16), radius: frameTier >= 3 ? 9 : 6, x: 0, y: 3)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [frame.opacity(0.96), frame.opacity(0.72), Color.white.opacity(0.86)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: frameTier >= 4 ? 3.8 : (frameTier >= 3 ? 3.2 : 2.8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .inset(by: 4)
                            .stroke(frame.opacity(frameTier >= 2 ? 0.5 : 0.34), lineWidth: frameTier >= 3 ? 1.8 : 1.2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .inset(by: 1)
                            .stroke(Color.white.opacity(0.45), lineWidth: 0.8)
                    )
                    .overlay {
                        if frameTier >= 2 {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .inset(by: 8)
                                .stroke(frame.opacity(frameTier >= 4 ? 0.34 : 0.22), lineWidth: frameTier >= 4 ? 1.8 : 1.2)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if frameTier >= 3 {
                            frameCornerOrnament(color: frame)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if frameTier >= 3 {
                            frameCornerOrnament(color: frame)
                                .padding(6)
                                .rotationEffect(.degrees(90))
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if frameTier >= 3 {
                            frameCornerOrnament(color: frame)
                                .padding(6)
                                .rotationEffect(.degrees(180))
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if frameTier >= 3 {
                            frameCornerOrnament(color: frame)
                                .padding(6)
                                .rotationEffect(.degrees(270))
                        }
                    }
                    .overlay(alignment: .top) {
                        if frameTier >= 4 {
                            frameCenterOrnament(color: frame)
                                .padding(.top, 5)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if frameTier >= 4 {
                            frameCenterOrnament(color: frame)
                                .padding(.bottom, 5)
                        }
                    }

                if let aiImage {
                    aiCard(image: aiImage, geo: geo)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if isGenerating {
                    loadingCard
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if let generationError,
                          aiEnabled,
                          !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          sourceImage != nil {
                    failedCard(message: generationError)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    waitingCard
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isGenerating)
        .animation(.easeInOut(duration: 0.24), value: aiImage != nil)
        .animation(.easeInOut(duration: 0.24), value: generationError != nil)
        .task(id: aiTaskKey) {
            await resolveAICardIfNeeded()
        }
    }

    private var museumFrameTier: Int {
        let value = HoldShapeRenderer.gradeValue(grade)
        switch value {
        case ...1: return 1
        case 2: return 2
        case 3: return 3
        default: return 4
        }
    }

    private func frameCornerOrnament(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color.opacity(0.2))
                .frame(width: 14, height: 14)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(color.opacity(0.78), lineWidth: 1.0)
                .frame(width: 10, height: 10)
        }
    }

    private func frameCenterOrnament(color: Color) -> some View {
        Capsule(style: .continuous)
            .fill(color.opacity(0.22))
            .frame(width: 34, height: 8)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(0.72), lineWidth: 1)
            )
    }

    private var waitingCard: some View {
        VStack(spacing: DojoSpace.sm) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DojoTheme.textSecondary)
            Text("Problem Card preview is ready to generate.")
                .font(DojoType.body)
                .foregroundStyle(DojoTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(waitingSubtitle)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DojoSpace.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DojoTheme.divider, lineWidth: 0.8)
                )
                .padding(DojoSpace.md)
        )
    }

    private var waitingSubtitle: String {
        if sourceImage == nil {
            return "Select and crop a wall photo to create a card."
        }
        if !aiEnabled {
            return "Enable AI in Settings to generate a 2D Problem Card."
        }
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Set your API key in Settings."
        }
        return "Tap Regenerate to request a new card."
    }

    private var loadingCard: some View {
        VStack(spacing: DojoSpace.sm) {
            ProgressView()
                .controlSize(.regular)
                .tint(DojoTheme.accentPrimary)
            Text("Generating your Problem Card...")
                .font(DojoType.body)
                .foregroundStyle(DojoTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text("This usually takes a few seconds.")
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
        }
        .padding(DojoSpace.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DojoTheme.divider, lineWidth: 0.8)
                )
                .padding(DojoSpace.md)
        )
    }

    private func failedCard(message: String) -> some View {
        VStack(spacing: DojoSpace.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DojoTheme.accentPrimary)
            Text("Problem Card generation failed.")
                .font(DojoType.body)
                .foregroundStyle(DojoTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(DojoType.caption)
                .foregroundStyle(DojoTheme.textSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.center)

            Button("Retry") {
                generationError = nil
                retryNonce += 1
            }
            .font(DojoType.caption)
            .foregroundStyle(DojoTheme.accentPrimary)
            .padding(.horizontal, DojoSpace.md)
            .padding(.vertical, DojoSpace.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .overlay(Capsule(style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
            )
            .buttonStyle(.plain)
        }
        .padding(DojoSpace.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DojoTheme.divider, lineWidth: 0.8)
                )
                .padding(DojoSpace.md)
        )
    }

    @ViewBuilder
    private func aiCard(image: UIImage, geo: GeometryProxy) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geo.size.width - 18, height: geo.size.height - 18)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(grade)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, DojoSpace.sm)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(HoldShapeRenderer.frameColor(for: grade).opacity(0.95))
                )
                .padding(DojoSpace.sm)
        }

        ForEach(sortedHolds) { hold in
            let x = geo.size.width * hold.xNormalized
            let y = geo.size.height * hold.yNormalized
            let base = max(28, min(56, CGFloat(hold.radius) * min(geo.size.width, geo.size.height) * 2.5))

            if let order = hold.orderIndex {
                Text("\(order)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DojoTheme.textPrimary.opacity(0.72))
                    .padding(4)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.38))
                    )
                    .position(x: x, y: y)
                    .onTapGesture {
                        onTapHold(hold)
                    }
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: base, height: base)
                    .contentShape(Circle())
                    .position(x: x, y: y)
                    .onTapGesture {
                        onTapHold(hold)
                    }
            }
        }
    }

    @MainActor
    private func resolveAICardIfNeeded() async {
        if refreshTrigger > lastHandledRefreshTrigger {
            ProblemCardImageStore.invalidate(entryID: entryID)
            aiImage = nil
            generationError = nil
            lastHandledRefreshTrigger = refreshTrigger
        }

        let allowLooseCache = entryID != ProblemCardImageStore.previewDraftEntryID
        aiImage = ProblemCardImageStore.load(entryID: entryID, signature: signature)
            ?? (allowLooseCache ? ProblemCardImageStore.loadAny(entryID: entryID) : nil)
        if aiImage != nil {
            isGenerating = false
            generationError = nil
            return
        }

        guard aiEnabled,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let sourceImage else {
            isGenerating = false
            generationError = nil
            return
        }

        isGenerating = true
        generationError = nil
        let result = await ProblemCardImagePipeline.shared.loadOrGenerate(
            entryID: entryID,
            signature: signature,
            sourceImage: sourceImage,
            holds: holdSpecs,
            grade: grade
        )
        switch result {
        case .ready(let generated):
            aiImage = generated
        case .failed(let message):
            generationError = message
        }
        isGenerating = false
    }
}
