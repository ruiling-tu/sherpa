import SwiftUI

struct HoldEditorCanvas: View {
    let image: UIImage
    @Binding var holds: [HoldDraft]
    @Binding var selectedHoldID: UUID?
    var annotationEnabled: Bool = true
    var onTapImage: (CGPoint) -> Void
    var onTapHold: (UUID) -> Void
    var onLongPressHold: (UUID) -> Void

    var body: some View {
        GeometryReader { geo in
            let frame = ImageSpaceTransform.fittedRect(imageSize: image.size, in: geo.size)

            let canvas = ZStack {
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

                    markerView(for: hold, center: center, in: frame)
                }
            }
            .contentShape(Rectangle())

            if annotationEnabled {
                canvas.gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard let normalized = ImageSpaceTransform.normalizedPoint(from: value.location, imageRect: frame) else { return }
                            onTapImage(normalized)
                        }
                )
            } else {
                canvas
            }
        }
    }

    @ViewBuilder
    private func markerView(for hold: HoldDraft, center: CGPoint, in frame: CGRect) -> some View {
        let marker = DojoHoldMarker(
            role: hold.role,
            diameter: max(12, hold.radius * frame.width * 2),
            orderText: hold.orderIndex.map(String.init),
            selected: selectedHoldID == hold.id
        )
        .position(center)

        if annotationEnabled {
            marker
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
        } else {
            marker
        }
    }
}
