import Foundation
import SwiftUI

@MainActor
final class NewProjectWizardViewModel: ObservableObject {
    private let holdDetectionService: HoldDetectionService = LocalRouteDetectionService()
    private var lastAutoExtractionKey: String?

    enum Step: Int, CaseIterable, Identifiable {
        case photo
        case crop
        case holds
        case finish

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .photo: return "Step 1: Add Photo"
            case .crop: return "Step 2: Crop"
            case .holds: return "Step 3: Route Setup"
            case .finish: return "Step 4: Finish"
            }
        }
    }

    @Published var step: Step = .photo
    @Published var sourceImageData: Data = Data()
    @Published var croppedImageData: Data = Data()
    @Published var cropRectNormalized = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @Published var draft = EntryDraft()
    @Published var selectedHoldID: UUID?
    @Published var isExtractingRoute = false
    @Published var isSamplingRouteColor = false
    @Published var routeColorCalibration: RouteColorCalibration?
    @Published var extractionSummary = "Route extraction runs locally and groups holds by the selected route color."

    var sourceImage: UIImage? { UIImage(data: sourceImageData) }
    var croppedImage: UIImage? { UIImage(data: croppedImageData) }

    func goNext() {
        if step == .crop {
            applyCrop(resetGeometry: false)
        }
        guard let currentIndex = Step.allCases.firstIndex(of: step), currentIndex + 1 < Step.allCases.count else { return }
        step = Step.allCases[currentIndex + 1]
    }

    func goBack() {
        guard let currentIndex = Step.allCases.firstIndex(of: step), currentIndex - 1 >= 0 else { return }
        step = Step.allCases[currentIndex - 1]
    }

    func applyCrop(resetGeometry: Bool = true) {
        guard let source = sourceImage,
              let cropped = source.cropped(normalizedRect: cropRectNormalized),
              let data = cropped.jpegData(compressionQuality: 0.9) else {
            return
        }

        croppedImageData = data
        draft.croppedImageData = data
        if resetGeometry {
            draft.wallOutline = RouteGeometry.defaultWallOutline
            draft.holds.removeAll()
            selectedHoldID = nil
            lastAutoExtractionKey = nil
            routeColorCalibration = nil
            isSamplingRouteColor = false
        }
        extractionSummary = "Pick the route color. If needed, tap Sample and tap one known hold to calibrate extraction."
    }

    func addHold(at normalizedPoint: CGPoint) {
        let hold = HoldDraft(
            xNormalized: normalizedPoint.x,
            yNormalized: normalizedPoint.y,
            radius: 0.05,
            widthNormalized: 0.1,
            heightNormalized: 0.08,
            contourPoints: RouteGeometry.ellipsePoints(
                center: normalizedPoint,
                width: 0.1,
                height: 0.08
            ),
            confidence: 0.35
        )
        draft.holds.append(hold)
        selectedHoldID = hold.id
    }

    func addHold(contourPoints: [CGPoint]) {
        let clamped = contourPoints.map(RouteGeometry.clamped)
        guard clamped.count >= 6 else { return }

        let xs = clamped.map(\.x)
        let ys = clamped.map(\.y)
        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return
        }

        let center = CGPoint(
            x: clamped.reduce(0) { $0 + $1.x } / Double(clamped.count),
            y: clamped.reduce(0) { $0 + $1.y } / Double(clamped.count)
        )

        let hold = HoldDraft(
            xNormalized: center.x,
            yNormalized: center.y,
            radius: max(maxX - minX, maxY - minY) * 0.5,
            widthNormalized: max(0.03, maxX - minX),
            heightNormalized: max(0.03, maxY - minY),
            role: .normal,
            contourPoints: clamped,
            confidence: 0.55
        )
        draft.holds.append(hold)
        selectedHoldID = hold.id
    }

    func selectOrAssignOrder(holdID: UUID) {
        selectedHoldID = holdID
    }

    func moveHold(id: UUID, normalizedPoint: CGPoint) {
        guard let index = draft.holds.firstIndex(where: { $0.id == id }) else { return }

        let current = draft.holds[index]
        let dx = normalizedPoint.x - current.xNormalized
        let dy = normalizedPoint.y - current.yNormalized
        draft.holds[index].xNormalized = normalizedPoint.x
        draft.holds[index].yNormalized = normalizedPoint.y
        draft.holds[index].contourPoints = RouteGeometry.translated(points: current.contourPoints, dx: dx, dy: dy)
    }

    func deleteHold(id: UUID) {
        draft.holds.removeAll { $0.id == id }
        if selectedHoldID == id {
            selectedHoldID = draft.holds.first?.id
        }
    }

    func updateHoldContour(id: UUID, contourPoints: [CGPoint]) {
        guard let index = draft.holds.firstIndex(where: { $0.id == id }),
              contourPoints.count >= 6 else { return }

        let clamped = contourPoints.map(RouteGeometry.clamped)
        let xs = clamped.map(\.x)
        let ys = clamped.map(\.y)
        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return
        }

        let center = CGPoint(
            x: clamped.reduce(0) { $0 + $1.x } / Double(clamped.count),
            y: clamped.reduce(0) { $0 + $1.y } / Double(clamped.count)
        )

        draft.holds[index].contourPoints = clamped
        draft.holds[index].xNormalized = center.x
        draft.holds[index].yNormalized = center.y
        draft.holds[index].widthNormalized = max(0.03, maxX - minX)
        draft.holds[index].heightNormalized = max(0.03, maxY - minY)
        draft.holds[index].radius = max(draft.holds[index].widthNormalized, draft.holds[index].heightNormalized) * 0.5
    }

    func clearHolds() {
        draft.holds.removeAll()
        selectedHoldID = nil
    }

    func beginRouteColorSampling() {
        isSamplingRouteColor = true
        extractionSummary = "Tap one hold from the route to calibrate the selected color, then extraction will rerun."
    }

    func applyRouteColorCalibration(at point: CGPoint) {
        routeColorCalibration = RouteColorCalibration(point: point)
        isSamplingRouteColor = false
        clearHolds()
        lastAutoExtractionKey = nil
    }

    func updateWallPoint(index: Int, to point: CGPoint) {
        guard draft.wallOutline.indices.contains(index) else { return }
        draft.wallOutline[index] = RouteGeometry.clamped(point)
    }

    func maybeAutoExtractRoute() async {
        let key = autoExtractionKey
        guard !key.isEmpty,
              key != lastAutoExtractionKey,
              draft.holds.isEmpty else {
            return
        }

        await detectRoute(force: true)
        lastAutoExtractionKey = key
    }

    func detectRoute(force: Bool) async {
        guard let image = croppedImage else { return }
        guard !isExtractingRoute else { return }
        if !force, !draft.holds.isEmpty { return }

        isExtractingRoute = true
        extractionSummary = "Extracting \(draft.routeColor.title.lowercased()) holds from the cropped image..."

        let result = await holdDetectionService.detectRoute(
            in: image,
            routeColor: draft.routeColor,
            calibration: routeColorCalibration
        )
        let highest = result.holds.min(by: { $0.yNormalized < $1.yNormalized })
        let lowest = result.holds.max(by: { $0.yNormalized < $1.yNormalized })

        draft.wallOutline = result.wallOutline
        draft.holds = result.holds.map { candidate in
            let role: HoldRole
            if candidate.id == lowest?.id {
                role = .start
            } else if candidate.id == highest?.id, highest?.id != lowest?.id {
                role = .finish
            } else {
                role = .normal
            }

            return HoldDraft(
                id: candidate.id,
                xNormalized: candidate.xNormalized,
                yNormalized: candidate.yNormalized,
                radius: max(candidate.widthNormalized, candidate.heightNormalized) * 0.5,
                widthNormalized: candidate.widthNormalized,
                heightNormalized: candidate.heightNormalized,
                rotationRadians: candidate.rotationRadians,
                role: role,
                holdType: .crimp,
                contourPoints: candidate.contourPoints,
                confidence: candidate.confidence
            )
        }

        selectedHoldID = draft.holds.first?.id
        extractionSummary = draft.holds.isEmpty
            ? "No clear holds were found. Try tightening the crop, changing the route color, or sampling one known hold."
            : "Detected \(draft.holds.count) holds. Drag holds or wall corners, delete bad detections, or redraw a hold outline."
        isExtractingRoute = false
    }

    func selectedHoldBinding() -> Binding<HoldDraft>? {
        guard let selectedHoldID,
              draft.holds.contains(where: { $0.id == selectedHoldID }) else {
            return nil
        }

        return Binding(
            get: {
                guard let index = self.draft.holds.firstIndex(where: { $0.id == selectedHoldID }) else {
                    return HoldDraft(xNormalized: 0.5, yNormalized: 0.5)
                }
                return self.draft.holds[index]
            },
            set: { updated in
                guard let index = self.draft.holds.firstIndex(where: { $0.id == selectedHoldID }) else { return }
                self.draft.holds[index] = updated
            }
        )
    }

    func canProceed() -> Bool {
        switch step {
        case .photo:
            return !sourceImageData.isEmpty
        case .crop:
            return !croppedImageData.isEmpty
        case .holds:
            return !croppedImageData.isEmpty && !isExtractingRoute
        case .finish:
            return !draft.grade.isEmpty
        }
    }

    private var autoExtractionKey: String {
        guard !croppedImageData.isEmpty else { return "" }
        let calibrationKey = routeColorCalibration.map {
            "\(String(format: "%.3f", $0.point.x))-\(String(format: "%.3f", $0.point.y))"
        } ?? "none"
        return "\(draft.routeColor.rawValue)-\(croppedImageData.count)-\(calibrationKey)"
    }
}
