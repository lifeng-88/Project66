import AVFoundation
import ImageIO
import UIKit

enum LocalPhotoThumbnailCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for record: LocalPhotoRecord, targetWidth: CGFloat) -> UIImage? {
        let pixelWidth = max(targetWidth * UIScreen.main.scale, 120)
        let key = "\(record.id)_\(Int(pixelWidth))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let url = LocalPhotoStorage.fileURL(for: record)
        let image: UIImage?
        if record.isVideo {
            image = videoThumbnail(at: url, maxPixelSize: pixelWidth)
        } else {
            image = downsampleImage(at: url, maxPixelSize: pixelWidth)
        }

        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    static func clear() {
        cache.removeAllObjects()
    }

    private static func downsampleImage(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }

        let maxDimension = max(maxPixelSize, 1)
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private static func videoThumbnail(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)

        let time = CMTime(seconds: 0.2, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
