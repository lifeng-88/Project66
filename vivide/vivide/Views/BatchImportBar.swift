import SwiftUI

struct BatchImportBar: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @ObservedObject var viewModel: PhotoLibraryViewModel
    let localLibrary: LocalLibraryViewModel

    var body: some View {
        VStack(spacing: 12) {
            ImportFolderPicker(
                selectedFolderId: $settings.importFolderId,
                folders: localLibrary.folders,
                onFoldersChanged: { localLibrary.reload() }
            )

            HStack {
                Button(viewModel.allFilteredSelected ? settings.t(.deselectAll) : settings.t(.selectAll)) {
                    if viewModel.allFilteredSelected {
                        viewModel.clearSelection()
                    } else {
                        viewModel.selectAllFiltered()
                    }
                }
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(palette.deepRose)

                Spacer()

                Text(settings.format(.selectedCount, viewModel.selectedCount))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(palette.textSecondary)

                Spacer()

                Button(settings.t(.cancel)) {
                    withAnimation { viewModel.exitSelectionMode() }
                }
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(palette.textSecondary)
            }

            Button {
                Task {
                    await viewModel.importSelected(
                        localLibrary: localLibrary,
                        folderId: settings.importFolderId,
                        settings: settings
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text(settings.format(.importToLocal, viewModel.selectedCount))
                }
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    viewModel.selectedCount > 0
                        ? AnyView(palette.accentGradient)
                        : AnyView(palette.rose.opacity(0.35))
                )
                .cornerRadius(16)
            }
            .disabled(viewModel.selectedCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            palette.cardHighlight.opacity(0.96)
                .shadow(color: palette.shadowColor, radius: 12, y: -4)
        )
    }
}

struct ImportProgressOverlay: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    let progress: ImportProgressState

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(LinearProgressViewStyle(tint: palette.rose))
                    .frame(width: 220)

                Text(settings.t(.importing))
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(palette.textPrimary)

                Text("\(min(progress.current + 1, progress.total)) / \(progress.total)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(palette.textSecondary)

                if let filename = progress.filename {
                    Text(filename)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(palette.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 240)
                }
            }
            .padding(28)
            .feminineCard()
            .padding(.horizontal, 40)
        }
    }
}

struct ImportResultBanner: View {
    @Environment(\.palette) private var palette
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(palette.deepRose)
            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(palette.textPrimary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(palette.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(palette.searchBackground)
        .cornerRadius(14)
        .shadow(color: palette.shadowColor, radius: 8, y: 4)
        .padding(.horizontal, 16)
    }
}
