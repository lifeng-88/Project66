import Foundation
import ImageIO
import Photos

struct EXIFInfo {
    let items: [(label: String, value: String)]

    var isEmpty: Bool { items.isEmpty }

    static let empty = EXIFInfo(items: [])
}

enum EXIFReader {
    static func load(from asset: PHAsset, languageCode: String, completion: @escaping (EXIFInfo) -> Void) {
        let options = PHImageRequestOptions()
        options.version = .current
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat

        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                DispatchQueue.main.async { completion(.empty) }
                return
            }

            let info = parse(properties: properties, languageCode: languageCode)
            DispatchQueue.main.async { completion(info) }
        }
    }

    private static func exifKeyMap(for languageCode: String) -> [(key: String, label: String, formatter: (Any, String) -> String?)] {
        func label(_ key: L10nKey) -> String {
            L10n.string(key, language: languageCode)
        }

        return [
            ("{TIFF}.Make", label(.exifMake), stringValue),
            ("{TIFF}.Model", label(.exifModel), stringValue),
            ("{TIFF}.Software", label(.exifSoftware), stringValue),
            ("{Exif}.LensModel", label(.exifLens), stringValue),
            ("{Exif}.FocalLength", label(.exifFocalLength), focalLength),
            ("{Exif}.FNumber", label(.exifAperture), fNumber),
            ("{Exif}.ISOSpeedRatings", label(.exifISO), iso),
            ("{Exif}.ExposureTime", label(.exifShutter), exposureTime),
            ("{Exif}.Flash", label(.exifFlash), flash),
            ("{Exif}.WhiteBalance", label(.exifWhiteBalance), whiteBalance),
            ("{Exif}.ColorSpace", label(.exifColorSpace), colorSpace),
            ("{Exif}.PixelXDimension", label(.exifWidth), pixel),
            ("{Exif}.PixelYDimension", label(.exifHeight), pixel),
            ("{GPS}.Latitude", label(.exifLatitude), gpsCoordinate),
            ("{GPS}.Longitude", label(.exifLongitude), gpsCoordinate),
            ("{GPS}.Altitude", label(.exifAltitude), altitude)
        ]
    }

    private static func parse(properties: [String: Any], languageCode: String) -> EXIFInfo {
        var items: [(String, String)] = []

        for entry in exifKeyMap(for: languageCode) {
            if let value = nestedValue(in: properties, path: entry.key),
               let formatted = entry.formatter(value, languageCode) {
                items.append((entry.label, formatted))
            }
        }

        if let orientation = properties[kCGImagePropertyOrientation as String],
           let text = orientationText(orientation, languageCode: languageCode) {
            items.insert((L10n.string(.direction, language: languageCode), text), at: 0)
        }

        return EXIFInfo(items: items)
    }

    private static func nestedValue(in properties: [String: Any], path: String) -> Any? {
        let parts = path.split(separator: ".").map(String.init)
        guard parts.count == 2 else { return nil }

        let sectionKey: String
        switch parts[0] {
        case "{TIFF}": sectionKey = kCGImagePropertyTIFFDictionary as String
        case "{Exif}": sectionKey = kCGImagePropertyExifDictionary as String
        case "{GPS}": sectionKey = kCGImagePropertyGPSDictionary as String
        default: return nil
        }

        guard let section = properties[sectionKey] as? [String: Any] else { return nil }
        return section[parts[1]]
    }

    private static func stringValue(_ value: Any, languageCode: String) -> String? {
        switch value {
        case let string as String where !string.isEmpty:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func focalLength(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        return String(format: "%.1f mm", number.doubleValue)
    }

    private static func fNumber(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        return String(format: "f/%.1f", number.doubleValue)
    }

    private static func iso(_ value: Any, languageCode: String) -> String? {
        if let array = value as? [NSNumber], let first = array.first {
            return first.stringValue
        }
        return stringValue(value, languageCode: languageCode)
    }

    private static func exposureTime(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        let seconds = number.doubleValue
        if seconds >= 1 {
            return String(format: L10n.string(.exifExposureSeconds, language: languageCode), seconds)
        }
        if seconds > 0 {
            let denominator = Int(round(1.0 / seconds))
            return String(format: L10n.string(.exifExposureFraction, language: languageCode), denominator)
        }
        return nil
    }

    private static func flash(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        return number.intValue == 0
            ? L10n.string(.exifFlashOff, language: languageCode)
            : L10n.string(.exifFlashOn, language: languageCode)
    }

    private static func whiteBalance(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        return number.intValue == 0
            ? L10n.string(.exifWbAuto, language: languageCode)
            : L10n.string(.exifWbManual, language: languageCode)
    }

    private static func colorSpace(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        switch number.intValue {
        case 1: return "sRGB"
        case 2: return "Adobe RGB"
        default: return number.stringValue
        }
    }

    private static func pixel(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        return "\(number.intValue) px"
    }

    private static func gpsCoordinate(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        return String(format: "%.6f°", number.doubleValue)
    }

    private static func altitude(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        return String(format: "%.1f m", number.doubleValue)
    }

    private static func orientationText(_ value: Any, languageCode: String) -> String? {
        guard let number = value as? NSNumber else { return nil }
        switch number.intValue {
        case 1: return L10n.string(.exifOrientationNormal, language: languageCode)
        case 3: return L10n.string(.exifOrientation180, language: languageCode)
        case 6: return L10n.string(.exifOrientationCW90, language: languageCode)
        case 8: return L10n.string(.exifOrientationCCW90, language: languageCode)
        default:
            return String(format: L10n.string(.exifOrientationUnknown, language: languageCode), number.intValue)
        }
    }
}
