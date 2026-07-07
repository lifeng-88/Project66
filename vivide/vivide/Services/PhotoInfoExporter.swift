import Foundation

enum PhotoInfoExporter {
    static func exportText(
        for photo: PhotoInfo,
        fileSize: String,
        exifInfo: EXIFInfo,
        languageCode: String
    ) -> String {
        func t(_ key: L10nKey) -> String {
            L10n.string(key, language: languageCode)
        }

        let listSeparator = languageCode.hasPrefix("zh") ? "、" : ", "

        var lines: [String] = [
            t(.exportHeader),
            t(.exportDivider),
            "\(t(.filename)): \(photo.filename ?? t(.unknown))",
            "\(t(.resolution)): \(photo.resolutionText)",
            "\(t(.aspectRatio)): \(photo.aspectRatioText)",
            "\(t(.fileSize)): \(fileSize)",
            "\(t(.mediaType)): \(photo.mediaKind.localizedTitle(languageCode: languageCode))",
            "\(t(.source)): \(photo.sourceKind.localizedTitle(languageCode: languageCode))",
            "\(t(.created)): \(formatDate(photo.creationDate, languageCode: languageCode))",
            "\(t(.modified)): \(formatDate(photo.modificationDate, languageCode: languageCode))"
        ]

        if let location = photo.locationDescription {
            lines.append("\(t(.location)): \(location)")
        }

        if photo.isVideo, let durationText = photo.durationText {
            lines.append("\(t(.duration)): \(durationText)")
        }

        lines.append("\(t(.favorite)): \(photo.isFavorite ? t(.yes) : t(.no))")
        lines.append("\(t(.hidden)): \(photo.isHidden ? t(.yes) : t(.no))")

        if !photo.subtypeTags.isEmpty {
            let tags = photo.subtypeTags
                .map { $0.localizedTitle(languageCode: languageCode) }
                .joined(separator: listSeparator)
            lines.append("\(t(.specialTags)): \(tags)")
        }

        if !exifInfo.isEmpty, !photo.isVideo {
            lines.append("")
            lines.append(t(.exifInfo))
            lines.append(t(.exportDivider))
            for item in exifInfo.items {
                lines.append("\(item.label): \(item.value)")
            }
        }

        lines.append("")
        lines.append(t(.exportFromVivide))
        return lines.joined(separator: "\n")
    }

    private static func formatDate(_ date: Date?, languageCode: String) -> String {
        guard let date else { return L10n.string(.unknown, language: languageCode) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode)
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
