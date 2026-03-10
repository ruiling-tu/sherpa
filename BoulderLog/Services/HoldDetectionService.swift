import Foundation
import UIKit
import os.log

struct HoldCandidate: Identifiable {
    let id = UUID()
    let xNormalized: Double
    let yNormalized: Double
    let widthNormalized: Double
    let heightNormalized: Double
    let rotationRadians: Double
    let contourPoints: [CGPoint]
    let confidence: Double
}

struct RouteDetectionResult {
    let holds: [HoldCandidate]
    let wallOutline: [CGPoint]
}

struct RouteColorCalibration: Equatable {
    let point: CGPoint
}

protocol HoldDetectionService {
    func detectRoute(in image: UIImage, routeColor: RouteColor, calibration: RouteColorCalibration?) async -> RouteDetectionResult
}

struct LocalRouteDetectionService: HoldDetectionService {
    private struct RawComponent {
        var pixels: [Int]
        var boundary: [Int]
        var minX: Int
        var maxX: Int
        var minY: Int
        var maxY: Int
        var sumX: Double
        var sumY: Double
        var scoreSum: Double
        var touchesBorder: Bool

        var area: Int { pixels.count }
        var centroidX: Double { sumX / Double(max(area, 1)) }
        var centroidY: Double { sumY / Double(max(area, 1)) }
        var width: Int { maxX - minX + 1 }
        var height: Int { maxY - minY + 1 }
        var averageScore: Double { scoreSum / Double(max(area, 1)) }
    }

    func detectRoute(in image: UIImage, routeColor: RouteColor, calibration: RouteColorCalibration?) async -> RouteDetectionResult {
        await Task.detached(priority: .userInitiated) {
            Self.detectRouteSync(in: image, routeColor: routeColor, calibration: calibration)
        }.value
    }

