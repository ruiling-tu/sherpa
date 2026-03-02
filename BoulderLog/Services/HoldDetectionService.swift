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

struct HoldRenderSpec: Codable, Hashable {
    let id: UUID
    let x: Double
    let y: Double
    let radius: Double
    let role: HoldRole
    let orderIndex: Int?
}

enum AICardSettings {
    struct ModelPreset: Identifiable {
        let id: String
        let title: String
        let description: String
    }

    static let enabledKey = "ai_problem_card_enabled"
    static let apiKeyKey = "openai_api_key"
    static let modelKey = "openai_image_model"
    static let bundledDefaultAPIKey = ""
    static let defaultModel = "gpt-image-1-mini"
    static let fallbackModel = "gpt-image-1"
    static let modelPresets: [ModelPreset] = [
        ModelPreset(id: "gpt-image-1-mini", title: "Fast", description: "Lower latency and cost."),
        ModelPreset(id: "gpt-image-1", title: "Balanced", description: "More detail and consistency.")
    ]

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var apiKey: String {
        let stored = UserDefaults.standard.string(forKey: apiKeyKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stored.isEmpty { return stored }
        let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !env.isEmpty { return env }
        return bundledDefaultAPIKey
    }

    static var model: String {
        let stored = UserDefaults.standard.string(forKey: modelKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultModel : stored
    }

    static func title(for model: String) -> String {
        modelPresets.first(where: { $0.id == model })?.title ?? model
    }

    static func quality(for model: String) -> String {
        model == defaultModel ? "low" : "medium"
    }
}

enum ProblemCardPromptFactory {
    static func prompt(grade: String, holds: [HoldRenderSpec]) -> String {
        let compactJSON = holdsJSONString(holds)
        let annotationInstruction: String = {
            if holds.isEmpty {
                return "No explicit route annotations were provided. Extract and illustrate all visible holds on the wall in a clean, readable layout."
            }
            return """
            Annotated route holds are provided via JSON and marker guides.
            Include all visible holds on the wall:
            - highlighted route holds: these annotated holds only
            - non-route holds: include as de-emphasized context shapes
            Preserve annotated roles (start/finish/normal) and sequence when present.
            """
        }()
        return """
        Create a collectible 2D climbing route card from this wall image.
        \(annotationInstruction)
        Preserve wall geometry and relative hold positions.
        Render in a stable house style:
        - flat vector-like illustration
        - soft rounded hold silhouettes
        - muted warm palette (#EDE9E2 background, route holds in warm red range, context holds muted gray/tan)
        - minimal shadows, no textures, no photo detail, no text labels
        - consistent framing and spacing like one card series
        Include subtle difficulty frame accents for grade \(grade), but keep them understated.
        Never output realistic wall texture or noisy details.
        Hold metadata JSON (normalized coordinates): \(compactJSON)
        """
    }

    static func signature(grade: String, holds: [HoldRenderSpec]) -> String {
        let sorted = holds.sorted { ($0.orderIndex ?? 999, $0.id.uuidString) < ($1.orderIndex ?? 999, $1.id.uuidString) }
        let base = sorted.map {
            "\($0.id.uuidString)|\(round6($0.x))|\(round6($0.y))|\(round6($0.radius))|\($0.role.rawValue)|\($0.orderIndex ?? -1)"
        }.joined(separator: ";")
        return stableHash("\(grade)|\(base)")
    }

    private static func holdsJSONString(_ holds: [HoldRenderSpec]) -> String {
        let payload = holds.sorted { ($0.orderIndex ?? 999, $0.id.uuidString) < ($1.orderIndex ?? 999, $1.id.uuidString) }
        guard let data = try? JSONEncoder().encode(payload),
              let raw = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return raw
    }

    private static func round6(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private static func stableHash(_ text: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(hash, radix: 16)
    }
}

enum ProblemCardImageStore {
    private static let directoryName = "BoulderLogProblemCards"

    static func load(entryID: UUID, signature: String) -> UIImage? {
        let defaults = UserDefaults.standard
        let key = signatureKey(for: entryID)
        let storedSignature = defaults.string(forKey: key)
        guard storedSignature == signature else {
            if storedSignature != nil {
                defaults.removeObject(forKey: key)
                deleteFile(entryID: entryID)
            }
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL(entryID: entryID)) else { return nil }
        return UIImage(data: data)
    }

    static func save(image: UIImage, entryID: UUID, signature: String) {
        guard let data = image.pngData() else { return }
        do {
            let dir = try directoryURL()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try data.write(to: fileURL(entryID: entryID), options: .atomic)
            UserDefaults.standard.set(signature, forKey: signatureKey(for: entryID))
        } catch {
            // Keep failure silent; deterministic renderer remains available.
        }
    }

    static func invalidate(entryID: UUID) {
        UserDefaults.standard.removeObject(forKey: signatureKey(for: entryID))
        deleteFile(entryID: entryID)
    }

    static func clearAll() {
        do {
            let dir = try directoryURL()
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            for url in files {
                try? FileManager.default.removeItem(at: url)
            }
        } catch {
            // No-op if cache folder does not exist.
        }
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("problem_card_signature_") {
            defaults.removeObject(forKey: key)
        }
    }

    private static func deleteFile(entryID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(entryID: entryID))
    }

    private static func fileURL(entryID: UUID) -> URL {
        (try? directoryURL().appendingPathComponent("\(entryID.uuidString).png")) ?? URL(filePath: NSTemporaryDirectory()).appendingPathComponent("\(entryID.uuidString).png")
    }

    private static func signatureKey(for entryID: UUID) -> String {
        "problem_card_signature_\(entryID.uuidString)"
    }

    private static func directoryURL() throws -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return docs.appendingPathComponent(directoryName, isDirectory: true)
    }
}

protocol ProblemCardGenerationService {
    func generateCard(sourceImage: UIImage, holds: [HoldRenderSpec], grade: String) async throws -> UIImage
}

struct OpenAIProblemCardService: ProblemCardGenerationService {
    func generateCard(sourceImage: UIImage, holds: [HoldRenderSpec], grade: String) async throws -> UIImage {
        let apiKey = AICardSettings.apiKey
        guard !apiKey.isEmpty else { throw URLError(.userAuthenticationRequired) }

        let guidance = renderGuidanceImage(sourceImage: sourceImage, holds: holds)
        guard let imageData = guidance.pngData() else { throw URLError(.cannotDecodeContentData) }
        let prompt = ProblemCardPromptFactory.prompt(grade: grade, holds: holds)
        do {
            return try await generateImage(
                apiKey: apiKey,
                model: AICardSettings.model,
                prompt: prompt,
                imageData: imageData
            )
        } catch {
            // If a newer lightweight model alias is unavailable for this endpoint, retry with stable fallback.
            if AICardSettings.model != AICardSettings.fallbackModel {
                return try await generateImage(
                    apiKey: apiKey,
                    model: AICardSettings.fallbackModel,
                    prompt: prompt,
                    imageData: imageData
                )
            }
            throw error
        }
    }

