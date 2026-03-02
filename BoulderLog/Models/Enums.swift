import Foundation

enum HoldRole: String, Codable, CaseIterable, Identifiable {
    case normal
    case start
    case finish

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum EntryStatus: String, Codable, CaseIterable, Identifiable {
    case attempted
    case sent
    case flashed

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum WallAngle: String, Codable, CaseIterable, Identifiable {
    case slab
    case vert
    case overhang

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum HoldTypeTag: String, Codable, CaseIterable, Identifiable {
    case crimp
    case jug
    case sloper
    case pinch
    case pocket
    case volume
    case chip

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum StyleTag: String, Codable, CaseIterable, Identifiable {
    case dyno
    case balance
    case compression
    case coordination
    case power

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TechniqueTag: String, Codable, CaseIterable, Identifiable {
    case heelHook
    case toeHook
    case lockOff
    case smear
    case mantle
    case openHand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heelHook: return "Heel Hook"
        case .toeHook: return "Toe Hook"
        case .lockOff: return "Lock-off"
        case .openHand: return "Open Hand"
        default: return rawValue.capitalized
        }
    }
}

enum GradeScale {
    static let presets = (0...10).map { "V\($0)" }
}
