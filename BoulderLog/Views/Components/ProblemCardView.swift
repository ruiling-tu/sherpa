import SwiftUI
import UIKit

struct ProblemCard2DView: View {
    let entryID: UUID
    let holds: [HoldEntity]
    let sourceImage: UIImage?
    let wallOutline: [CGPoint]
    let grade: String
    let routeColor: RouteColor
    let wallAngle: WallAngle
    var refreshTrigger: Int = 0
    let onTapHold: (HoldEntity) -> Void

    private var sortedHolds: [HoldEntity] {
        holds.sorted { ($0.orderIndex ?? 999) < ($1.orderIndex ?? 999) }
    }

    var body: some View {
        GeometryReader { geo in
            let contentRect = blueprintContentRect(size: geo.size)
            ZStack {
                RouteBlueprintArtwork(
                    holds: sortedHolds,
                    sourceImage: sourceImage,
                    wallOutline: wallOutline,
                    grade: grade,
                    routeColor: routeColor,
                    wallAngle: wallAngle
                )

                ForEach(sortedHolds) { hold in
                    HoldContourShape(points: hold.contourPoints, drawRect: contentRect)
                        .fill(Color.clear)
                        .contentShape(HoldContourShape(points: hold.contourPoints, drawRect: contentRect))
                        .onTapGesture {
                            onTapHold(hold)
                        }
                }
            }
        }
    }

    private func blueprintContentRect(size: CGSize) -> CGRect {
        let outerRect = CGRect(origin: .zero, size: size)
        let innerRect = outerRect.insetBy(dx: 16, dy: 16)
        guard let sourceImage else { return innerRect }
        let fitted = ImageSpaceTransform.fittedRect(imageSize: sourceImage.size, in: innerRect.size)
        return fitted.offsetBy(dx: innerRect.minX, dy: innerRect.minY)
    }
}

struct RouteBlueprintArtwork: View {
    let holds: [HoldEntity]
    let sourceImage: UIImage?
    let wallOutline: [CGPoint]
    let grade: String
    let routeColor: RouteColor
    let wallAngle: WallAngle

    private let surfaceColor = Color(hex: "F4F0E8")

