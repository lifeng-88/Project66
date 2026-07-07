import SwiftUI

struct PhotoGridView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @ObservedObject var viewModel: PhotoLibraryViewModel
    @ObservedObject var localLibrary: LocalLibraryViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if viewModel.isLoading && viewModel.photos.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: palette.rose))
                        Text(settings.t(.loadingAlbum))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                    }
                } else if viewModel.photos.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if viewModel.authState == .limited {
                                limitedLibraryBanner
                            }
                            headerBanner
                            AlbumStatsCard(
                                stats: viewModel.stats,
                                filteredCount: viewModel.photos.count,
                                hasActiveFilters: viewModel.hasActiveFilters
                            )
                            PhotoSearchBar(text: $viewModel.searchText)
                            filterToolbar
                            DateFilterBar(viewModel: viewModel)
                            CategoryFilterBar(viewModel: viewModel)
                            if !viewModel.isSelectionMode {
                                ImportFolderPicker(
                                    selectedFolderId: $settings.importFolderId,
                                    folders: localLibrary.folders,
                                    onFoldersChanged: { localLibrary.reload() }
                                )
                                .padding(.horizontal, 16)
                            }

                            AdaptiveWaterfallGrid(
                                items: viewModel.photos,
                                spacing: WaterfallGridMetrics.defaultSpacing,
                                normalizedHeight: { photo in
                                    WaterfallGridMetrics.normalizedHeightToWidth(
                                        width: photo.pixelWidth,
                                        height: photo.pixelHeight
                                    )
                                }
                            ) { photo in
                                if viewModel.isSelectionMode {
                                    SelectablePhotoCell(viewModel: viewModel, photo: photo)
                                } else {
                                    NavigationLink(destination: PhotoDetailView(viewModel: viewModel, photo: photo)) {
                                        PhotoThumbnailCell(viewModel: viewModel, photo: photo, showImportedBadge: true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, WaterfallGridMetrics.horizontalPadding)
                        }
                        .padding(.bottom, viewModel.isSelectionMode ? 140 : 24)
                    }
                    .refreshable { await viewModel.refresh() }
                }
            }

            if viewModel.isSelectionMode {
                BatchImportBar(viewModel: viewModel, localLibrary: localLibrary)
            }

            if let progress = viewModel.importProgress, viewModel.isImporting {
                ImportProgressOverlay(progress: progress)
            }
        }
        .onAppear {
            viewModel.syncImportedAssets()
            viewModel.updateThumbnailCaching(for: viewModel.photos)
        }
        .onDisappear {
            viewModel.stopThumbnailCaching()
        }
        .onChange(of: localLibrary.contentRevision) { _ in
            viewModel.syncImportedAssets()
        }
    }

    private var limitedLibraryBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.title3)
                .foregroundColor(palette.deepRose)

            VStack(alignment: .leading, spacing: 8) {
                Text(settings.t(.limitedLibraryHint))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(settings.t(.limitedLibraryManage)) {
                    viewModel.presentLimitedLibraryPicker()
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(palette.deepRose)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .feminineCard()
        .padding(.horizontal, WaterfallGridMetrics.horizontalPadding)
    }

    private var headerBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.t(.myAlbum))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(palette.textPrimary)
                Text(subtitleText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(palette.textSecondary)
            }
            Spacer()
            if viewModel.hasActiveFilters && !viewModel.isSelectionMode {
                Button(settings.t(.reset)) {
                    withAnimation { viewModel.resetFilters() }
                }
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(palette.deepRose)
            } else if !viewModel.isSelectionMode {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundColor(palette.rose.opacity(0.8))
                    Text("\(settings.t(.localCount)) \(localLibrary.totalCount)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(palette.textSecondary)
                }
            }
        }
        .padding(20)
        .feminineCard()
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var filterToolbar: some View {
        HStack {
            SortMenuButton(viewModel: viewModel)
            Spacer()
            Text(settings.sortTitle(viewModel.sortOption))
                .font(.system(.caption, design: .rounded))
                .foregroundColor(palette.textSecondary)
        }
        .padding(.horizontal, 16)
    }

    private var subtitleText: String {
        if viewModel.isSelectionMode {
            return settings.t(.selectToImport)
        }
        if !viewModel.hasActiveFilters {
            return settings.format(.totalPhotos, viewModel.totalPhotoCount)
        }
        return settings.format(.showingPhotos, viewModel.photos.count, viewModel.totalPhotoCount)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.searchText.isEmpty ? "photo.stack" : "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(palette.lavender)
            Text(emptyMessage)
                .font(.system(.body, design: .rounded))
                .foregroundColor(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if viewModel.hasActiveFilters {
                Button(settings.t(.clearFilters)) {
                    viewModel.resetFilters()
                }
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(palette.accentGradient)
                .cornerRadius(14)
            }
        }
    }

    private var emptyMessage: String {
        if !viewModel.searchText.isEmpty {
            return settings.format(.noSearchResultsWithQuery, viewModel.searchText)
        }
        if viewModel.hasActiveFilters {
            return settings.t(.noFilterResults)
        }
        return settings.t(.noPhotos)
    }
}

