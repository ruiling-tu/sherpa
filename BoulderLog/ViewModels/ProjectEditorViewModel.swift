import Foundation
import SwiftUI

@MainActor
final class NewProjectWizardViewModel: ObservableObject {
    enum Step: Int, CaseIterable, Identifiable {
        case photo
        case crop
        case holds
        case preview
        case metadata
        case save

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .photo: return "Step 1: Photo"
            case .crop: return "Step 2: Crop"
            case .holds: return "Step 3: Holds"
            case .preview: return "Step 4: Preview"
            case .metadata: return "Step 5: Metadata"
            case .save: return "Step 6: Save"
            }
        }
    }

    @Published var step: Step = .photo
    @Published var sourceImageData: Data = Data()
    @Published var croppedImageData: Data = Data()
    @Published var cropRectNormalized = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @Published var draft = EntryDraft()
    @Published var selectedHoldID: UUID?
    @Published var annotateMode = false

    var sourceImage: UIImage? { UIImage(data: sourceImageData) }
    var croppedImage: UIImage? { UIImage(data: croppedImageData) }

    func goNext() {
        guard let currentIndex = Step.allCases.firstIndex(of: step), currentIndex + 1 < Step.allCases.count else { return }
        step = Step.allCases[currentIndex + 1]
    }

    func goBack() {
        guard let currentIndex = Step.allCases.firstIndex(of: step), currentIndex - 1 >= 0 else { return }
        step = Step.allCases[currentIndex - 1]
    }

    func applyCrop() {
        guard let source = sourceImage,
              let cropped = source.cropped(normalizedRect: cropRectNormalized),
              let data = cropped.jpegData(compressionQuality: 0.9) else {
            return
        }
        croppedImageData = data
        draft.croppedImageData = data
    }

    func addHold(at normalizedPoint: CGPoint) {
        guard annotateMode else { return }
        let hold = HoldDraft(xNormalized: normalizedPoint.x, yNormalized: normalizedPoint.y)
        draft.holds.append(hold)
        selectedHoldID = hold.id
    }

    func selectOrAssignOrder(holdID: UUID) {
        selectedHoldID = holdID
        guard annotateMode else { return }
        let maxOrder = draft.holds.compactMap(\.orderIndex).max() ?? 0
        if let idx = draft.holds.firstIndex(where: { $0.id == holdID }) {
            draft.holds[idx].orderIndex = maxOrder + 1
        }
    }

    func moveHold(id: UUID, normalizedPoint: CGPoint) {
        guard let idx = draft.holds.firstIndex(where: { $0.id == id }) else { return }
        draft.holds[idx].xNormalized = normalizedPoint.x
        draft.holds[idx].yNormalized = normalizedPoint.y
    }

    func deleteHold(id: UUID) {
        draft.holds.removeAll { $0.id == id }
        selectedHoldID = nil
    }

    func clearHolds() {
        draft.holds.removeAll()
        selectedHoldID = nil
    }

    func selectedHoldBinding() -> Binding<HoldDraft>? {
        guard let selectedHoldID,
              draft.holds.contains(where: { $0.id == selectedHoldID }) else {
            return nil
        }

        return Binding(
            get: {
                guard let idx = self.draft.holds.firstIndex(where: { $0.id == selectedHoldID }) else {
                    return HoldDraft(xNormalized: 0.5, yNormalized: 0.5)
                }
                return self.draft.holds[idx]
            },
            set: { updated in
                guard let idx = self.draft.holds.firstIndex(where: { $0.id == selectedHoldID }) else { return }
                self.draft.holds[idx] = updated
            }
        )
    }

    func canProceed() -> Bool {
        switch step {
        case .photo: return !sourceImageData.isEmpty
        case .crop: return !croppedImageData.isEmpty
        case .holds: return true
        case .preview: return true
        case .metadata: return !draft.grade.isEmpty
        case .save: return true
        }
    }
}
