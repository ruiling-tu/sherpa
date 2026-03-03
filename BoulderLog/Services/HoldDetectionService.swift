import CoreImage
import CoreImage.CIFilterBuiltins
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

struct HoldRenderSpec: Codable, Hashable {
    let id: UUID
    let x: Double
    let y: Double
    let radius: Double
    let role: HoldRole
    let orderIndex: Int?
    let isRoute: Bool
}

extension HoldRenderSpec {
    static func fromEntities(_ holds: [HoldEntity]) -> [HoldRenderSpec] {
        let routeIDs = routeIDSet(holds: holds.map { ($0.id, $0.role, $0.orderIndex) })
        return holds.map {
            HoldRenderSpec(
                id: $0.id,
                x: $0.xNormalized,
                y: $0.yNormalized,
                radius: $0.radius,
                role: $0.role,
                orderIndex: $0.orderIndex,
                isRoute: routeIDs.contains($0.id)
            )
        }
    }

    static func fromDrafts(_ holds: [HoldDraft]) -> [HoldRenderSpec] {
        let routeIDs = routeIDSet(holds: holds.map { ($0.id, $0.role, $0.orderIndex) })
        return holds.map {
            HoldRenderSpec(
                id: $0.id,
                x: $0.xNormalized,
                y: $0.yNormalized,
                radius: $0.radius,
                role: $0.role,
                orderIndex: $0.orderIndex,
                isRoute: routeIDs.contains($0.id)
            )
        }
    }

    private static func routeIDSet(holds: [(UUID, HoldRole, Int?)]) -> Set<UUID> {
        guard !holds.isEmpty else { return [] }
        // In this flow, any stored hold is considered an explicit annotation.
        return Set(holds.map { $0.0 })
    }
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
    static let maxUploadDimension: CGFloat = 896
    static let uploadJPEGQuality: CGFloat = 0.68
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

    static func quality(for model: String) -> String {
        model == defaultModel ? "low" : "medium"
    }
}

enum ProblemCardPromptFactory {
    static func prompt(grade: String, holds: [HoldRenderSpec]) -> String {
        let compactJSON = holdsJSONString(holds)
        let hasRouteAnnotations = holds.contains(where: \.isRoute)
        let routeCount = holds.filter(\.isRoute).count

        let annotationInstruction: String
        if hasRouteAnnotations {
            annotationInstruction = """
            Route holds are explicitly annotated. Hard constraint: render only those annotated holds.
            Do not add, infer, or keep any unannotated hold.
            """
        } else {
            annotationInstruction = "No explicit route subset was annotated. Infer all visible holds from image and render a readable complete hold map."
        }

        return """
        Create a collectible 2D climbing route card from this wall image.
        \(annotationInstruction)
        Preserve exact spatial relationships between selected holds.
        Preserve each selected hold's contour, footprint, and relative size so shape remains recognizable.
        Never distort route geometry.
        Style requirements:
        - clean illustrated card, minimal noise
        - solid warm background color #F4F1EA
        - preserve each hold's original dominant color family from the source image
        - keep hold shapes faithful to source (not overly simplified blobs)
        - active route holds may be slightly more saturated, but keep original hue
        - no text labels, no letters, no numbers
        - no connecting lines, arrows, or paths between holds
        - full-bleed composition that fills the canvas without black bars or borders
        - if a hold is not in metadata JSON, it must not appear in output
        Route holds count target: \(routeCount)
        Grade context: \(grade)
        Hold metadata JSON: \(compactJSON)
        """
    }

    static func signature(grade: String, holds: [HoldRenderSpec]) -> String {
        let sorted = holds.sorted {
            let lOrder = $0.orderIndex ?? 999
            let rOrder = $1.orderIndex ?? 999
            if lOrder != rOrder { return lOrder < rOrder }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.x < $1.x
        }
        let base = sorted.map {
            "\(round6($0.x))|\(round6($0.y))|\(round6($0.radius))|\($0.role.rawValue)|\($0.orderIndex ?? -1)|\($0.isRoute ? 1 : 0)"
        }.joined(separator: ";")
        return stableHash("\(grade)|\(base)")
    }

