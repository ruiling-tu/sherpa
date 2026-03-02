import Foundation
import UIKit

struct HoldCandidate: Identifiable {
    let id = UUID()
    let xNormalized: Double
    let yNormalized: Double
    let confidence: Double
}

protocol HoldDetectionService {
    func detectHolds(image: UIImage) async -> [HoldCandidate]
}

struct ManualHoldDetectionService: HoldDetectionService {
    func detectHolds(image: UIImage) async -> [HoldCandidate] { [] }
}
