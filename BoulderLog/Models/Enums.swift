import Foundation
import SwiftUI

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

enum RouteColor: String, Codable, CaseIterable, Identifiable {
    case yellow
    case green
    case red
    case blue
    case black
    case white
    case purple
    case orange
    case pink
    case brown
    case gray
    case teal

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var promptLabel: String {
        switch self {
        case .gray: return "gray"
        default: return rawValue
        }
    }

    var swatch: Color {
        switch self {
        case .yellow: return Color(hex: "D8B020")
        case .green: return Color(hex: "4D9E59")
        case .red: return Color(hex: "C7473A")
        case .blue: return Color(hex: "4E78B8")
        case .black: return Color(hex: "2F2F32")
        case .white: return Color(hex: "F4F2ED")
        case .purple: return Color(hex: "8A5AA8")
        case .orange: return Color(hex: "D67E32")
        case .pink: return Color(hex: "D77FB1")
        case .brown: return Color(hex: "7A5638")
        case .gray: return Color(hex: "8E9198")
        case .teal: return Color(hex: "3C9B9A")
        }
    }

    var shadowSwatch: Color {
        switch self {
        case .white: return Color(hex: "D9D4CD")
        case .yellow: return Color(hex: "9E7F11")
        case .green: return Color(hex: "2E6338")
        case .red: return Color(hex: "7F2A22")
        case .blue: return Color(hex: "2F4D7F")
        case .black: return Color(hex: "111214")
        case .purple: return Color(hex: "56356B")
        case .orange: return Color(hex: "8A4B17")
        case .pink: return Color(hex: "9B4D7C")
        case .brown: return Color(hex: "533520")
        case .gray: return Color(hex: "5E6066")
        case .teal: return Color(hex: "235E5D")
        }
    }
}
