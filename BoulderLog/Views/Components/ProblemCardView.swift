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

                // Subtle difficulty frame.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HoldShapeRenderer.frameColor(for: grade).opacity(0.75), lineWidth: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .inset(by: 4)
                            .stroke(HoldShapeRenderer.frameColor(for: grade).opacity(0.25), lineWidth: 1)
                    )

                if !patches.isEmpty {
                    ForEach(patches) { patch in
                        let x = geo.size.width * patch.x
                        let y = geo.size.height * patch.y
                        let base = max(24, min(52, holdDiameter(for: patch.id, in: geo.size)))

                        HoldShapeBlob(
                            role: patch.role,
                            image: patch.image,
                            diameter: base,
                            orderText: patch.orderIndex.map(String.init)
                        )
                        .position(x: x, y: y)
                        .onTapGesture {
                            if let hold = sortedHolds.first(where: { $0.id == patch.id }) {
                                onTapHold(hold)
                            }
                        }
                    }
                } else {
                    ForEach(sortedHolds) { hold in
                        DojoHoldMarker(
                            role: hold.role,
                            diameter: 20,
                            orderText: hold.orderIndex.map(String.init)
                        )
                        .position(x: geo.size.width * hold.xNormalized, y: geo.size.height * hold.yNormalized)
                        .onTapGesture {
                            onTapHold(hold)
                        }
                    }
                }
            }
        }
        .frame(height: 220)
    }

    private func holdDiameter(for id: UUID, in size: CGSize) -> CGFloat {
        guard let hold = sortedHolds.first(where: { $0.id == id }) else { return 30 }
        return CGFloat(hold.radius) * min(size.width, size.height) * 2.2
    }
}

private struct HoldShapeBlob: View {
    let role: HoldRole
    let image: UIImage?
    let diameter: CGFloat
    let orderText: String?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(RoundedRectangle(cornerRadius: diameter * 0.34, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: diameter * 0.34, style: .continuous)
                            .stroke(DojoTheme.accentSecondary.opacity(0.45), lineWidth: role == .finish ? 2.4 : 1.6)
                    )
            } else {
                RoundedRectangle(cornerRadius: diameter * 0.34, style: .continuous)
                    .fill(DojoTheme.holdFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: diameter * 0.34, style: .continuous)
                            .stroke(DojoTheme.accentSecondary.opacity(0.45), lineWidth: role == .finish ? 2.4 : 1.6)
                    )
                    .frame(width: diameter, height: diameter)
            }

            if role == .start {
                RoundedRectangle(cornerRadius: diameter * 0.27, style: .continuous)
                    .inset(by: 3)
                    .stroke(DojoTheme.accentSecondary, lineWidth: 1)
                    .frame(width: diameter, height: diameter)
            }

            if let orderText {
                Text(orderText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DojoTheme.textPrimary)
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
