import Foundation
import SwiftUI
import UIKit

struct HoldPatch: Identifiable {
    let id: UUID
    let x: Double
    let y: Double
    let role: HoldRole
    let orderIndex: Int?
    let image: UIImage?
}

enum HoldShapeRenderer {
    private static let cache = NSCache<NSString, UIImage>()

    static func buildPatches(image: UIImage, holds: [HoldEntity]) -> [HoldPatch] {
        holds.map { hold in
            HoldPatch(
                id: hold.id,
                x: hold.xNormalized,
                y: hold.yNormalized,
                role: hold.role,
                orderIndex: hold.orderIndex,
                image: patchImage(for: hold, in: image)
            )
        }
    }

    static func patchImage(for hold: HoldEntity, in source: UIImage) -> UIImage? {
        let key = NSString(string: "\(hold.id.uuidString)-\(Int(source.size.width))x\(Int(source.size.height))-\(hold.radius)")
        if let cached = cache.object(forKey: key) { return cached }

        guard let cg = source.cgImage else { return nil }
        let width = cg.width
        let height = cg.height

        let cx = Int(hold.xNormalized * Double(width))
        let cy = Int(hold.yNormalized * Double(height))
        let half = max(18, Int(hold.radius * Double(min(width, height)) * 1.8))

        let rect = CGRect(
            x: max(0, cx - half),
            y: max(0, cy - half),
            width: min(width - max(0, cx - half), half * 2),
            height: min(height - max(0, cy - half), half * 2)
        ).integral

        guard rect.width > 8, rect.height > 8,
              let cropCG = cg.cropping(to: rect) else {
            return nil
        }

        guard let simplified = removeBackgroundAndSoften(cropCG) else {
            return UIImage(cgImage: cropCG)
        }

        cache.setObject(simplified, forKey: key)
        return simplified
    }

    private static func removeBackgroundAndSoften(_ cgImage: CGImage) -> UIImage? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Estimate local background from border pixels.
        var sumR = 0.0, sumG = 0.0, sumB = 0.0, count = 0.0
        for y in 0..<height {
            for x in 0..<width {
                if x == 0 || y == 0 || x == width - 1 || y == height - 1 {
                    let i = (y * width + x) * bytesPerPixel
                    sumR += Double(pixels[i])
                    sumG += Double(pixels[i + 1])
                    sumB += Double(pixels[i + 2])
                    count += 1
                }
            }
        }

        let bgR = sumR / max(count, 1)
        let bgG = sumG / max(count, 1)
        let bgB = sumB / max(count, 1)

        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bytesPerPixel
                let r = Double(pixels[i])
                let g = Double(pixels[i + 1])
                let b = Double(pixels[i + 2])

                let maxC = max(r, max(g, b))
                let minC = min(r, min(g, b))
                let saturation = (maxC - minC) / max(maxC, 1)
                let distance = sqrt(pow(r - bgR, 2) + pow(g - bgG, 2) + pow(b - bgB, 2))

                // Keep likely hold color; remove flat background tones.
                let keep = distance > 22 || saturation > 0.13
                pixels[i + 3] = keep ? 255 : 0
            }
        }

        guard let outCG = context.makeImage() else { return nil }
        return UIImage(cgImage: outCG)
    }

    static func frameColor(for grade: String) -> Color {
        let value = gradeValue(grade)
        switch value {
        case ...1: return Color(hex: "B08D57") // bronze
        case 2: return Color(hex: "A9A9AA") // silver
        case 3: return Color(hex: "C9A227") // gold
        default: return Color(hex: "8FB8C9") // diamond
        }
    }

    static func gradeValue(_ grade: String) -> Int {
        let normalized = grade.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.hasPrefix("V"), let number = Int(normalized.dropFirst()) else { return 0 }
        return number
    }
}
