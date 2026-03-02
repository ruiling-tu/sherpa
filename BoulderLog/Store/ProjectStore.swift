import Foundation
import SwiftData
import UIKit

@MainActor
enum SeedDataLoader {
    static func loadIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<SessionEntity>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let session = SessionEntity(title: "Friday Circuit", date: Date().addingTimeInterval(-86400 * 3), gym: "Sherpa Gym")
        let sampleImage = UIImage(systemName: "mountain.2.fill")?.withTintColor(.orange, renderingMode: .alwaysOriginal)
        let data = sampleImage?.jpegData(compressionQuality: 0.85) ?? Data()
        let imagePath = (try? ImageStore.saveJPEG(data: data)) ?? ""

        let entry = ProjectEntryEntity(
            name: "Orange Compression",
            grade: "V5",
            status: .attempted,
            attempts: 7,
            wallAngle: .overhang,
            notes: "Falls at third move when cutting feet.",
            gym: "Sherpa Gym",
            imagePath: imagePath,
            styleTags: [.compression],
            holdTypeTags: [.sloper],
            techniqueTags: [.toeHook],
            session: session
        )

        let h1 = HoldEntity(xNormalized: 0.2, yNormalized: 0.8, role: .start, orderIndex: 1, holdType: .sloper, entry: entry)
        let h2 = HoldEntity(xNormalized: 0.45, yNormalized: 0.55, role: .normal, orderIndex: 2, holdType: .sloper, entry: entry)
        let h3 = HoldEntity(xNormalized: 0.72, yNormalized: 0.2, role: .finish, orderIndex: 3, holdType: .jug, entry: entry)

        entry.holds.append(contentsOf: [h1, h2, h3])

        context.insert(session)
        context.insert(entry)
        try? context.save()
    }
}
