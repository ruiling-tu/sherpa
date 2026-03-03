import Foundation
import UIKit
import os.log

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

    static let requestTimeoutSeconds: TimeInterval = 35
    static let maxUploadDimension: CGFloat = 1408
    static let fallbackUploadDimension: CGFloat = 1152
    static let uploadJPEGQuality: CGFloat = 0.9
    static let fallbackUploadJPEGQuality: CGFloat = 0.82
    static let maxUploadJPEGBytes: Int = 2_800_000
    static let fallbackMaxUploadJPEGBytes: Int = 1_900_000
    static let maxUploadPNGBytes: Int = 4_000_000
    static let fallbackMaxUploadPNGBytes: Int = 2_500_000
    static let preferredOutputSize = "1024x1536"
    static let fallbackOutputSize = "1024x1024"

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

    static func quality(for _: String) -> String { "medium" }
}

enum ProblemCardPromptFactory {
    private static let promptVersion = "route-color-fidelity-v1"

    static func prompt(grade: String, routeColor: RouteColor) -> String {
        return """
        Generate a collectible 2D climbing problem card from this wall photo.
        Route color selected by user: \(routeColor.promptLabel)
        This is the only color that belongs to the route.
        Manual annotation data is not provided and must not be inferred.
        Ignore any marker-like circles, numbers, or overlays if they appear in the image.
        They are UI artifacts and are not route semantics.

        Priority order:
        1) Extremely high spatial fidelity (most important)
        2) High hold-shape and hold-size fidelity
        3) Clean simplified card styling

        Hard constraints:
        - Extract only holds of the selected route color (\(routeColor.promptLabel)).
        - Do not include holds from other colors, wall features, tapes, labels, logos, bolts, or background artifacts.
        - If a hold color is ambiguous, exclude it.
        - Preserve each included hold's silhouette and geometry: contour, corners, concavities, and footprint area.
        - Preserve relative hold sizes exactly (large vs small differences must remain true).
        - Preserve spatial layout exactly: same relative positions, spacing, and movement flow.
        - Do not warp, mirror, rotate, reorder, merge, split, or invent holds.

        Visual style requirements:
        - simplified abstract rendering with clean edges and subtle depth
        - geometry must remain faithful; simplify texture only
        - solid warm background color #F4F1EA
        - prioritize geometric accuracy over creative style
        - no text labels, no letters, no numbers
        - no arrows, no path lines, no guides
        - full-bleed composition that fills the canvas without black bars or borders

        Grade context: \(grade)
        """
    }

    static func signature(grade: String, routeColor: RouteColor) -> String {
        stableHash("\(promptVersion)|\(grade)|\(routeColor.rawValue)")
    }

    static func cacheSignature(grade: String, routeColor: RouteColor, model: String) -> String {
        "\(signature(grade: grade, routeColor: routeColor))-\(model)"
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
    static let previewDraftEntryID = UUID(uuidString: "00000000-0000-0000-0000-00000000D031")!

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
            // Keep failure silent; caller has fallback behavior.
        }
    }

    static func loadAny(entryID: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL(entryID: entryID)) else { return nil }
        return UIImage(data: data)
    }

    static func cloneCachedCard(from sourceEntryID: UUID, to targetEntryID: UUID, signature: String) {
        guard let image = load(entryID: sourceEntryID, signature: signature) else { return }
        save(image: image, entryID: targetEntryID, signature: signature)
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
    func generateCard(sourceImage: UIImage, grade: String, routeColor: RouteColor) async throws -> UIImage
}

struct OpenAIProblemCardService: ProblemCardGenerationService {
    private let logger = Logger(subsystem: "BoulderLog", category: "ProblemCardGeneration")

    private enum UploadProfile {
        case fidelity
        case fallback
    }

    private struct UploadImagePayload {
        let data: Data
        let filename: String
        let contentType: String
    }