    var body: some View {
        GeometryReader { geo in
            let frameColor = HoldShapeRenderer.frameColor(for: grade)
            let frameHighlight = HoldShapeRenderer.frameHighlight(for: grade)
            let outerRect = CGRect(origin: .zero, size: geo.size)
            let innerRect = outerRect.insetBy(dx: 16, dy: 16)
            let sourceRect = sourceImage.map {
                ImageSpaceTransform.fittedRect(imageSize: $0.size, in: innerRect.size)
                    .offsetBy(dx: innerRect.minX, dy: innerRect.minY)
            } ?? innerRect
            let wallPath = wallShape(in: innerRect)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(surfaceColor)
                    .shadow(color: frameColor.opacity(0.16), radius: 12, x: 0, y: 6)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [frameHighlight.opacity(0.92), frameColor.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.6
                    )

                wallPath
                    .fill(
                        LinearGradient(
                            colors: wallGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        wallPath.stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }

                wallPath
                    .stroke(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 1.4, dash: [8, 6]))

                wallAtmosphere(in: innerRect)

                ForEach(holds) { hold in
                    holdView(for: hold, drawRect: sourceRect)
                }

                if holds.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(DojoTheme.textSecondary)
                        Text("No holds detected")
                            .font(DojoType.body)
                            .foregroundStyle(DojoTheme.textPrimary)
                        Text("Re-extract with a tighter crop or redraw a missed outline.")
                            .font(DojoType.caption)
                            .foregroundStyle(DojoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.8))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DojoTheme.divider, lineWidth: 0.8))
                    )
                }

                metadataBadge
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private var wallGradient: [Color] {
        switch wallAngle {
        case .slab:
            return [Color(hex: "FBF8F1"), Color(hex: "E7DED0")]
        case .vert:
            return [Color(hex: "F3EBDF"), Color(hex: "D7CBB8")]
        case .overhang:
            return [Color(hex: "DDCEBB"), Color(hex: "B29E88")]
        }
    }

    private func wallShape(in rect: CGRect) -> Path {
        let points = normalizedWallOutline.map { point in
            CGPoint(
                x: rect.minX + point.x * rect.width,
                y: rect.minY + point.y * rect.height
            )
        }

        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private var normalizedWallOutline: [CGPoint] {
        let points = wallOutline.isEmpty ? RouteGeometry.defaultWallOutline : wallOutline
        return points.map(RouteGeometry.clamped)
    }

    private func wallAtmosphere(in rect: CGRect) -> some View {
        ZStack {
            RadialGradient(
                colors: [Color.white.opacity(0.34), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: max(rect.width, rect.height) * 0.9
            )
            .clipShape(wallShape(in: rect))

            ForEach(0..<7, id: \.self) { index in
                wallShape(in: rect)
                    .stroke(
                        routeColor.swatch.opacity(index == 0 ? 0.05 : 0.025),
                        style: StrokeStyle(lineWidth: index == 0 ? 1.2 : 0.8, dash: [CGFloat(12 + index * 2), CGFloat(10 + index * 2)])
                    )
                    .scaleEffect(
                        x: 1 - CGFloat(index) * 0.035,
                        y: 1 - CGFloat(index) * 0.045,
                        anchor: .center
                    )
                    .blendMode(.multiply)
            }
        }
        .allowsHitTesting(false)
    }

    private func holdView(for hold: HoldEntity, drawRect: CGRect) -> some View {
        let contour = hold.contourPoints
        let roleAccent: Color = {
            switch hold.role {
            case .start: return Color(hex: "5B9B64")
            case .finish: return Color(hex: "BC5441")
            case .normal: return routeColor.shadowSwatch
            }
        }()

        return ZStack {
            if let sourceImage {
                Image(uiImage: sourceImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: drawRect.width, height: drawRect.height)
                    .position(x: drawRect.midX, y: drawRect.midY)
                    .saturation(0.72)
                    .contrast(1.28)
                    .brightness(0.02)
                    .mask(HoldContourShape(points: contour, drawRect: drawRect))
                    .overlay {
                        HoldContourShape(points: contour, drawRect: drawRect)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.34), Color.clear, Color.black.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        HoldContourShape(points: contour, drawRect: drawRect)
                            .fill(routeColor.swatch.opacity(0.22))
                            .blendMode(.softLight)
                    }
                    .overlay {
                        HoldContourShape(points: contour, drawRect: drawRect)
                            .fill(
                                RadialGradient(
                                    colors: [routeColor.swatch.opacity(0.18), Color.clear],
                                    center: .topLeading,
                                    startRadius: 10,
                                    endRadius: max(drawRect.width, drawRect.height) * 0.5
                                )
                            )
                    }
            } else {
                HoldContourShape(points: contour, drawRect: drawRect)
                    .fill(routeColor.swatch.opacity(0.92))
            }
        }
            .background {
                HoldContourShape(points: contour, drawRect: drawRect, inset: -2)
                    .fill(Color.white.opacity(0.18))
                    .blur(radius: 6)
            }
            .overlay {
                HoldContourShape(points: contour, drawRect: drawRect)
                    .stroke(routeColor.shadowSwatch.opacity(0.85), lineWidth: 1.6)
            }
            .overlay {
                HoldContourShape(points: contour, drawRect: drawRect)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1.0)
                    .blur(radius: 0.4)
            }
            .overlay {
                HoldContourShape(points: contour, drawRect: drawRect, inset: 4)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
            }
            .shadow(color: routeColor.shadowSwatch.opacity(0.26), radius: 7, x: 0, y: 4)
            .overlay(alignment: .center) {
                if let order = hold.orderIndex {
                    Text("\(order)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(roleAccent.opacity(0.9))
                        )
                }
            }
            .overlay(alignment: .topLeading) {
                if hold.role != .normal {
                    Circle()
                        .fill(roleAccent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                        .padding(6)
                }
            }
    }

    private var metadataBadge: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(grade)
                .font(.system(size: 12, weight: .bold))
            Text(wallAngle.title)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(HoldShapeRenderer.frameColor(for: grade).opacity(0.94))
        )
    }
}

struct HoldContourShape: Shape {
    let points: [CGPoint]
    var drawRect: CGRect? = nil
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let drawingRect = (drawRect ?? rect).insetBy(dx: inset, dy: inset)
        let normalizedPoints = points.isEmpty
            ? RouteGeometry.ellipsePoints(center: CGPoint(x: 0.5, y: 0.5), width: 0.1, height: 0.1)
            : points

        return Path { path in
            guard let first = normalizedPoints.first else { return }
            path.move(to: CGPoint(x: drawingRect.minX + first.x * drawingRect.width, y: drawingRect.minY + first.y * drawingRect.height))
            for point in normalizedPoints.dropFirst() {
                path.addLine(to: CGPoint(x: drawingRect.minX + point.x * drawingRect.width, y: drawingRect.minY + point.y * drawingRect.height))
            }
            path.closeSubpath()
        }
    }
}

@MainActor
enum RouteBlueprintExportStore {
    static func exportPNG(
        holds: [HoldEntity],
        sourceImage: UIImage?,
        wallOutline: [CGPoint],
        grade: String,
        routeColor: RouteColor,
        wallAngle: WallAngle,
        name: String
    ) throws -> URL {
        let content = RouteBlueprintArtwork(
            holds: holds,
            sourceImage: sourceImage,
            wallOutline: wallOutline,
            grade: grade,
            routeColor: routeColor,
            wallAngle: wallAngle
        )
        .frame(width: 1024, height: 1536)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1

        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }

        let filename = sanitizedFilename(name.isEmpty ? "route-blueprint" : name) + ".png"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func sanitizedFilename(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let replaced = text
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        return String(replaced).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