    private static func detectRouteSync(in image: UIImage, routeColor: RouteColor, calibration: RouteColorCalibration?) -> RouteDetectionResult {
        guard let cgImage = downscaledCGImage(from: image, maxDimension: 720) else {
            return RouteDetectionResult(holds: [], wallOutline: RouteGeometry.defaultWallOutline)
        }

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
            return RouteDetectionResult(holds: [], wallOutline: RouteGeometry.defaultWallOutline)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let totalPixels = width * height
        let minArea = max(48, totalPixels / 5000)
        let maxArea = max(totalPixels / 3, minArea * 2)
        let referenceHSV = calibration.flatMap { sampleHSV(from: pixels, width: width, height: height, normalizedPoint: $0.point) }

        var mask = [UInt8](repeating: 0, count: totalPixels)
        var matchScores = [Double](repeating: 0, count: totalPixels)
        for index in 0..<totalPixels {
            let offset = index * bytesPerPixel
            let red = Double(pixels[offset]) / 255.0
            let green = Double(pixels[offset + 1]) / 255.0
            let blue = Double(pixels[offset + 2]) / 255.0
            let hsv = HSV(red: red, green: green, blue: blue)
            let score = adaptiveMatchScore(routeColor: routeColor, hsv: hsv, referenceHSV: referenceHSV)
            matchScores[index] = score
            if score > (referenceHSV == nil ? 0.38 : 0.32) {
                mask[index] = 1
            }
        }

        mask = morphologyClose(mask: mask, width: width, height: height, radius: 2, passes: 2)
        mask = fillSmallHoles(
            mask: mask,
            width: width,
            height: height,
            maxHoleArea: max(24, totalPixels / 18000)
        )
        mask = smooth(mask: mask, width: width, height: height)
        mask = morphologyClose(mask: mask, width: width, height: height, radius: 1, passes: 1)

        var visited = [Bool](repeating: false, count: totalPixels)
        let neighbors = [
            (-1, 0), (1, 0), (0, -1), (0, 1),
            (-1, -1), (-1, 1), (1, -1), (1, 1)
        ]
        var components: [RawComponent] = []

        for start in 0..<totalPixels where mask[start] == 1 && !visited[start] {
            var queue = [start]
            var queueIndex = 0
            visited[start] = true

            var component: [Int] = []
            var boundary: [Int] = []
            var minX = width
            var maxX = 0
            var minY = height
            var maxY = 0
            var sumX = 0.0
            var sumY = 0.0
            var scoreSum = 0.0
            var touchesBorder = false

            while queueIndex < queue.count {
                let current = queue[queueIndex]
                queueIndex += 1
                component.append(current)

                let x = current % width
                let y = current / width
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
                sumX += Double(x)
                sumY += Double(y)
                scoreSum += matchScores[current]
                touchesBorder = touchesBorder || x == 0 || y == 0 || x == width - 1 || y == height - 1

                var isBoundary = false
                for (dx, dy) in neighbors {
                    let nx = x + dx
                    let ny = y + dy
                    if nx < 0 || ny < 0 || nx >= width || ny >= height {
                        isBoundary = true
                        continue
                    }

                    let neighborIndex = ny * width + nx
                    if mask[neighborIndex] == 0 {
                        isBoundary = true
                        continue
                    }

                    if !visited[neighborIndex] {
                        visited[neighborIndex] = true
                        queue.append(neighborIndex)
                    }
                }

                if isBoundary {
                    boundary.append(current)
                }
            }

            guard component.count >= minArea,
                  component.count <= maxArea,
                  maxX - minX >= 6,
                  maxY - minY >= 6 else {
                continue
            }

            let averageScore = scoreSum / Double(max(component.count, 1))
            if averageScore < (referenceHSV == nil ? 0.43 : 0.35) {
                continue
            }

            if touchesBorder && component.count > max(120, totalPixels / 7000) {
                continue
            }

            components.append(
                RawComponent(
                    pixels: component,
                    boundary: boundary,
                    minX: minX,
                    maxX: maxX,
                    minY: minY,
                    maxY: maxY,
                    sumX: sumX,
                    sumY: sumY,
                    scoreSum: scoreSum,
                    touchesBorder: touchesBorder
                )
            )
        }

        let mergedComponents = splitCompositeComponents(
            mergeComponents(components),
            width: width,
            height: height,
            matchScores: matchScores,
            minArea: minArea
        )
        var candidates: [HoldCandidate] = []

        for component in mergedComponents {
            let centroidX = component.centroidX
            let centroidY = component.centroidY

            var covXX = 0.0
            var covYY = 0.0
            var covXY = 0.0
            for index in component.pixels {
                let x = Double(index % width) - centroidX
                let y = Double(index / width) - centroidY
                covXX += x * x
                covYY += y * y
                covXY += x * y
            }
            let rotation = 0.5 * atan2(2 * covXY, covXX - covYY)

            let contour = sampledContour(
                boundary: component.boundary,
                centroidX: centroidX,
                centroidY: centroidY,
                width: width,
                height: height
            )

            let widthNormalized = Double(component.width) / Double(width)
            let heightNormalized = Double(component.height) / Double(height)
            let confidence = min(
                0.99,
                0.25 + component.averageScore * 0.55 + Double(component.area) / Double(totalPixels) * 10
            )

            candidates.append(
                HoldCandidate(
                    xNormalized: centroidX / Double(width),
                    yNormalized: centroidY / Double(height),
                    widthNormalized: widthNormalized,
                    heightNormalized: heightNormalized,
                    rotationRadians: rotation,
                    contourPoints: contour,
                    confidence: confidence
                )
            )
        }

        let sorted = candidates.sorted {
            if abs($0.yNormalized - $1.yNormalized) > 0.03 {
                return $0.yNormalized > $1.yNormalized
            }
            return $0.xNormalized < $1.xNormalized
        }

        return RouteDetectionResult(
            holds: sorted,
            wallOutline: RouteGeometry.defaultWallOutline
        )
    }

    private static func mergeComponents(_ components: [RawComponent]) -> [RawComponent] {
        guard components.count > 1 else { return components }
        var merged = components.sorted { $0.area > $1.area }
        var didMerge = true

        while didMerge {
            didMerge = false
            outer: for leftIndex in 0..<merged.count {
                for rightIndex in (leftIndex + 1)..<merged.count {
                    if shouldMerge(merged[leftIndex], merged[rightIndex]) {
                        merged[leftIndex] = combine(merged[leftIndex], merged[rightIndex])
                        merged.remove(at: rightIndex)
                        didMerge = true
                        break outer
                    }
                }
            }
        }

        return merged
    }