    func generateCard(sourceImage: UIImage, grade: String, routeColor: RouteColor) async throws -> UIImage {
        let apiKey = AICardSettings.apiKey
        guard !apiKey.isEmpty else {
            throw NSError(domain: "ProblemCard", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing API key."])
        }
        let deadline = Date().addingTimeInterval(AICardSettings.requestTimeoutSeconds)

        let prepStart = Date()
        let uploadPayload = try await Task.detached(priority: .utility) {
            try prepareGuidanceUploadPayload(sourceImage: sourceImage, profile: .fidelity)
        }.value
        let prepDuration = Date().timeIntervalSince(prepStart)
        guard deadline.timeIntervalSinceNow > 0 else {
            throw timeoutError()
        }

        let prompt = ProblemCardPromptFactory.prompt(grade: grade, routeColor: routeColor)
        let networkStart = Date()

        func remainingTimeout() throws -> TimeInterval {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0.6 else {
                throw timeoutError()
            }
            return remaining
        }

        func hasRetryBudget(minimumSeconds: TimeInterval = 8) -> Bool {
            deadline.timeIntervalSinceNow >= minimumSeconds
        }

        func generateWithSmartSize(model: String, payload: UploadImagePayload) async throws -> UIImage {
            do {
                return try await generateImage(
                    apiKey: apiKey,
                    model: model,
                    prompt: prompt,
                    uploadPayload: payload,
                    outputSize: AICardSettings.preferredOutputSize,
                    timeout: try remainingTimeout()
                )
            } catch {
                let message = error.localizedDescription.lowercased()
                let shouldFallbackSize = (message.contains("size") || message.contains("invalid")) && !isTimeoutError(error)
                if shouldFallbackSize, hasRetryBudget(minimumSeconds: 4) {
                    return try await generateImage(
                        apiKey: apiKey,
                        model: model,
                        prompt: prompt,
                        uploadPayload: payload,
                        outputSize: AICardSettings.fallbackOutputSize,
                        timeout: try remainingTimeout()
                    )
                }
                throw error
            }
        }

        func generateWithModelAndPayload(model: String, payload: UploadImagePayload) async throws -> UIImage {
            let image = try await generateWithSmartSize(model: model, payload: payload)
            logger.info("problem_card_generation_success model=\(model, privacy: .public) prep_ms=\(Int(prepDuration * 1000)) net_ms=\(Int(Date().timeIntervalSince(networkStart) * 1000)) bytes=\(payload.data.count)")
            return image
        }

        do {
            return try await generateWithModelAndPayload(model: AICardSettings.model, payload: uploadPayload)
        } catch {
            if isTimeoutError(error) {
                logger.error("problem_card_generation_timeout model=\(AICardSettings.model, privacy: .public) prep_ms=\(Int(prepDuration * 1000)) bytes=\(uploadPayload.data.count)")
                throw timeoutError()
            }

            if shouldRetryWithFallbackPayload(error), hasRetryBudget() {
                logger.info("problem_card_generation_retry_light_payload prep_ms=\(Int(prepDuration * 1000))")
                let fallbackPayload = try await Task.detached(priority: .utility) {
                    try prepareGuidanceUploadPayload(sourceImage: sourceImage, profile: .fallback)
                }.value
                return try await generateWithModelAndPayload(model: AICardSettings.model, payload: fallbackPayload)
            }

            if AICardSettings.model != AICardSettings.fallbackModel, hasRetryBudget(), !isTimeoutError(error) {
                logger.info("problem_card_generation_retry_fallback prep_ms=\(Int(prepDuration * 1000))")
                let fallbackPayload = try await Task.detached(priority: .utility) {
                    try prepareGuidanceUploadPayload(sourceImage: sourceImage, profile: .fallback)
                }.value
                let image = try await generateWithSmartSize(model: AICardSettings.fallbackModel, payload: fallbackPayload)
                logger.info("problem_card_generation_success_fallback net_ms=\(Int(Date().timeIntervalSince(networkStart) * 1000)) bytes=\(fallbackPayload.data.count)")
                return image
            }
            logger.error("problem_card_generation_failed error=\(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func generateImage(
        apiKey: String,
        model: String,
        prompt: String,
        uploadPayload: UploadImagePayload,
        outputSize: String,
        timeout: TimeInterval
    ) async throws -> UIImage {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(
            boundary: boundary,
            model: model,
            prompt: prompt,
            uploadPayload: uploadPayload,
            outputSize: outputSize
        )

        let (data, response) = try await dataWithTimeout(request: request, timeout: timeout)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "OpenAI image request failed."
            throw NSError(domain: "OpenAIProblemCardService", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let decoded = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
        guard let item = decoded.data.first else {
            throw NSError(domain: "OpenAIProblemCardService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No image data in response."])
        }

        if let b64 = item.b64_json, let imgData = Data(base64Encoded: b64), let image = UIImage(data: imgData) {
            return image
        }

        if let urlString = item.url, let url = URL(string: urlString) {
            var imageRequest = URLRequest(url: url)
            imageRequest.timeoutInterval = max(2, min(8, timeout * 0.5))
            let (imgData, _) = try await URLSession.shared.data(for: imageRequest)
            if let image = UIImage(data: imgData) {
                return image
            }
        }

        throw NSError(domain: "OpenAIProblemCardService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to decode generated image."])
    }

    private func dataWithTimeout(request: URLRequest, timeout: TimeInterval) async throws -> (Data, URLResponse) {
        try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask {
                try await URLSession.shared.data(for: request)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NSError(domain: "OpenAIProblemCardService", code: 408, userInfo: [NSLocalizedDescriptionKey: "Generation timed out. Please retry."])
            }

            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw NSError(domain: "OpenAIProblemCardService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response from generation task."])
            }
            return first
        }
    }

    private func buildMultipartBody(
        boundary: String,
        model: String,
        prompt: String,
        uploadPayload: UploadImagePayload,
        outputSize: String
    ) -> Data {
        var body = Data()
        let quality = AICardSettings.quality(for: model)

        appendField("model", value: model, to: &body, boundary: boundary)
        appendField("prompt", value: prompt, to: &body, boundary: boundary)
        appendField("size", value: outputSize, to: &body, boundary: boundary)
        appendField("quality", value: quality, to: &body, boundary: boundary)
        appendField("n", value: "1", to: &body, boundary: boundary)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(uploadPayload.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(uploadPayload.contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(uploadPayload.data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private func appendField(_ name: String, value: String, to body: inout Data, boundary: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func prepareGuidanceUploadPayload(sourceImage: UIImage, profile: UploadProfile) throws -> UploadImagePayload {
        let maxDimension: CGFloat
        let jpegQuality: CGFloat
        let maxJPEGBytes: Int
        let maxPNGBytes: Int
        switch profile {
        case .fidelity:
            maxDimension = AICardSettings.maxUploadDimension
            jpegQuality = AICardSettings.uploadJPEGQuality
            maxJPEGBytes = AICardSettings.maxUploadJPEGBytes
            maxPNGBytes = AICardSettings.maxUploadPNGBytes
        case .fallback:
            maxDimension = AICardSettings.fallbackUploadDimension
            jpegQuality = AICardSettings.fallbackUploadJPEGQuality
            maxJPEGBytes = AICardSettings.fallbackMaxUploadJPEGBytes
            maxPNGBytes = AICardSettings.fallbackMaxUploadPNGBytes
        }

        let normalized = downscaled(image: sourceImage, maxDimension: maxDimension)
        let guided = normalized

        if let jpeg = compressedJPEGData(image: guided, preferredQuality: jpegQuality, maxBytes: maxJPEGBytes) {
            return UploadImagePayload(data: jpeg, filename: "route.jpg", contentType: "image/jpeg")
        }

        if let png = guided.pngData(), png.count <= maxPNGBytes {
            return UploadImagePayload(data: png, filename: "route.png", contentType: "image/png")
        }

        guard let jpeg = guided.jpegData(compressionQuality: max(0.68, jpegQuality - 0.18)) else {
            throw NSError(domain: "OpenAIProblemCardService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to build upload payload."])
        }
        return UploadImagePayload(data: jpeg, filename: "route.jpg", contentType: "image/jpeg")
    }

    private func compressedJPEGData(image: UIImage, preferredQuality: CGFloat, maxBytes: Int) -> Data? {
        let minQuality: CGFloat = 0.66

        func encode(_ source: UIImage, startQuality: CGFloat) -> Data? {
            var quality = startQuality
            var smallest: Data?

            while quality >= minQuality {
                guard let data = source.jpegData(compressionQuality: quality) else { break }
                if smallest == nil || data.count < smallest!.count {
                    smallest = data
                }
                if data.count <= maxBytes {
                    return data
                }
                quality -= 0.06
            }
            return smallest
        }

        if let preferred = encode(image, startQuality: preferredQuality), preferred.count <= maxBytes {
            return preferred
        }

        let reducedMaxDimension = max(960, max(image.size.width, image.size.height) * 0.84)
        let reduced = downscaled(image: image, maxDimension: reducedMaxDimension)
        return encode(reduced, startQuality: min(preferredQuality, 0.82))
    }

    private func isTimeoutError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == "OpenAIProblemCardService", ns.code == 408 {
            return true
        }
        return ns.localizedDescription.lowercased().contains("timed out")
    }

    private func shouldRetryWithFallbackPayload(_ error: Error) -> Bool {
        if isTimeoutError(error) { return false }
        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("413")
            || message.contains("payload")
            || message.contains("too large")
            || message.contains("invalid image")
            || message.contains("unsupported image")
    }

    private func timeoutError() -> NSError {
        NSError(
            domain: "OpenAIProblemCardService",
            code: 408,
            userInfo: [NSLocalizedDescriptionKey: "Generation timed out. Please retry."]
        )
    }

    private func downscaled(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let targetSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
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

enum ProblemCardPipelineResult {
    case ready(UIImage)
    case failed(String)
}

actor ProblemCardImagePipeline {
    static let shared = ProblemCardImagePipeline()

    private let service: ProblemCardGenerationService = OpenAIProblemCardService()
    private var inFlight: [String: Task<ProblemCardPipelineResult, Never>] = [:]

    func loadOrGenerate(
        entryID: UUID,
        signature: String,
        sourceImage: UIImage,
        grade: String,
        routeColor: RouteColor
    ) async -> ProblemCardPipelineResult {
        if let cached = ProblemCardImageStore.load(entryID: entryID, signature: signature) {
            return .ready(cached)
        }

        guard AICardSettings.isEnabled, !AICardSettings.apiKey.isEmpty else {
            return .failed("AI generation is disabled. Add an API key in Settings.")
        }

        let key = "\(entryID.uuidString)-\(signature)"
        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task<ProblemCardPipelineResult, Never> {
            do {
                let image = try await service.generateCard(sourceImage: sourceImage, grade: grade, routeColor: routeColor)
                ProblemCardImageStore.save(image: image, entryID: entryID, signature: signature)
                return .ready(image)
            } catch {
                return .failed(error.localizedDescription)
            }
        }

        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }
}
