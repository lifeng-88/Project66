import SwiftUI

struct LocalLibraryView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @ObservedObject var viewModel: LocalLibraryViewModel

    @State private var showFolderManage = false

    private var displayedRecords: [LocalPhotoRecord] {
        viewModel.displayedRecords(
            showHiddenPhotos: settings.showHiddenPhotos,
            folderFilterId: viewModel.folderFilterId
        )
    }

    private var allDisplayedSelected: Bool {
        viewModel.allDisplayedSelected(
            showHiddenPhotos: settings.showHiddenPhotos,
            folderFilterId: viewModel.folderFilterId
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if viewModel.records.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCard
                            folderFilterBar
                            if settings.showHiddenPhotos {
                                hiddenFilterBar
                            }

                            if displayedRecords.isEmpty {
                                folderFilteredEmptyView
                            } else {
                                AdaptiveWaterfallGrid(
                                    items: displayedRecords,
                                    spacing: WaterfallGridMetrics.defaultSpacing,
                                    normalizedHeight: { record in
                                        WaterfallGridMetrics.normalizedHeightToWidth(
                                            width: record.pixelWidth,
                                            height: record.pixelHeight
                                        )
                                    }
                                ) { record in
                                    if viewModel.isSelectionMode {
                                        LocalPhotoSelectableCell(
                                            record: record,
                                            viewModel: viewModel
                                        )
                                    } else {
                                        NavigationLink(
                                            destination: LocalPhotoDetailView(record: record, viewModel: viewModel)
                                        ) {
                                            LocalPhotoCell(record: record, viewModel: viewModel)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, WaterfallGridMetrics.horizontalPadding)
                            }
                        }
                        .padding(.bottom, viewModel.isSelectionMode ? 168 : 24)
                    }
                }
            }

            if viewModel.isSelectionMode && !displayedRecords.isEmpty {
                localSelectionBar
            }
        }
        .navigationTitle(settings.t(.tabLocal))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.records.isEmpty {
                    Button(viewModel.isSelectionMode ? settings.t(.done) : settings.t(.manage)) {
                        withAnimation {
                            if viewModel.isSelectionMode {
                                viewModel.exitSelectionMode()
                            } else {
                                viewModel.isSelectionMode = true
                            }
                        }
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(palette.deepRose)
                }
            }
        }
        .overlay(alignment: .top) {
            if let message = viewModel.formattedActionMessage(using: settings) {
                ImportResultBanner(message: message) {
                    viewModel.clearActionMessage()
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { viewModel.reload() }
        .onChange(of: settings.showHiddenPhotos) { showHidden in
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.displayFilter = showHidden ? .all : .visible
                viewModel.clearSelection()
            }
        }
        .sheet(isPresented: $showFolderManage) {
            FolderManageSheet(viewModel: viewModel)
                .environmentObject(settings)
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.t(.savedLocally))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(palette.textPrimary)
                Text(settings.format(.localLibrarySummary, viewModel.totalCount, viewModel.totalSizeText))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(palette.textSecondary)
            }
            Spacer()
            Image(systemName: "internaldrive")
                .font(.title2)
                .foregroundColor(palette.lavender)
        }
        .padding(20)
        .feminineCard()
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var folderFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(settings.t(.localFolderFilter))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(palette.textSecondary)

                Spacer()

                if !viewModel.folders.isEmpty {
                    Button(settings.t(.manageFolders)) {
                        showFolderManage = true
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(palette.deepRose)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterChip(
                        title: settings.t(.folderAll),
                        isSelected: viewModel.folderFilterId == nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.folderFilterId = nil
                            viewModel.clearSelection()
                        }
                    }

                    ForEach(viewModel.folders) { folder in
                        FilterChip(
                            title: folder.name,
                            isSelected: viewModel.folderFilterId == folder.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.folderFilterId = folder.id
                                viewModel.clearSelection()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var hiddenFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(LocalLibraryFilter.hiddenBrowseFilters) { filter in
                    FilterChip(
                        title: hiddenBrowseFilterTitle(filter),
                        isSelected: viewModel.displayFilter == filter
                            || (filter == .all && viewModel.displayFilter == .visible)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.displayFilter = filter
                            viewModel.clearSelection()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func hiddenBrowseFilterTitle(_ filter: LocalLibraryFilter) -> String {
        switch filter {
        case .all: return settings.t(.libAll)
        case .hidden: return settings.t(.libHidden)
        case .visible: return settings.t(.libVisible)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(palette.lavender)
            Text(settings.t(.localEmpty))
                .font(.system(.title3, design: .rounded))
                .foregroundColor(palette.textPrimary)
            Text(settings.t(.localEmptyHint))
                .font(.system(.body, design: .rounded))
                .foregroundColor(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 80)
    }

    private var folderFilteredEmptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(palette.lavender)
            Text(folderEmptyMessage)
                .font(.system(.body, design: .rounded))
                .foregroundColor(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.bottom, 24)
    }

    private var folderEmptyMessage: String {
        if settings.showHiddenPhotos && viewModel.displayFilter == .hidden {
            return settings.t(.noHiddenPhotos)
        }
        return settings.t(.folderEmptyPhotos)
    }

    private var localSelectionBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button(allDisplayedSelected ? settings.t(.deselectAll) : settings.t(.selectAll)) {
                    if allDisplayedSelected {
                        viewModel.clearSelection()
                    } else {
                        viewModel.selectAllDisplayed(
                            showHiddenPhotos: settings.showHiddenPhotos,
                            folderFilterId: viewModel.folderFilterId
                        )
                    }
                }
                .foregroundColor(palette.deepRose)

                Spacer()
                Text(settings.format(.selectedCount, viewModel.selectedCount))
                    .foregroundColor(palette.textSecondary)
                Spacer()

                Button(settings.t(.cancel)) { viewModel.exitSelectionMode() }
                    .foregroundColor(palette.textSecondary)
            }
            .font(.system(.subheadline, design: .rounded))

            HStack(spacing: 10) {
                if settings.showHiddenPhotos {
                    if viewModel.displayFilter != .hidden {
                        actionButton(
                            title: settings.t(.hide),
                            icon: "eye.slash",
                            enabled: viewModel.selectedCount > 0,
                            style: .primary
                        ) {
                            viewModel.setSelectedHidden(true)
                        }
                    }

                    if viewModel.displayFilter == .hidden || viewModel.displayFilter == .all {
                        actionButton(
                            title: settings.t(.unhide),
                            icon: "eye",
                            enabled: viewModel.selectedCount > 0,
                            style: .secondary
                        ) {
                            viewModel.setSelectedHidden(false)
                        }
                    }
                } else {
                    actionButton(
                        title: settings.t(.hide),
                        icon: "eye.slash",
                        enabled: viewModel.selectedCount > 0,
                        style: .primary
                    ) {
                        viewModel.setSelectedHidden(true)
                    }
                }
            }

            Button(role: .destructive) {
                viewModel.deleteSelected()
            } label: {
                Text(settings.format(.deleteSelected, viewModel.selectedCount))
                    .font(.system(.subheadline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .disabled(viewModel.selectedCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(palette.cardHighlight.opacity(0.96))
    }

    private enum ActionStyle { case primary, secondary }

    private func actionButton(
        title: String,
        icon: String,
        enabled: Bool,
        style: ActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(style == .primary ? .white : palette.deepRose)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                enabled
                    ? (style == .primary ? AnyView(palette.accentGradient) : AnyView(palette.rose.opacity(0.15)))
                    : AnyView(palette.rose.opacity(0.2))
            )
            .cornerRadius(14)
        }
        .disabled(!enabled)
    }
}

struct LocalPhotoCell: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    let record: LocalPhotoRecord
    @ObservedObject var viewModel: LocalLibraryViewModel

    private var displayAspectRatio: CGFloat {
        WaterfallGridMetrics.displayAspectRatio(width: record.pixelWidth, height: record.pixelHeight)
    }

    private var thumbnailTargetWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let columnCount = CGFloat(WaterfallGridMetrics.columnCount(for: screenWidth - WaterfallGridMetrics.horizontalPadding * 2))
        return (screenWidth - WaterfallGridMetrics.horizontalPadding * 2 - WaterfallGridMetrics.defaultSpacing * (columnCount - 1)) / columnCount
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image = viewModel.image(for: record, targetWidth: thumbnailTargetWidth) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(record.isHidden ? 0.55 : 1)
                } else {
                    Rectangle().fill(palette.blush)
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
                if record.isVideo {
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

            if record.isVideo, let durationText = record.durationText {
                Text(durationText)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(8)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            if record.isHidden {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                    Text(settings.t(.hiddenBadge))
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.textPrimary.opacity(0.55))
                .cornerRadius(10)
                .padding(6)
            }
        }
    }
}

struct LocalPhotoSelectableCell: View {
    @Environment(\.palette) private var palette
    let record: LocalPhotoRecord
    @ObservedObject var viewModel: LocalLibraryViewModel

    var body: some View {
        Button {
            viewModel.toggleSelection(for: record)
        } label: {
            ZStack(alignment: .topTrailing) {
                LocalPhotoCell(record: record, viewModel: viewModel)
                    .overlay(selectionOverlay)

                Image(systemName: viewModel.selectedRecordIDs.contains(record.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(viewModel.selectedRecordIDs.contains(record.id) ? palette.deepRose : .white)
                    .shadow(radius: 2)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
    }

    private var selectionOverlay: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                viewModel.selectedRecordIDs.contains(record.id) ? palette.deepRose : Color.clear,
                lineWidth: 3
            )
    }
}

struct LocalPhotoDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    let record: LocalPhotoRecord
    @ObservedObject var viewModel: LocalLibraryViewModel
    @Environment(\.presentationMode) private var presentationMode
    @State private var showDeleteConfirm = false

    private var currentRecord: LocalPhotoRecord {
        viewModel.records.first { $0.id == record.id } ?? record
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = settings.language.locale
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if currentRecord.isVideo {
                    LocalFileVideoPlayerView(url: viewModel.fileURL(for: currentRecord))
                        .frame(maxHeight: 360)
                        .opacity(currentRecord.isHidden ? 0.7 : 1)
                } else if let image = viewModel.fullImage(for: currentRecord) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(currentRecord.isHidden ? 0.7 : 1)
                        .cornerRadius(20)
                        .shadow(color: palette.rose.opacity(0.2), radius: 16, y: 8)
                }

                infoCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(palette.backgroundGradient.ignoresSafeArea())
        .navigationTitle(settings.t(.localPhoto))
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewModel.setHidden(!currentRecord.isHidden, for: currentRecord)
                    } label: {
                        Label(
                            currentRecord.isHidden ? settings.t(.unhide) : settings.t(.hide),
                            systemImage: currentRecord.isHidden ? "eye" : "eye.slash"
                        )
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label(settings.t(.delete), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(palette.deepRose)
                }
            }
        }
        .alert(settings.t(.deleteLocalTitle), isPresented: $showDeleteConfirm) {
            Button(settings.t(.delete), role: .destructive) {
                viewModel.delete(record: currentRecord)
                presentationMode.wrappedValue.dismiss()
            }
            Button(settings.t(.cancel), role: .cancel) {}
        } message: {
            Text(settings.t(.deleteLocalMessage))
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(palette.accentGradient).frame(width: 8, height: 8)
                Text(settings.t(.localInfo))
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(palette.textPrimary)
            }

            InfoRow(icon: "doc.text", label: settings.t(.filename), value: currentRecord.filename)
            Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
            InfoRow(icon: "arrow.up.left.and.arrow.down.right", label: settings.t(.resolution), value: currentRecord.resolutionText)
            Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
            InfoRow(icon: "externaldrive", label: settings.t(.fileSize), value: currentRecord.fileSizeText)
            Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
            InfoRow(
                icon: currentRecord.isVideo ? "video" : "photo",
                label: settings.t(.mediaType),
                value: currentRecord.isVideo ? settings.t(.mediaVideo) : settings.t(.mediaImage)
            )
            if currentRecord.isVideo, let durationText = currentRecord.durationText {
                Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
                InfoRow(icon: "clock", label: settings.t(.duration), value: durationText)
            }
            Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
            InfoRow(
                icon: "folder",
                label: settings.t(.storageFolder),
                value: folderDisplayName(for: currentRecord)
            )
            Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
            InfoRow(icon: "eye.slash", label: settings.t(.hidden), value: currentRecord.isHidden ? settings.t(.yes) : settings.t(.no))
            Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
            InfoRow(icon: "calendar", label: settings.t(.importedAt), value: dateFormatter.string(from: currentRecord.importedAt))
            if let creationDate = currentRecord.creationDate {
                Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
                InfoRow(icon: "camera", label: settings.t(.shotAt), value: dateFormatter.string(from: creationDate))
            }
        }
        .padding(20)
        .feminineCard()
    }

    private func folderDisplayName(for record: LocalPhotoRecord) -> String {
        if let name = LocalPhotoStorage.folderName(for: record.folderId, in: viewModel.folders) {
            return name
        }
        return settings.t(.folderAll)
    }
}