    private static func splitCompositeComponents(
        _ components: [RawComponent],
        width: Int,
        height: Int,
        matchScores: [Double],
        minArea: Int
    ) -> [RawComponent] {
        components.flatMap {
            splitCompositeComponent($0, width: width, height: height, matchScores: matchScores, minArea: minArea)
        }
    }

    private static func splitCompositeComponent(
        _ component: RawComponent,
        width: Int,
        height: Int,
        matchScores: [Double],
        minArea: Int
    ) -> [RawComponent] {
        guard component.area >= max(minArea * 2, 220),
              max(component.width, component.height) >= 30 else {
            return [component]
        }

        let componentSet = Set(component.pixels)
        let distances = distanceMap(for: component, componentSet: componentSet, width: width, height: height)
        guard let maxDistance = distances.values.max(), maxDistance >= 6 else {
            return [component]
        }

        let localPeaks = distances.compactMap { index, distance -> (index: Int, distance: Int, score: Double)? in
            guard distance >= max(4, Int(Double(maxDistance) * 0.58)) else { return nil }
            let x = index % width
            let y = index / width

            for dy in -1...1 {
                for dx in -1...1 where dx != 0 || dy != 0 {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    let neighborIndex = ny * width + nx
                    if let neighborDistance = distances[neighborIndex], neighborDistance > distance {
                        return nil
                    }
                }
            }

            return (
                index: index,
                distance: distance,
                score: Double(distance) * (0.7 + matchScores[index])
            )
        }
        .sorted { $0.score > $1.score }

        guard localPeaks.count >= 2 else {
            return [component]
        }

        let separationThreshold = max(18.0, Double(maxDistance) * 1.9)
        var selectedPeaks: [(index: Int, distance: Int, score: Double)] = []
        for peak in localPeaks {
            let px = Double(peak.index % width)
            let py = Double(peak.index / width)
            let separated = selectedPeaks.allSatisfy { chosen in
                let cx = Double(chosen.index % width)
                let cy = Double(chosen.index / width)
                let dx = px - cx
                let dy = py - cy
                return sqrt(dx * dx + dy * dy) >= separationThreshold
            }
            if separated {
                selectedPeaks.append(peak)
            }
            if selectedPeaks.count == 3 { break }
        }

        guard selectedPeaks.count >= 2 else {
            return [component]
        }

        var groups = Array(repeating: [Int](), count: selectedPeaks.count)
        for pixel in component.pixels {
            let x = Double(pixel % width)
            let y = Double(pixel / width)

            var bestGroup = 0
            var bestScore = Double.greatestFiniteMagnitude
            for (groupIndex, peak) in selectedPeaks.enumerated() {
                let px = Double(peak.index % width)
                let py = Double(peak.index / width)
                let dx = x - px
                let dy = y - py
                let distance = sqrt(dx * dx + dy * dy)
                let weightedScore = distance / Double(max(peak.distance, 1))
                if weightedScore < bestScore {
                    bestScore = weightedScore
                    bestGroup = groupIndex
                }
            }
            groups[bestGroup].append(pixel)
        }

        let splitComponents = groups.compactMap {
            buildComponent(from: $0, width: width, height: height, matchScores: matchScores)
        }

        guard splitComponents.count >= 2,
              splitComponents.allSatisfy({ $0.area >= max(36, minArea / 2) }) else {
            return [component]
        }

        return splitComponents
    }

