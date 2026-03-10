import SwiftUI

struct ImageSpaceTransform {
    static func fittedRect(imageSize: CGSize, in bounds: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2, width: width, height: height)
    }

    static func filledRect(imageSize: CGSize, in bounds: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2, width: width, height: height)
    }

    static func normalizedPoint(from viewPoint: CGPoint, imageRect: CGRect) -> CGPoint? {
        guard imageRect.contains(viewPoint), imageRect.width > 0, imageRect.height > 0 else { return nil }
        let x = (viewPoint.x - imageRect.minX) / imageRect.width
        let y = (viewPoint.y - imageRect.minY) / imageRect.height
        return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    static func viewPoint(from normalized: CGPoint, imageRect: CGRect) -> CGPoint {
        CGPoint(x: imageRect.minX + normalized.x * imageRect.width, y: imageRect.minY + normalized.y * imageRect.height)
    }
}

extension UIImage {
    func cropped(normalizedRect: CGRect) -> UIImage? {
        let uprightImage = normalized()
        let clamped = CGRect(
            x: max(0, min(1, normalizedRect.origin.x)),
            y: max(0, min(1, normalizedRect.origin.y)),
            width: max(0.05, min(1, normalizedRect.size.width)),
            height: max(0.05, min(1, normalizedRect.size.height))
        )

        guard let sourceCG = uprightImage.cgImage else { return nil }
        let cropRect = CGRect(
            x: clamped.origin.x * CGFloat(sourceCG.width),
            y: clamped.origin.y * CGFloat(sourceCG.height),
            width: clamped.size.width * CGFloat(sourceCG.width),
            height: clamped.size.height * CGFloat(sourceCG.height)
        ).integral

        guard let cg = sourceCG.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cg, scale: uprightImage.scale, orientation: .up)
    }

    private func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