struct SelectablePhotoCell: View {
    @Environment(\.palette) private var palette
    @ObservedObject var viewModel: PhotoLibraryViewModel
    let photo: PhotoInfo

    var body: some View {
        Button { viewModel.toggleSelection(for: photo) } label: {
            ZStack(alignment: .topTrailing) {
                PhotoThumbnailCell(viewModel: viewModel, photo: photo, showImportedBadge: true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                viewModel.selectedPhotoIDs.contains(photo.id) ? palette.deepRose : Color.clear,
                                lineWidth: 3
                            )
                    )
                Image(systemName: viewModel.selectedPhotoIDs.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(viewModel.selectedPhotoIDs.contains(photo.id) ? palette.deepRose : .white)
                    .shadow(radius: 2)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
    }
}

struct PhotoThumbnailCell: View {
    @Environment(\.palette) private var palette
    @ObservedObject var viewModel: PhotoLibraryViewModel
    let photo: PhotoInfo
    var showImportedBadge = false

    @State private var thumbnail: UIImage?

    private var displayAspectRatio: CGFloat {
        WaterfallGridMetrics.displayAspectRatio(width: photo.pixelWidth, height: photo.pixelHeight)
    }

    private var thumbnailTargetSize: CGSize {
        let scale = UIScreen.main.scale
        let screenWidth = UIScreen.main.bounds.width
        let columnCount = CGFloat(WaterfallGridMetrics.columnCount(for: screenWidth - WaterfallGridMetrics.horizontalPadding * 2))
        let columnWidth = (screenWidth - WaterfallGridMetrics.horizontalPadding * 2 - WaterfallGridMetrics.defaultSpacing * (columnCount - 1)) / columnCount
        let pixelWidth = max(columnWidth * scale, 180)
        let pixelHeight = pixelWidth / max(displayAspectRatio, 0.1)
        return CGSize(width: pixelWidth, height: pixelHeight)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(palette.blush)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: palette.rose))
                        )
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(displayAspectRatio, contentMode: .fit)
            .clipped()
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .overlay {
                if photo.isVideo {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.45))
                            .frame(width: 36, height: 36)
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }
                }
            }

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    if showImportedBadge && viewModel.isImported(photo) {
                        Image(systemName: "internaldrive.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(palette.lavender.opacity(0.9))
                            .clipShape(Circle())
                    }
                    if photo.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(palette.rose.opacity(0.85))
                            .clipShape(Circle())
                    }
                }

                if photo.isVideo, let durationText = photo.durationText {
                    Text(durationText)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(8)
                }
            }
            .padding(6)
        }
        .task(id: photo.id) {
            viewModel.loadThumbnail(for: photo, targetSize: thumbnailTargetSize) { thumbnail = $0 }
        }
        .onDisappear {
            viewModel.cancelThumbnail(for: photo.id)
        }
    }
}
