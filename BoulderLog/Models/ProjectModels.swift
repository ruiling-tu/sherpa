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
    var roleRaw: String
    var orderIndex: Int?
    var note: String
    var holdTypeRaw: String

    var entry: ProjectEntryEntity?

    init(
        id: UUID = UUID(),
        xNormalized: Double,
        yNormalized: Double,
        radius: Double = 0.045,
        role: HoldRole = .normal,
        orderIndex: Int? = nil,
        note: String = "",
        holdType: HoldTypeTag = .crimp,
        entry: ProjectEntryEntity? = nil
    ) {
        self.id = id
        self.xNormalized = xNormalized
        self.yNormalized = yNormalized
        self.radius = radius
        self.roleRaw = role.rawValue
        self.orderIndex = orderIndex
        self.note = note
        self.holdTypeRaw = holdType.rawValue
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
}
