import Foundation
import SwiftUI
import UIKit

struct HoldPatch: Identifiable {
    let id: UUID
    let x: Double
    let y: Double
    let role: HoldRole
    let orderIndex: Int?
    let maskImage: UIImage?
    let fillColor: Color
    let aspectRatio: CGFloat
}

enum HoldShapeRenderer {
    private static let maskCache = NSCache<NSString, UIImage>()
    private static var colorCache: [String: UIColor] = [:]
    private static var ratioCache: [String: CGFloat] = [:]

    static func buildPatches(image: UIImage, holds: [HoldEntity]) -> [HoldPatch] {
        holds.map { hold in
            let key = cacheKey(for: hold, in: image)
            let result = patchMaskAndColor(for: hold, in: image)

            return HoldPatch(
                id: hold.id,
                x: hold.xNormalized,
                y: hold.yNormalized,
                role: hold.role,
                orderIndex: hold.orderIndex,
                maskImage: result?.mask,
                fillColor: Color(uiColor: result?.color ?? fallbackColor(for: hold)),
                aspectRatio: result?.aspectRatio ?? 1.0
            )
        }
    }

    private static func cacheKey(for hold: HoldEntity, in source: UIImage) -> NSString {
        NSString(string: "\(hold.id.uuidString)-\(Int(source.size.width))x\(Int(source.size.height))-\(hold.radius)")
    }

    private static func patchMaskAndColor(for hold: HoldEntity, in source: UIImage) -> (mask: UIImage, color: UIColor, aspectRatio: CGFloat)? {
        let key = cacheKey(for: hold, in: source)
        let keyString = key as String

        if let mask = maskCache.object(forKey: key), let color = colorCache[keyString], let ratio = ratioCache[keyString] {
            return (mask, color, ratio)
        }

        guard let cg = source.cgImage else { return nil }
        let width = cg.width
        let height = cg.height

        let cx = Int(hold.xNormalized * Double(width))
        let cy = Int(hold.yNormalized * Double(height))
        let half = max(20, Int(hold.radius * Double(min(width, height)) * 2.0))

        let rect = CGRect(
            x: max(0, cx - half),
            y: max(0, cy - half),
            width: min(width - max(0, cx - half), half * 2),
            height: min(height - max(0, cy - half), half * 2)
        ).integral

        guard rect.width > 10, rect.height > 10, let cropCG = cg.cropping(to: rect) else { return nil }
        guard let extraction = extractMaskAndColor(from: cropCG) else { return nil }

        maskCache.setObject(extraction.mask, forKey: key)
        colorCache[keyString] = extraction.color
        ratioCache[keyString] = extraction.aspectRatio

        return extraction
    }

    private static func extractMaskAndColor(from cgImage: CGImage) -> (mask: UIImage, color: UIColor, aspectRatio: CGFloat)? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width

        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Estimate local background from patch borders.
        var bgR = 0.0, bgG = 0.0, bgB = 0.0, bgCount = 0.0
        for y in 0..<height {
            for x in 0..<width {
                if x < 2 || y < 2 || x >= width - 2 || y >= height - 2 {
                    let i = (y * width + x) * bytesPerPixel
                    bgR += Double(pixels[i])
                    bgG += Double(pixels[i + 1])
                    bgB += Double(pixels[i + 2])
                    bgCount += 1
                }
            }
        }

        bgR /= max(bgCount, 1)
        bgG /= max(bgCount, 1)
        bgB /= max(bgCount, 1)

        var maskAlpha = [UInt8](repeating: 0, count: width * height)
        var keepR = 0.0, keepG = 0.0, keepB = 0.0, keepCount = 0.0
        var minX = width, minY = height, maxX = 0, maxY = 0

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

