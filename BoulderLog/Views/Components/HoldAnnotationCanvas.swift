import SwiftUI

struct HoldEditorCanvas: View {
    let image: UIImage
    let routeColor: RouteColor
    @Binding var holds: [HoldDraft]
    @Binding var wallOutline: [CGPoint]
    @Binding var selectedHoldID: UUID?
    let sampleMode: Bool
    let samplePoint: CGPoint?
    var onTapHold: (UUID) -> Void
    var onTapImage: (CGPoint) -> Void
    var onRequestRedrawHold: (UUID) -> Void
    var onDeleteHold: (UUID) -> Void
    var onMoveHold: (UUID, CGPoint) -> Void
    var onMoveWallPoint: (Int, CGPoint) -> Void
    var onUpdateHoldContour: (UUID, [CGPoint]) -> Void

    var body: some View {
        GeometryReader { geo in
            let frame = ImageSpaceTransform.fittedRect(imageSize: image.size, in: geo.size)

            ZStack {
                Color.clear

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                if sampleMode {
                    sampleOverlay(in: frame)
                }

                wallOverlay(in: frame)

                ForEach(holds) { hold in
                    holdOverlay(for: hold, in: frame)
                }

                ForEach(Array(wallOutline.enumerated()), id: \.offset) { index, point in
                    wallHandle(index: index, point: point, in: frame)
                }

                if let selectedHold {
                    inspector(for: selectedHold, in: frame)
                }

                if let samplePoint {
                    sampledPointBadge(samplePoint, in: frame)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private var selectedHold: HoldDraft? {
        guard let selectedHoldID else { return nil }
        return holds.first(where: { $0.id == selectedHoldID })
    }

    private func wallOverlay(in frame: CGRect) -> some View {
        let points = wallOutline.map { ImageSpaceTransform.viewPoint(from: $0, imageRect: frame) }

        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        .stroke(routeColor.swatch.opacity(0.72), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
    }

    private func sampleOverlay(in frame: CGRect) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.16))
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .overlay(alignment: .top) {
                Text("Tap one hold from the selected route")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.9))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(DojoTheme.divider, lineWidth: 0.8)
                            )
                    )
                    .padding(.top, 12)
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

    private func holdOverlay(for hold: HoldDraft, in frame: CGRect) -> some View {
        let contour = hold.contourPoints
        let path = holdPath(contour: contour, in: frame)
        let center = ImageSpaceTransform.viewPoint(
            from: CGPoint(x: hold.xNormalized, y: hold.yNormalized),
            imageRect: frame
        )
        let selected = selectedHoldID == hold.id

        return ZStack {
            path
                .fill(routeColor.swatch.opacity(selected ? 0.22 : 0.15))
                .overlay {
                    path.stroke(selected ? routeColor.shadowSwatch : routeColor.swatch, lineWidth: selected ? 2.3 : 1.2)
                }
                .shadow(color: routeColor.shadowSwatch.opacity(0.14), radius: selected ? 5 : 2, x: 0, y: 2)

            DojoHoldMarker(
                role: hold.role,
                diameter: max(12, hold.radius * frame.width * 1.2),
                orderText: hold.orderIndex.map(String.init),
                selected: selected
            )
            .position(center)
        }
        .contentShape(path)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !sampleMode,
                          let normalized = ImageSpaceTransform.normalizedPoint(from: value.location, imageRect: frame) else { return }
                    onMoveHold(hold.id, normalized)
                    selectedHoldID = hold.id
                }
                .onEnded { _ in
                    onTapHold(hold.id)
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    guard !sampleMode else { return }
                    onTapHold(hold.id)
                }
        )
    }

    private func wallHandle(index: Int, point: CGPoint, in frame: CGRect) -> some View {
        let center = ImageSpaceTransform.viewPoint(from: point, imageRect: frame)

        return Circle()
            .fill(Color.white.opacity(0.94))
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .stroke(routeColor.swatch, lineWidth: 2)
            )
            .position(center)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !sampleMode,
                              let normalized = ImageSpaceTransform.normalizedPoint(from: value.location, imageRect: frame) else { return }
                        onMoveWallPoint(index, normalized)
                    }
            )
    }

    private func inspector(for hold: HoldDraft, in frame: CGRect) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected hold")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DojoTheme.textSecondary)
                Text("\(Int(hold.confidence * 100))% confidence")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(routeColor.shadowSwatch)
            }

            Spacer(minLength: 6)

            Button {
                onRequestRedrawHold(hold.id)
            } label: {
                Label("Redraw", systemImage: "pencil.line")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(routeColor.swatch.opacity(0.16))
            )

            Button(role: .destructive) {
                onDeleteHold(hold.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "A2473A"))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color(hex: "F6E6E3"))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: min(frame.width - 20, 360))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    private func sampledPointBadge(_ point: CGPoint, in frame: CGRect) -> some View {
        let center = ImageSpaceTransform.viewPoint(from: point, imageRect: frame)

        return ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 2.5)
                .frame(width: 22, height: 22)
            Circle()
                .fill(routeColor.swatch)
                .frame(width: 8, height: 8)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
        .position(center)
    }

    private func holdPath(contour: [CGPoint], in frame: CGRect) -> Path {
        Path { path in
            guard let first = contour.first else { return }
            path.move(to: ImageSpaceTransform.viewPoint(from: first, imageRect: frame))
            for point in contour.dropFirst() {
                path.addLine(to: ImageSpaceTransform.viewPoint(from: point, imageRect: frame))
            }
            path.closeSubpath()
        }
    }
}
