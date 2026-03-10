import Foundation
import SwiftData
import UIKit

@MainActor
struct ProjectRepository {
    let context: ModelContext

    func createSession(title: String, date: Date, gym: String) throws {
        context.insert(SessionEntity(title: title, date: date, gym: gym))
        try context.save()
    }

    func deleteSession(_ session: SessionEntity) throws {
        // Explicitly delete entry images before deleting the session tree.
        for entry in session.entries {
            ImageStore.delete(path: entry.imagePath)
            ProblemCardImageStore.invalidate(entryID: entry.id)
        }
        context.delete(session)
        try context.save()
    }

    func createEntry(in session: SessionEntity, draft: EntryDraft) throws {
        let imagePath = try ImageStore.saveJPEG(data: draft.croppedImageData)
        let entryGym = draft.gym.isEmpty ? session.gym : draft.gym
        let entry = ProjectEntryEntity(
            name: draft.name,
            grade: draft.grade,
            status: draft.status,
            attempts: draft.attempts,
            wallAngle: draft.wallAngle,
            notes: draft.notes,
            gym: entryGym,
            createdAt: Date(),
            updatedAt: Date(),
            imagePath: imagePath,
            routeColor: draft.routeColor,
            wallOutline: draft.wallOutline,
            styleTags: draft.styleTags,
            holdTypeTags: draft.holdTypeTags,
            techniqueTags: draft.techniqueTags,
            session: session
        )

        let holds = draft.holds.map {
            HoldEntity(
                xNormalized: $0.xNormalized,
                yNormalized: $0.yNormalized,
                radius: $0.radius,
                widthNormalized: $0.widthNormalized,
                heightNormalized: $0.heightNormalized,
                rotationRadians: $0.rotationRadians,
                role: $0.role,
                orderIndex: $0.orderIndex,
                note: $0.note,
                holdType: $0.holdType,
                contourPoints: $0.contourPoints,
                confidence: $0.confidence,
                entry: entry
            )
        }
        entry.holds.append(contentsOf: holds)

        context.insert(entry)
        try context.save()
    }

    func saveEntry(_ entry: ProjectEntryEntity) throws {
        entry.updatedAt = Date()
        try context.save()
    }

    func deleteEntry(_ entry: ProjectEntryEntity) throws {
        ImageStore.delete(path: entry.imagePath)
        ProblemCardImageStore.invalidate(entryID: entry.id)
        context.delete(entry)
        try context.save()
    }

    func upsertHold(entry: ProjectEntryEntity, hold: HoldEntity) throws {
        if hold.entry == nil {
            hold.entry = entry
            entry.holds.append(hold)
        }
        entry.updatedAt = Date()
        try context.save()
    }

    func deleteHold(_ hold: HoldEntity, from entry: ProjectEntryEntity) throws {
        entry.holds.removeAll { $0.id == hold.id }
        context.delete(hold)
        entry.updatedAt = Date()
        try context.save()
    }
}

enum ImageStore {
    static func saveJPEG(data: Data, compressionQuality: CGFloat = 0.82) throws -> String {
        let uiImage = UIImage(data: data)
        let finalData = uiImage?.jpegData(compressionQuality: compressionQuality) ?? data
        let directory = try imageDirectoryURL()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let name = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(name)
        try finalData.write(to: url, options: .atomic)
        return name
    }

    static func load(path: String) -> UIImage? {
        guard let url = try? imageDirectoryURL().appendingPathComponent(path) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    static func delete(path: String) {
        guard let url = try? imageDirectoryURL().appendingPathComponent(path) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private static func imageDirectoryURL() throws -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return docs.appendingPathComponent("BoulderLogImages", isDirectory: true)
    }
}

struct HoldDraft: Identifiable {
    let id: UUID
    var xNormalized: Double
    var yNormalized: Double
    var radius: Double
    var widthNormalized: Double
    var heightNormalized: Double
    var rotationRadians: Double
    var role: HoldRole
    var orderIndex: Int?
    var note: String
    var holdType: HoldTypeTag
    var contourPoints: [CGPoint]
    var confidence: Double

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
        confidence: Double = 1
    ) {
        self.id = id
        self.xNormalized = xNormalized
        self.yNormalized = yNormalized
        self.radius = radius
        self.widthNormalized = widthNormalized
        self.heightNormalized = heightNormalized
        self.rotationRadians = rotationRadians
        self.role = role
        self.orderIndex = orderIndex
        self.note = note
        self.holdType = holdType
        self.contourPoints = contourPoints.isEmpty
            ? RouteGeometry.ellipsePoints(
                center: CGPoint(x: xNormalized, y: yNormalized),
                width: widthNormalized,
                height: heightNormalized,
                rotation: rotationRadians
            )
            : contourPoints
        self.confidence = confidence
    }
}

struct EntryDraft {
    var name: String = ""
    var grade: String = "V2"
    var routeColor: RouteColor = .yellow
    var status: EntryStatus = .attempted
    var attempts: Int = 1
    var wallAngle: WallAngle = .vert
    var styleTags: [StyleTag] = []
    var holdTypeTags: [HoldTypeTag] = []
    var techniqueTags: [TechniqueTag] = []
    var notes: String = ""
    var gym: String = ""
    var croppedImageData: Data = Data()
    var wallOutline: [CGPoint] = RouteGeometry.defaultWallOutline
    var holds: [HoldDraft] = []
}