    private static func shouldMerge(_ left: RawComponent, _ right: RawComponent) -> Bool {
        let expandedLeft = CGRect(
            x: CGFloat(left.minX - 4),
            y: CGFloat(left.minY - 4),
            width: CGFloat(left.width + 8),
            height: CGFloat(left.height + 8)
        )
        let expandedRight = CGRect(
            x: CGFloat(right.minX - 4),
            y: CGFloat(right.minY - 4),
            width: CGFloat(right.width + 8),
            height: CGFloat(right.height + 8)
        )

        if CGRect(x: left.minX, y: left.minY, width: left.width, height: left.height)
            .intersects(CGRect(x: right.minX, y: right.minY, width: right.width, height: right.height)) {
            return true
        }

        if expandedLeft.intersects(expandedRight) && min(left.area, right.area) < 90 {
            return true
        }

        let horizontalGap = max(0, max(left.minX, right.minX) - min(left.maxX, right.maxX) - 1)
        let verticalGap = max(0, max(left.minY, right.minY) - min(left.maxY, right.maxY) - 1)
        let overlapX = max(0, min(left.maxX, right.maxX) - max(left.minX, right.minX))
        let overlapY = max(0, min(left.maxY, right.maxY) - max(left.minY, right.minY))
        let overlapRatioX = Double(overlapX) / Double(max(min(left.width, right.width), 1))
        let overlapRatioY = Double(overlapY) / Double(max(min(left.height, right.height), 1))

        if horizontalGap <= 4 && overlapRatioY > 0.68 {
            return true
        }

        if verticalGap <= 4 && overlapRatioX > 0.68 {
            return true
        }

        let dx = left.centroidX - right.centroidX
        let dy = left.centroidY - right.centroidY
        let distance = sqrt(dx * dx + dy * dy)
        let threshold = max(
            10.0,
            Double(min(max(left.width, left.height), max(right.width, right.height))) * 0.42
        )
        return distance < threshold
    }

    private static func combine(_ left: RawComponent, _ right: RawComponent) -> RawComponent {
        RawComponent(
            pixels: left.pixels + right.pixels,
            boundary: left.boundary + right.boundary,
            minX: min(left.minX, right.minX),
            maxX: max(left.maxX, right.maxX),
            minY: min(left.minY, right.minY),
            maxY: max(left.maxY, right.maxY),
            sumX: left.sumX + right.sumX,
            sumY: left.sumY + right.sumY,
            scoreSum: left.scoreSum + right.scoreSum,
            touchesBorder: left.touchesBorder || right.touchesBorder
        )
    }

    private static func buildComponent(
        from pixels: [Int],
        width: Int,
        height: Int,
        matchScores: [Double]
    ) -> RawComponent? {
        guard !pixels.isEmpty else { return nil }
        let componentSet = Set(pixels)
        let neighbors = [
            (-1, 0), (1, 0), (0, -1), (0, 1),
            (-1, -1), (-1, 1), (1, -1), (1, 1)
        ]

        var boundary: [Int] = []
        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var sumX = 0.0
        var sumY = 0.0
        var scoreSum = 0.0
        var touchesBorder = false

        for pixel in pixels {
            let x = pixel % width
            let y = pixel / width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
            sumX += Double(x)
            sumY += Double(y)
            scoreSum += matchScores[pixel]
            touchesBorder = touchesBorder || x == 0 || y == 0 || x == width - 1 || y == height - 1

            var isBoundary = false
            for (dx, dy) in neighbors {
                let nx = x + dx
                let ny = y + dy
                if nx < 0 || ny < 0 || nx >= width || ny >= height || !componentSet.contains(ny * width + nx) {
                    isBoundary = true
                    break
                }
            }
            if isBoundary {
                boundary.append(pixel)
            }
        }

        return RawComponent(
            pixels: pixels,
            boundary: boundary,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            sumX: sumX,
            sumY: sumY,
            scoreSum: scoreSum,
            touchesBorder: touchesBorder
        )
    }

    private static func distanceMap(
        for component: RawComponent,
        componentSet: Set<Int>,
        width: Int,
        height: Int
    ) -> [Int: Int] {
        let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        var distances = Dictionary(uniqueKeysWithValues: component.pixels.map { ($0, Int.max) })
        var queue = component.boundary
        var queueIndex = 0

        for boundaryPixel in component.boundary {
            distances[boundaryPixel] = 0
        }

        while queueIndex < queue.count {
            let current = queue[queueIndex]
            queueIndex += 1
            guard let currentDistance = distances[current] else { continue }

            let x = current % width
            let y = current / width
            for (dx, dy) in neighbors {
                let nx = x + dx
                let ny = y + dy
                guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                let neighborIndex = ny * width + nx
                guard componentSet.contains(neighborIndex) else { continue }

                if currentDistance + 1 < (distances[neighborIndex] ?? Int.max) {
                    distances[neighborIndex] = currentDistance + 1
                    queue.append(neighborIndex)
                }
            }
        }

        return distances
    }

