import SwiftUI

struct HoldEditorCanvas: View {
    let image: UIImage
    @Binding var holds: [HoldDraft]
    @Binding var selectedHoldID: UUID?
    var onTapImage: (CGPoint) -> Void
    var onTapHold: (UUID) -> Void
    var onLongPressHold: (UUID) -> Void

    var body: some View {
        GeometryReader { geo in
            let frame = ImageSpaceTransform.fittedRect(imageSize: image.size, in: geo.size)

            ZStack {
                Color.clear
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                ForEach(holds) { hold in
                    let center = ImageSpaceTransform.viewPoint(
                        from: CGPoint(x: hold.xNormalized, y: hold.yNormalized),
                        imageRect: frame
                    )

                    Circle()
                        .fill(color(for: hold.role).opacity(0.25))
                        .overlay(Circle().stroke(color(for: hold.role), lineWidth: selectedHoldID == hold.id ? 3 : 2))
                        .frame(width: max(12, hold.radius * frame.width * 2), height: max(12, hold.radius * frame.width * 2))
                        .overlay {
                            if let order = hold.orderIndex {
                                Text("\(order)").font(.caption2.bold()).foregroundStyle(.white)
                            }
                        }
                        .position(center)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let normalized = ImageSpaceTransform.normalizedPoint(from: value.location, imageRect: frame),
                                          let idx = holds.firstIndex(where: { $0.id == hold.id }) else { return }
                                    holds[idx].xNormalized = normalized.x
                                    holds[idx].yNormalized = normalized.y
                                }
                                .onEnded { _ in
                                    onTapHold(hold.id)
                                }
                        )
                        .onLongPressGesture {
                            onLongPressHold(hold.id)
                        }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard let normalized = ImageSpaceTransform.normalizedPoint(from: value.location, imageRect: frame) else { return }
                        onTapImage(normalized)
                    }
            )
        }
    }

    private func color(for role: HoldRole) -> Color {
        switch role {
        case .start: return .green
        case .finish: return .red
        case .normal: return .blue
        }
    }
}
