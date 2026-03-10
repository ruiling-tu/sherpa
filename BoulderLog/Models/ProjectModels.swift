import CoreGraphics
import Foundation
import SwiftData

@Model
final class SessionEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var gym: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ProjectEntryEntity.session)
    var entries: [ProjectEntryEntity]

    init(id: UUID = UUID(), title: String, date: Date, gym: String, createdAt: Date = Date(), entries: [ProjectEntryEntity] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.gym = gym
        self.createdAt = createdAt
        self.entries = entries
    }
}

@Model
final class ProjectEntryEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var grade: String
    var statusRaw: String
    var attempts: Int
    var wallAngleRaw: String
    var notes: String
    var gym: String
    var createdAt: Date
    var updatedAt: Date
    var imagePath: String
    var routeColorRaw: String = RouteColor.yellow.rawValue
    var wallOutlineRaw: String = RouteGeometry.encode(points: RouteGeometry.defaultWallOutline)
    var styleTagsRaw: String
    var holdTypeTagsRaw: String
    var techniqueTagsRaw: String

    @Relationship(deleteRule: .cascade, inverse: \HoldEntity.entry)
    var holds: [HoldEntity]

    var session: SessionEntity?

    init(
        id: UUID = UUID(),
        name: String,
        grade: String,
        status: EntryStatus,
        attempts: Int,
        wallAngle: WallAngle,
        notes: String,
        gym: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        imagePath: String,
        routeColor: RouteColor = .yellow,
        wallOutline: [CGPoint] = RouteGeometry.defaultWallOutline,
        styleTags: [StyleTag] = [],
        holdTypeTags: [HoldTypeTag] = [],
        techniqueTags: [TechniqueTag] = [],
        holds: [HoldEntity] = [],
        session: SessionEntity? = nil
    ) {
        self.id = id
        self.name = name
        self.grade = grade
        self.statusRaw = status.rawValue
        self.attempts = attempts
        self.wallAngleRaw = wallAngle.rawValue
        self.notes = notes
        self.gym = gym
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imagePath = imagePath
        self.routeColorRaw = routeColor.rawValue
        self.wallOutlineRaw = RouteGeometry.encode(points: wallOutline)
        self.styleTagsRaw = Self.encodeTags(styleTags)
        self.holdTypeTagsRaw = Self.encodeTags(holdTypeTags)
        self.techniqueTagsRaw = Self.encodeTags(techniqueTags)
        self.holds = holds
        self.session = session
    }

    var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .attempted }
        set { statusRaw = newValue.rawValue }
    }

    var wallAngle: WallAngle {
        get { WallAngle(rawValue: wallAngleRaw) ?? .vert }
        set { wallAngleRaw = newValue.rawValue }
    }

    var routeColor: RouteColor {
        get { RouteColor(rawValue: routeColorRaw) ?? .yellow }
        set { routeColorRaw = newValue.rawValue }
    }

    var wallOutline: [CGPoint] {
        get {
            let decoded = RouteGeometry.decode(points: wallOutlineRaw)
            return decoded.isEmpty ? RouteGeometry.defaultWallOutline : decoded
        }
        set { wallOutlineRaw = RouteGeometry.encode(points: newValue) }
    }

    var styleTags: [StyleTag] {
        get { Self.decodeTags(styleTagsRaw, as: StyleTag.self) }
        set { styleTagsRaw = Self.encodeTags(newValue) }
    }

    var holdTypeTags: [HoldTypeTag] {
        get { Self.decodeTags(holdTypeTagsRaw, as: HoldTypeTag.self) }
        set { holdTypeTagsRaw = Self.encodeTags(newValue) }
    }

    var techniqueTags: [TechniqueTag] {
        get { Self.decodeTags(techniqueTagsRaw, as: TechniqueTag.self) }
        set { techniqueTagsRaw = Self.encodeTags(newValue) }
    }

    private static func encodeTags<T: RawRepresentable>(_ tags: [T]) -> String where T.RawValue == String {
        tags.map { $0.rawValue }.joined(separator: ",")
    }

    private static func decodeTags<T: RawRepresentable>(_ raw: String, as type: T.Type) -> [T] where T.RawValue == String {
        raw.split(separator: ",").compactMap { T(rawValue: String($0)) }
    }
}

