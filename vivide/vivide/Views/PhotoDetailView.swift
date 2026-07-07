import Photos
import SwiftUI
import AVFoundation

struct PhotoDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @ObservedObject var viewModel: PhotoLibraryViewModel
    let photo: PhotoInfo

    @State private var fullImage: UIImage?
    @State private var videoPlayer: AVPlayer?
    @State private var fileSizeText = ""
    @State private var exifInfo: EXIFInfo = .empty
    @State private var isLoadingEXIF = true
    @State private var showShareSheet = false
    @State private var showCopiedToast = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = settings.language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                previewSection
                infoSection(title: settings.t(.basicInfo), rows: basicInfoRows)
                infoSection(title: settings.t(.captureInfo), rows: captureInfoRows)
                if !photo.isVideo {
                    exifSection
                }

                if !photo.subtypeTags.isEmpty {
                    tagsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(palette.backgroundGradient.ignoresSafeArea())
        .navigationTitle(settings.t(.photoDetail))
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        copyInfoToClipboard()
                    } label: {
                        Label(settings.t(.copyInfo), systemImage: "doc.on.doc")
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label(settings.t(.shareInfo), systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(palette.deepRose)
                }
            }
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                Text(settings.t(.copied))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(palette.deepRose.opacity(0.92))
                    .cornerRadius(20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [exportText])
        }
        .onAppear {
            fileSizeText = settings.t(.calculating)
            if photo.isVideo {
                viewModel.loadVideoPlayer(for: photo) { player in
                    videoPlayer = player
                }
            } else {
                viewModel.loadFullImage(for: photo) { image in
                    fullImage = image
                }
                loadEXIF()
            }
            loadFileSize()
        }
        .onDisappear {
            videoPlayer?.pause()
            videoPlayer = nil
        }
        .onChange(of: settings.language) { _ in
            if !photo.isVideo {
                loadEXIF()
            }
        }
    }

    @ViewBuilder
    private var exifSection: some View {
        if isLoadingEXIF {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(settings.t(.exifInfo))
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: palette.rose))
                    Text(settings.t(.loadingEXIF))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(palette.textSecondary)
                }
            }
            .padding(20)
            .feminineCard()
        } else if !exifInfo.isEmpty {
            infoSection(
                title: settings.t(.exifInfo),
                rows: exifInfo.items.map { ("camera.aperture", $0.label, $0.value) }
            )
        }
    }

    private var previewSection: some View {
        Group {
            if photo.isVideo {
                if let videoPlayer {
                    AssetVideoPlayerView(player: videoPlayer)
                        .frame(maxHeight: 360)
                } else {
                    videoPlaceholder
                }
            } else if let fullImage {
                Image(uiImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(20)
                    .shadow(color: palette.rose.opacity(0.2), radius: 16, y: 8)
            } else {
                videoPlaceholder
            }
        }
        .padding(.top, 8)
    }

    private var videoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(palette.blush)
            .aspectRatio(
                photo.pixelHeight > 0
                    ? CGFloat(photo.pixelWidth) / CGFloat(photo.pixelHeight)
                    : 16 / 9,
                contentMode: .fit
            )
            .frame(maxHeight: 360)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: palette.rose))
            )
    }

    private var basicInfoRows: [(String, String, String)] {
        var rows: [(String, String, String)] = [
            ("doc.text", settings.t(.filename), photo.filename ?? settings.t(.unknown)),
            ("arrow.up.left.and.arrow.down.right", settings.t(.resolution), photo.resolutionText),
            ("aspectratio", settings.t(.aspectRatio), photo.aspectRatioText),
            ("externaldrive", settings.t(.fileSize), fileSizeText),
            ("photo", settings.t(.mediaType), settings.mediaKindTitle(photo.mediaKind)),
            ("folder", settings.t(.source), settings.sourceKindTitle(photo.sourceKind))
        ]

        if photo.isVideo, let durationText = photo.durationText {
            rows.append(("clock", settings.t(.duration), durationText))
        }

        return rows
    }

    private var captureInfoRows: [(String, String, String)] {
        var rows: [(String, String, String)] = [
            ("calendar", settings.t(.created), formatDate(photo.creationDate)),
            ("clock", settings.t(.modified), formatDate(photo.modificationDate))
        ]

        if let location = photo.locationDescription {
            rows.append(("location", settings.t(.location), location))
        }

        rows.append(("heart", settings.t(.favorite), photo.isFavorite ? settings.t(.yes) : settings.t(.no)))
        rows.append(("eye.slash", settings.t(.hidden), photo.isHidden ? settings.t(.yes) : settings.t(.no)))

        return rows
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(settings.t(.specialTags))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photo.subtypeTags, id: \.self) { tag in
                        Text(settings.subtypeTitle(tag))
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(palette.deepRose)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(palette.rose.opacity(0.2))
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding(20)
        .feminineCard()
    }

    private func infoSection(title: String, rows: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    InfoRow(icon: row.0, label: row.1, value: row.2)

                    if index < rows.count - 1 {
                        Divider()
                            .background(palette.rose.opacity(0.15))
                            .padding(.leading, 44)
                    }
                }
            }
        }
        .padding(20)
        .feminineCard()
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(palette.accentGradient)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(palette.textPrimary)
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return settings.t(.unknown) }
        return dateFormatter.string(from: date)
    }

    private func loadFileSize() {
        let resources = PHAssetResource.assetResources(for: photo.asset)
        let resource = resources.first { item in
            if photo.isVideo {
                return item.type == .video || item.type == .fullSizeVideo
            }
            return item.type == .photo || item.type == .fullSizePhoto
        } ?? resources.first
        guard let resource else {
            fileSizeText = settings.t(.unknown)
            return
        }

        var total: Int64 = 0
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        PHAssetResourceManager.default().requestData(
            for: resource,
            options: options,
            dataReceivedHandler: { data in
                total += Int64(data.count)
            },
            completionHandler: { error in
                DispatchQueue.main.async {
                    if total > 0 {
                        fileSizeText = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
                    } else {
                        fileSizeText = error == nil ? settings.t(.unknown) : settings.t(.unknown)
                    }
                }
            }
        )
    }

    private func loadEXIF() {
        isLoadingEXIF = true
        EXIFReader.load(from: photo.asset, languageCode: settings.language.l10nCode) { info in
            exifInfo = info
            isLoadingEXIF = false
        }
    }

    private var exportText: String {
        PhotoInfoExporter.exportText(
            for: photo,
            fileSize: fileSizeText,
            exifInfo: exifInfo,
            languageCode: settings.language.l10nCode
        )
    }

    private func copyInfoToClipboard() {
        UIPasteboard.general.string = exportText
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}

struct InfoRow: View {
    @Environment(\.palette) private var palette
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(palette.lavender)
                .frame(width: 24)

            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(palette.textSecondary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(palette.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}