    static func cacheSignature(grade: String, holds: [HoldRenderSpec], model: String) -> String {
        "\(signature(grade: grade, holds: holds))-\(model)"
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
    func generateCard(sourceImage: UIImage, holds: [HoldRenderSpec], grade: String) async throws -> UIImage
}

struct OpenAIProblemCardService: ProblemCardGenerationService {
    private let logger = Logger(subsystem: "BoulderLog", category: "ProblemCardGeneration")
    private let ciContext = CIContext(options: [.priorityRequestLow: true])

    func generateCard(sourceImage: UIImage, holds: [HoldRenderSpec], grade: String) async throws -> UIImage {
        let apiKey = AICardSettings.apiKey
        guard !apiKey.isEmpty else {
            throw NSError(domain: "ProblemCard", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing API key."])
        }

        let prepStart = Date()
        let imageData = try await Task.detached(priority: .utility) {
            try prepareGuidanceUploadData(sourceImage: sourceImage, holds: holds)
        }.value
        let prepDuration = Date().timeIntervalSince(prepStart)

        let prompt = ProblemCardPromptFactory.prompt(grade: grade, holds: holds)
        let networkStart = Date()

        func generateWithSmartSize(model: String) async throws -> UIImage {
            do {
                return try await generateImage(
                    apiKey: apiKey,
                    model: model,
                    prompt: prompt,
                    imageData: imageData,
                    outputSize: AICardSettings.preferredOutputSize
                )
            } catch {
                let message = error.localizedDescription.lowercased()
                let shouldFallbackSize = message.contains("size") || message.contains("invalid")
                if shouldFallbackSize {
                    return try await generateImage(
                        apiKey: apiKey,
                        model: model,
                        prompt: prompt,
                        imageData: imageData,
                        outputSize: AICardSettings.fallbackOutputSize
                    )
                }
                throw error
            }
        }

        do {
            let image = try await generateWithSmartSize(model: AICardSettings.model)
            logger.info("problem_card_generation_success prep_ms=\(Int(prepDuration * 1000)) net_ms=\(Int(Date().timeIntervalSince(networkStart) * 1000)) bytes=\(imageData.count)")
            return image
        } catch {
            if AICardSettings.model != AICardSettings.fallbackModel {
                logger.info("problem_card_generation_retry_fallback prep_ms=\(Int(prepDuration * 1000))")
                let image = try await generateWithSmartSize(model: AICardSettings.fallbackModel)
                logger.info("problem_card_generation_success_fallback net_ms=\(Int(Date().timeIntervalSince(networkStart) * 1000))")
                return image
            }
            logger.error("problem_card_generation_failed error=\(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func generateImage(apiKey: String, model: String, prompt: String, imageData: Data, outputSize: String) async throws -> UIImage {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.timeoutInterval = AICardSettings.requestTimeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(boundary: boundary, model: model, prompt: prompt, imageData: imageData, outputSize: outputSize)

        let (data, response) = try await dataWithTimeout(request: request, timeout: AICardSettings.requestTimeoutSeconds)

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
            let (imgData, _) = try await URLSession.shared.data(from: url)
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

    private func buildMultipartBody(boundary: String, model: String, prompt: String, imageData: Data, outputSize: String) -> Data {
        var body = Data()
        let quality = AICardSettings.quality(for: model)

        appendField("model", value: model, to: &body, boundary: boundary)
        appendField("prompt", value: prompt, to: &body, boundary: boundary)
        appendField("size", value: outputSize, to: &body, boundary: boundary)
        appendField("quality", value: quality, to: &body, boundary: boundary)
        appendField("n", value: "1", to: &body, boundary: boundary)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"route.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
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

    private func prepareGuidanceUploadData(sourceImage: UIImage, holds: [HoldRenderSpec]) throws -> Data {
        let normalized = downscaled(image: sourceImage, maxDimension: AICardSettings.maxUploadDimension)
        let contrasted = enhanceContrast(image: normalized) ?? normalized
        let guided = renderGuidanceImage(sourceImage: contrasted, holds: holds)

        guard let data = guided.jpegData(compressionQuality: AICardSettings.uploadJPEGQuality) else {
            throw NSError(domain: "OpenAIProblemCardService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to build upload payload."])
        }
        return data
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

    private func enhanceContrast(image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.contrast = 1.25
        controls.saturation = 1.2
        controls.brightness = 0.02

        guard let output = controls.outputImage,
              let outCG = ciContext.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: outCG)
    }

    private func renderGuidanceImage(sourceImage: UIImage, holds: [HoldRenderSpec]) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: sourceImage.size, format: format)

        return renderer.image { context in
            let hasExplicitRoute = holds.contains(where: \.isRoute)
            let routeHolds = hasExplicitRoute ? holds.filter(\.isRoute) : holds

            let canvasRect = CGRect(origin: .zero, size: sourceImage.size)
            UIColor(red: 244/255, green: 241/255, blue: 234/255, alpha: 1).setFill()
            context.fill(canvasRect)

            // Keep only selected holds visible in guidance by compositing localized hold patches.
            for hold in routeHolds {
                let center = CGPoint(x: sourceImage.size.width * hold.x, y: sourceImage.size.height * hold.y)
                let radius = max(20, CGFloat(hold.radius) * min(sourceImage.size.width, sourceImage.size.height) * 2.2)
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2).integral

                let imgRect = CGRect(origin: .zero, size: sourceImage.size)
                let clipped = rect.intersection(imgRect)
                guard clipped.width > 4, clipped.height > 4 else { continue }

                if let cg = sourceImage.cgImage?.cropping(to: clipped) {
                    let patchImage = UIImage(cgImage: cg)
                    patchImage.draw(in: clipped)
                }
            }

            for hold in routeHolds {
                let center = CGPoint(x: sourceImage.size.width * hold.x, y: sourceImage.size.height * hold.y)
                let radius = max(8, CGFloat(hold.radius) * min(sourceImage.size.width, sourceImage.size.height))
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

                let stroke: UIColor
                let fill: UIColor
                switch hold.role {
                case .start:
                    stroke = UIColor(red: 0.46, green: 0.71, blue: 0.45, alpha: 1)
                case .finish:
                    stroke = UIColor(red: 0.86, green: 0.54, blue: 0.25, alpha: 1)
                case .normal:
                    stroke = UIColor(red: 0.27, green: 0.55, blue: 0.82, alpha: 1)
                }
                fill = UIColor.white.withAlphaComponent(0.06)

                context.cgContext.setStrokeColor(stroke.cgColor)
                context.cgContext.setFillColor(fill.cgColor)
                context.cgContext.setLineWidth(2.2)
                context.cgContext.fillEllipse(in: rect)
                context.cgContext.strokeEllipse(in: rect)

                if let order = hold.orderIndex {
                    let text = "\(order)" as NSString
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: max(9, radius * 0.65), weight: .medium),
                        .foregroundColor: UIColor.white
                    ]
                    let size = text.size(withAttributes: attrs)
                    let textRect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
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

enum ProblemCardPipelineResult {
    case ready(UIImage)
    case failed(String)
}

actor ProblemCardImagePipeline {
    static let shared = ProblemCardImagePipeline()

    private let service: ProblemCardGenerationService = OpenAIProblemCardService()
    private var inFlight: [String: Task<ProblemCardPipelineResult, Never>] = [:]

    func loadOrGenerate(entryID: UUID, signature: String, sourceImage: UIImage, holds: [HoldRenderSpec], grade: String) async -> ProblemCardPipelineResult {
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
                let image = try await service.generateCard(sourceImage: sourceImage, holds: holds, grade: grade)
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