    private static func smooth(mask: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard width > 2, height > 2 else { return mask }
        var output = mask

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var count = 0
                for ky in -1...1 {
                    for kx in -1...1 {
                        let idx = (y + ky) * width + (x + kx)
                        count += Int(mask[idx])
                    }
                }

                let index = y * width + x
                output[index] = count >= 5 ? 1 : 0
            }
        }

        return output
    }

    private static func fillSmallHoles(mask: [UInt8], width: Int, height: Int, maxHoleArea: Int) -> [UInt8] {
        guard maxHoleArea > 0 else { return mask }
        var output = mask
        var visited = [Bool](repeating: false, count: mask.count)
        let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        for start in 0..<mask.count where mask[start] == 0 && !visited[start] {
            var queue = [start]
            var queueIndex = 0
            var region: [Int] = []
            var touchesBorder = false
            visited[start] = true

            while queueIndex < queue.count {
                let current = queue[queueIndex]
                queueIndex += 1
                region.append(current)

                let x = current % width
                let y = current / width
                if x == 0 || y == 0 || x == width - 1 || y == height - 1 {
                    touchesBorder = true
                }

                for (dx, dy) in neighbors {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    let neighborIndex = ny * width + nx
                    if mask[neighborIndex] == 0 && !visited[neighborIndex] {
                        visited[neighborIndex] = true
                        queue.append(neighborIndex)
                    }
                }
            }

            if !touchesBorder && region.count <= maxHoleArea {
                for index in region {
                    output[index] = 1
                }
            }
        }

        return output
    }

    private static func morphologyClose(mask: [UInt8], width: Int, height: Int, radius: Int, passes: Int) -> [UInt8] {
        var output = mask
        for _ in 0..<passes {
            output = dilate(mask: output, width: width, height: height, radius: radius)
            output = erode(mask: output, width: width, height: height, radius: radius)
        }
        return output
    }

    private static func dilate(mask: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0 else { return mask }
        var output = mask

        for y in 0..<height {
            for x in 0..<width {
                var found = false
                for ky in -radius...radius {
                    for kx in -radius...radius {
                        let nx = x + kx
                        let ny = y + ky
                        if nx < 0 || ny < 0 || nx >= width || ny >= height {
                            continue
                        }
                        if mask[ny * width + nx] == 1 {
                            found = true
                            break
                        }
                    }
                    if found { break }
                }
                output[y * width + x] = found ? 1 : 0
            }
        }

        return output
    }

    private static func erode(mask: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0 else { return mask }
        var output = mask

        for y in 0..<height {
            for x in 0..<width {
                var keep = true
                for ky in -radius...radius {
                    for kx in -radius...radius {
                        let nx = x + kx
                        let ny = y + ky
                        if nx < 0 || ny < 0 || nx >= width || ny >= height || mask[ny * width + nx] == 0 {
                            keep = false
                            break
                        }
                    }
                    if !keep { break }
                }
                output[y * width + x] = keep ? 1 : 0
            }
        }

        return output
    }

    private static func sampledContour(
        boundary: [Int],
        centroidX: Double,
        centroidY: Double,
        width: Int,
        height: Int,
        bins: Int = 20
    ) -> [CGPoint] {
        guard !boundary.isEmpty else {
            return RouteGeometry.ellipsePoints(
                center: CGPoint(x: centroidX / Double(width), y: centroidY / Double(height)),
                width: 0.08,
                height: 0.08
            )
        }

        var best = Array<(distance: Double, point: CGPoint)?>(repeating: nil, count: bins)

        for index in boundary {
            let x = Double(index % width)
            let y = Double(index / width)
            let dx = x - centroidX
            let dy = y - centroidY
            let distance = dx * dx + dy * dy
            let angle = atan2(dy, dx)
            let normalizedAngle = angle < 0 ? angle + Double.pi * 2 : angle
            let bin = min(bins - 1, Int((normalizedAngle / (Double.pi * 2)) * Double(bins)))
            let point = RouteGeometry.clamped(
                CGPoint(
                    x: x / Double(width),
                    y: y / Double(height)
                )
            )

            if let existing = best[bin], existing.distance >= distance {
                continue
            }
            best[bin] = (distance, point)
        }

        let points = best.compactMap { entry in
            entry?.point
        }
        if points.count >= 6 {
            return points
        }

        return RouteGeometry.ellipsePoints(
            center: CGPoint(x: centroidX / Double(width), y: centroidY / Double(height)),
            width: 0.08,
            height: 0.08
        )
    }

    private static func adaptiveMatchScore(routeColor: RouteColor, hsv: HSV, referenceHSV: HSV?) -> Double {
        let familyScore = matchScore(routeColor: routeColor, hsv: hsv)
        guard let referenceHSV else { return familyScore }

        let sampledScore = sampleMatchScore(routeColor: routeColor, hsv: hsv, referenceHSV: referenceHSV)
        if familyScore < 0.08 {
            return sampledScore * 0.35
        }
        return max(familyScore, familyScore * 0.35 + sampledScore * 0.75)
    }

    private static func matchScore(routeColor: RouteColor, hsv: HSV) -> Double {
        switch routeColor {
        case .yellow:
            return chromaticScore(hsv: hsv, targetHue: 56, hueTolerance: 20, minSaturation: 0.28, minValue: 0.28)
        case .green:
            return chromaticScore(hsv: hsv, targetHue: 118, hueTolerance: 28, minSaturation: 0.22, minValue: 0.16)
        case .red:
            return chromaticScore(hsv: hsv, targetHue: 2, hueTolerance: 18, minSaturation: 0.3, minValue: 0.18)
        case .blue:
            return chromaticScore(hsv: hsv, targetHue: 220, hueTolerance: 24, minSaturation: 0.24, minValue: 0.17)
        case .black:
            return max(0, min(1, (0.24 - hsv.value) * 3.2 + (0.42 - hsv.saturation) * 0.7))
        case .white:
            return max(0, min(1, (hsv.value - 0.72) * 2.4 + (0.18 - hsv.saturation) * 1.3))
        case .purple:
            return chromaticScore(hsv: hsv, targetHue: 286, hueTolerance: 24, minSaturation: 0.22, minValue: 0.18)
        case .orange:
            return chromaticScore(hsv: hsv, targetHue: 28, hueTolerance: 14, minSaturation: 0.3, minValue: 0.2)
        case .pink:
            return chromaticScore(hsv: hsv, targetHue: 330, hueTolerance: 20, minSaturation: 0.16, minValue: 0.4)
        case .brown:
            let hueScore = chromaticScore(hsv: hsv, targetHue: 25, hueTolerance: 14, minSaturation: 0.26, minValue: 0.14)
            return hsv.value <= 0.58 ? hueScore : hueScore * 0.45
        case .gray:
            return max(0, min(1, (0.16 - hsv.saturation) * 2.3)) * max(0, min(1, 1 - abs(hsv.value - 0.5) * 2.2))
        case .teal:
            return chromaticScore(hsv: hsv, targetHue: 178, hueTolerance: 18, minSaturation: 0.24, minValue: 0.18)
        }
    }

    private static func sampleMatchScore(routeColor: RouteColor, hsv: HSV, referenceHSV: HSV) -> Double {
        let hueTolerance: Double = {
            switch routeColor {
            case .red, .orange, .pink, .brown:
                return 18
            case .yellow, .green, .blue, .purple, .teal:
                return 22
            case .black, .white, .gray:
                return 40
            }
        }()

        switch routeColor {
        case .black, .white, .gray:
            let saturationDistance = abs(hsv.saturation - referenceHSV.saturation)
            let valueDistance = abs(hsv.value - referenceHSV.value)
            let saturationScore = max(0, 1 - saturationDistance / 0.18)
            let valueScore = max(0, 1 - valueDistance / 0.22)
            return saturationScore * 0.45 + valueScore * 0.55
        default:
            let hueScore = max(0, 1 - hueDistance(hsv.hue, referenceHSV.hue) / hueTolerance)
            let saturationScore = max(0, 1 - abs(hsv.saturation - referenceHSV.saturation) / 0.28)
            let valueScore = max(0, 1 - abs(hsv.value - referenceHSV.value) / 0.32)
            return hueScore * 0.65 + saturationScore * 0.2 + valueScore * 0.15
        }
    }

    private static func sampleHSV(from pixels: [UInt8], width: Int, height: Int, normalizedPoint: CGPoint) -> HSV? {
        guard width > 0, height > 0 else { return nil }
        let centerX = min(max(Int(normalizedPoint.x * Double(width)), 0), width - 1)
        let centerY = min(max(Int(normalizedPoint.y * Double(height)), 0), height - 1)
        let radius = 3

        var sumSine = 0.0
        var sumCosine = 0.0
        var sumSaturation = 0.0
        var sumValue = 0.0
        var count = 0.0

        for y in max(0, centerY - radius)...min(height - 1, centerY + radius) {
            for x in max(0, centerX - radius)...min(width - 1, centerX + radius) {
                let offset = (y * width + x) * 4
                let red = Double(pixels[offset]) / 255.0
                let green = Double(pixels[offset + 1]) / 255.0
                let blue = Double(pixels[offset + 2]) / 255.0
                let hsv = HSV(red: red, green: green, blue: blue)
                let radians = hsv.hue / 180 * Double.pi
                sumCosine += cos(radians)
                sumSine += sin(radians)
                sumSaturation += hsv.saturation
                sumValue += hsv.value
                count += 1
            }
        }

        guard count > 0 else { return nil }
        var hue = atan2(sumSine / count, sumCosine / count) * 180 / Double.pi
        if hue < 0 { hue += 360 }
        return HSV(
            hue: hue,
            saturation: sumSaturation / count,
            value: sumValue / count
        )
    }

    private static func chromaticScore(
        hsv: HSV,
        targetHue: Double,
        hueTolerance: Double,
        minSaturation: Double,
        minValue: Double
    ) -> Double {
        guard hsv.saturation >= minSaturation, hsv.value >= minValue else { return 0 }
        let hueDelta = hueDistance(hsv.hue, targetHue)
        guard hueDelta <= hueTolerance else { return 0 }
        let hueScore = 1 - hueDelta / hueTolerance
        let saturationScore = min(1, (hsv.saturation - minSaturation) / max(1 - minSaturation, 0.0001))
        let valueScore = min(1, (hsv.value - minValue) / max(1 - minValue, 0.0001))
        return hueScore * 0.7 + saturationScore * 0.2 + valueScore * 0.1
    }

    private static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let raw = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(raw, 360 - raw)
    }

    private static func downscaledCGImage(from image: UIImage, maxDimension: CGFloat) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return image.cgImage }
        guard longest > maxDimension else { return image.cgImage }

        let scale = maxDimension / longest
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let downscaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return downscaled.cgImage
    }
}

private struct HSV {
    let hue: Double
    let saturation: Double
    let value: Double

    init(hue: Double, saturation: Double, value: Double) {
        self.hue = hue
        self.saturation = saturation
        self.value = value
    }

    init(red: Double, green: Double, blue: Double) {
        let maxValue = max(red, max(green, blue))
        let minValue = min(red, min(green, blue))
        let delta = maxValue - minValue
        let rawHue: Double

        value = maxValue
        saturation = maxValue == 0 ? 0 : delta / maxValue

        if delta == 0 {
            rawHue = 0
        } else if maxValue == red {
            rawHue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxValue == green {
            rawHue = 60 * (((blue - red) / delta) + 2)
        } else {
            rawHue = 60 * (((red - green) / delta) + 4)
        }

        hue = rawHue < 0 ? rawHue + 360 : rawHue
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