    private func generateImage(apiKey: String, model: String, prompt: String, imageData: Data) async throws -> UIImage {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(boundary: boundary, model: model, prompt: prompt, imageData: imageData)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "OpenAI image request failed."
            throw NSError(domain: "OpenAIProblemCardService", code: 1, userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        let decoded = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
        guard let item = decoded.data.first else { throw URLError(.badServerResponse) }

        if let b64 = item.b64_json, let imgData = Data(base64Encoded: b64), let image = UIImage(data: imgData) {
            return image
        }

        if let urlString = item.url, let url = URL(string: urlString) {
            let (imgData, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: imgData) {
                return image
            }
        }

        throw URLError(.cannotDecodeContentData)
    }

    private func buildMultipartBody(boundary: String, model: String, prompt: String, imageData: Data) -> Data {
        var body = Data()
        let quality = AICardSettings.quality(for: model)

        appendField("model", value: model, to: &body, boundary: boundary)
        appendField("prompt", value: prompt, to: &body, boundary: boundary)
        appendField("size", value: "1024x1024", to: &body, boundary: boundary)
        appendField("quality", value: quality, to: &body, boundary: boundary)
        appendField("n", value: "1", to: &body, boundary: boundary)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"route.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private func appendField(_ name: String, value: String, to body: inout Data, boundary: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func renderGuidanceImage(sourceImage: UIImage, holds: [HoldRenderSpec]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: sourceImage.size)
        return renderer.image { context in
            sourceImage.draw(in: CGRect(origin: .zero, size: sourceImage.size))

            for hold in holds {
                let center = CGPoint(x: sourceImage.size.width * hold.x, y: sourceImage.size.height * hold.y)
                let radius = max(10, CGFloat(hold.radius) * min(sourceImage.size.width, sourceImage.size.height))
                let ringRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

                let strokeColor: UIColor
                switch hold.role {
                case .start: strokeColor = UIColor(red: 0.56, green: 0.74, blue: 0.53, alpha: 1)
                case .finish: strokeColor = UIColor(red: 0.86, green: 0.55, blue: 0.26, alpha: 1)
                case .normal: strokeColor = UIColor(red: 0.96, green: 0.24, blue: 0.21, alpha: 1)
                }

                context.cgContext.setStrokeColor(strokeColor.cgColor)
                context.cgContext.setFillColor(strokeColor.withAlphaComponent(0.14).cgColor)
                context.cgContext.setLineWidth(hold.role == .finish ? 4 : 3)
                context.cgContext.fillEllipse(in: ringRect)
                context.cgContext.strokeEllipse(in: ringRect)

                if let order = hold.orderIndex {
                    let text = "\(order)" as NSString
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: max(11, radius * 0.8), weight: .medium),
                        .foregroundColor: UIColor.white
                    ]
                    let textSize = text.size(withAttributes: attrs)
                    let textRect = CGRect(
                        x: center.x - textSize.width / 2,
                        y: center.y - textSize.height / 2,
                        width: textSize.width,
                        height: textSize.height
                    )
                    text.draw(in: textRect, withAttributes: attrs)
                }
            }
        }
    }

    private struct OpenAIImageResponse: Decodable {
        struct Item: Decodable {
            let b64_json: String?
            let url: String?
        }
        let data: [Item]
    }
}

actor ProblemCardImagePipeline {
    static let shared = ProblemCardImagePipeline()

    private let service: ProblemCardGenerationService = OpenAIProblemCardService()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func loadOrGenerate(entryID: UUID, signature: String, sourceImage: UIImage, holds: [HoldRenderSpec], grade: String) async -> UIImage? {
        if let cached = ProblemCardImageStore.load(entryID: entryID, signature: signature) {
            return cached
        }

        guard AICardSettings.isEnabled, !AICardSettings.apiKey.isEmpty else { return nil }
        let key = "\(entryID.uuidString)-\(signature)"

        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task<UIImage?, Never> {
            do {
                let image = try await service.generateCard(sourceImage: sourceImage, holds: holds, grade: grade)
                ProblemCardImageStore.save(image: image, entryID: entryID, signature: signature)
                return image
            } catch {
                return nil
            }
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }
}