@Model
final class HoldEntity {
    @Attribute(.unique) var id: UUID
    var xNormalized: Double
    var yNormalized: Double
    var radius: Double
    var widthNormalized: Double
    var heightNormalized: Double
    var rotationRadians: Double
    var roleRaw: String
    var orderIndex: Int?
    var note: String
    var holdTypeRaw: String
    var contourPointsRaw: String
    var confidence: Double

    var entry: ProjectEntryEntity?

    init(
        id: UUID = UUID(),
        xNormalized: Double,
        yNormalized: Double,
        radius: Double = 0.045,
        widthNormalized: Double = 0.09,
        heightNormalized: Double = 0.09,
        rotationRadians: Double = 0,
        role: HoldRole = .normal,
        orderIndex: Int? = nil,
        note: String = "",
        holdType: HoldTypeTag = .crimp,
        contourPoints: [CGPoint] = [],
        confidence: Double = 1,
        entry: ProjectEntryEntity? = nil
    ) {
        self.id = id
        self.xNormalized = xNormalized
        self.yNormalized = yNormalized
        self.radius = radius
        self.widthNormalized = widthNormalized
        self.heightNormalized = heightNormalized
        self.rotationRadians = rotationRadians
        self.roleRaw = role.rawValue
        self.orderIndex = orderIndex
        self.note = note
        self.holdTypeRaw = holdType.rawValue
        self.contourPointsRaw = RouteGeometry.encode(points: contourPoints)
        self.confidence = confidence
        self.entry = entry
    }

    var role: HoldRole {
        get { HoldRole(rawValue: roleRaw) ?? .normal }
        set { roleRaw = newValue.rawValue }
    }

    var holdType: HoldTypeTag {
        get { HoldTypeTag(rawValue: holdTypeRaw) ?? .crimp }
        set { holdTypeRaw = newValue.rawValue }
    }

    var contourPoints: [CGPoint] {
        get {
            let decoded = RouteGeometry.decode(points: contourPointsRaw)
            if !decoded.isEmpty { return decoded }
            return RouteGeometry.ellipsePoints(
                center: CGPoint(x: xNormalized, y: yNormalized),
                width: widthNormalized,
                height: heightNormalized,
                rotation: rotationRadians
            )
        }
        set { contourPointsRaw = RouteGeometry.encode(points: newValue) }
    }
}

enum RouteGeometry {
    static let defaultWallOutline: [CGPoint] = [
        CGPoint(x: 0.02, y: 0.02),
        CGPoint(x: 0.98, y: 0.02),
        CGPoint(x: 0.98, y: 0.98),
        CGPoint(x: 0.02, y: 0.98)
    ]

    static func encode(points: [CGPoint]) -> String {
        points
            .map { point in
                let x = String(format: "%.5f", point.x)
                let y = String(format: "%.5f", point.y)
                return "\(x),\(y)"
            }
            .joined(separator: "|")
    }

    static func decode(points raw: String) -> [CGPoint] {
        raw
            .split(separator: "|")
            .compactMap { pair -> CGPoint? in
                let parts = pair.split(separator: ",")
                guard parts.count == 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1]) else {
                    return nil
                }
                return CGPoint(x: x, y: y)
            }
    }

    static func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }

    static func ellipsePoints(
        center: CGPoint,
        width: Double,
        height: Double,
        rotation: Double = 0,
        segments: Int = 18
    ) -> [CGPoint] {
        let count = max(segments, 8)
        let cosTheta = cos(rotation)
        let sinTheta = sin(rotation)

        return (0..<count).map { index in
            let angle = (Double(index) / Double(count)) * Double.pi * 2
            let localX = cos(angle) * width * 0.5
            let localY = sin(angle) * height * 0.5
            let rotatedX = localX * cosTheta - localY * sinTheta
            let rotatedY = localX * sinTheta + localY * cosTheta

            return clamped(
                CGPoint(
                    x: center.x + rotatedX,
                    y: center.y + rotatedY
                )
            )
        }
    }

    static func translated(points: [CGPoint], dx: Double, dy: Double) -> [CGPoint] {
        points.map { point in
            clamped(
                CGPoint(
                    x: point.x + dx,
                    y: point.y + dy
                )
            )
        }
    }
}
