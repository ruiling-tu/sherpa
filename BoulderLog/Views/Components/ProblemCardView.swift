import SwiftUI

struct ProblemCard2DView: View {
    let holds: [HoldEntity]
    let sourceImage: UIImage?
    let grade: String
    let onTapHold: (HoldEntity) -> Void

    private var sortedHolds: [HoldEntity] {
        holds.sorted { ($0.orderIndex ?? 999) < ($1.orderIndex ?? 999) }
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

                // Collectible-style frame by grade difficulty.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HoldShapeRenderer.frameColor(for: grade).opacity(0.82), lineWidth: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .inset(by: 4)
                            .stroke(HoldShapeRenderer.frameColor(for: grade).opacity(0.28), lineWidth: 1)
                    )

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
        }
        .frame(height: 220)
    }

    private var renderPatches: [HoldPatch] {
        if !patches.isEmpty {
            return patches
        }

        // Fallback for entries missing source image.
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