                let isHoldPixel = distance > 26 || saturation > 0.18
                if isHoldPixel {
                    maskAlpha[y * width + x] = 255
                    keepR += r
                    keepG += g
                    keepB += b
                    keepCount += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard keepCount > 16 else { return nil }

        // Soften silhouette edges for a cartoon-like style.
        maskAlpha = gaussianSmooth(maskAlpha, width: width, height: height)

        let averageColor = UIColor(
            red: CGFloat(keepR / keepCount / 255.0),
            green: CGFloat(keepG / keepCount / 255.0),
            blue: CGFloat(keepB / keepCount / 255.0),
            alpha: 1
        )

        let stylized = normalizeHoldColor(averageColor)

        var outPixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let out = idx * 4
                outPixels[out] = 255
                outPixels[out + 1] = 255
                outPixels[out + 2] = 255
                outPixels[out + 3] = maskAlpha[idx]
            }
        }

        guard let outContext = CGContext(
            data: &outPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outCG = outContext.makeImage() else {
            return nil
        }

        let w = max(1, maxX - minX)
        let h = max(1, maxY - minY)
        let aspect = CGFloat(w) / CGFloat(h)

        return (UIImage(cgImage: outCG), stylized, min(max(aspect, 0.55), 1.8))
    }

    private static func gaussianSmooth(_ alpha: [UInt8], width: Int, height: Int) -> [UInt8] {
        let kernel = [1, 2, 1,
                      2, 4, 2,
                      1, 2, 1]
        var output = alpha

        guard width > 2, height > 2 else { return alpha }

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sum = 0
                var k = 0
                for ky in -1...1 {
                    for kx in -1...1 {
                        let pixel = Int(alpha[(y + ky) * width + (x + kx)])
                        sum += pixel * kernel[k]
                        k += 1
                    }
                }
                let value = min(255, max(0, sum / 16))
                output[y * width + x] = UInt8(value)
            }
        }

        return output
    }

    private static func normalizeHoldColor(_ color: UIColor) -> UIColor {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let sat = (maxC - minC) / max(maxC, 0.001)

        if sat < 0.12 {
            // Nudge neutral holds into warm clay so cards remain readable.
            return UIColor(red: 0.72, green: 0.57, blue: 0.47, alpha: 1)
        }

        // Slightly flatten/brighten for clean collectible style.
        return UIColor(
            red: min(1, r * 0.92 + 0.05),
            green: min(1, g * 0.92 + 0.05),
            blue: min(1, b * 0.92 + 0.05),
            alpha: 1
        )
    }

    private static func fallbackColor(for hold: HoldEntity) -> UIColor {
        switch hold.role {
        case .start: return UIColor(red: 0.55, green: 0.74, blue: 0.54, alpha: 1)
        case .finish: return UIColor(red: 0.83, green: 0.37, blue: 0.30, alpha: 1)
        case .normal: return UIColor(red: 0.86, green: 0.21, blue: 0.16, alpha: 1)
        }
    }

    private static let framePalette: [Color] = [
        Color(hex: "9D7A4E"), // V0
        Color(hex: "B08D57"), // V1
        Color(hex: "A9A9AA"), // V2
        Color(hex: "C9A227"), // V3
        Color(hex: "C88A3A"), // V4
        Color(hex: "A975B5"), // V5
        Color(hex: "7E9BC7"), // V6
        Color(hex: "4EA08A"), // V7
        Color(hex: "6E93A1"), // V8
        Color(hex: "516A86"), // V9
        Color(hex: "39455A")  // V10
    ]

    private static let frameHighlightPalette: [Color] = [
        Color(hex: "D8BE9A"), // V0
        Color(hex: "E4CDA4"), // V1
        Color(hex: "E3E2E2"), // V2
        Color(hex: "E7D078"), // V3
        Color(hex: "E7B077"), // V4
        Color(hex: "D2A0DA"), // V5
        Color(hex: "A9C5E4"), // V6
        Color(hex: "95CFBF"), // V7
        Color(hex: "A8C6D0"), // V8
        Color(hex: "92AAC7"), // V9
        Color(hex: "73859D")  // V10
    ]

    static func frameColor(for grade: String) -> Color {
        framePalette[clampedGradeValue(grade)]
    }

    static func frameHighlight(for grade: String) -> Color {
        frameHighlightPalette[clampedGradeValue(grade)]
    }

    static func clampedGradeValue(_ grade: String) -> Int {
        min(max(gradeValue(grade), 0), 10)
    }

    static func gradeValue(_ grade: String) -> Int {
        let normalized = grade.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.hasPrefix("V"), let number = Int(normalized.dropFirst()) else { return 0 }
        return number
    }
}
