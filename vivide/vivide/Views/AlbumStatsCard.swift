import SwiftUI

struct AlbumStatsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette

    let stats: AlbumStats
    let filteredCount: Int
    let hasActiveFilters: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(settings.t(.albumOverview))
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(palette.textPrimary)
                Spacer()
                if hasActiveFilters {
                    Text(settings.format(.filterShowing, filteredCount))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(palette.deepRose)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(palette.rose.opacity(0.15))
                        .cornerRadius(12)
                }
            }

            HStack(spacing: 0) {
                statItem(value: stats.total, label: settings.t(.catAll), icon: "photo.on.rectangle")
                statDivider
                statItem(value: stats.favorites, label: settings.t(.catFavorites), icon: "heart.fill")
                statDivider
                statItem(value: stats.videos, label: settings.t(.catVideos), icon: "video.fill")
                statDivider
                statItem(value: stats.screenshots, label: settings.t(.catScreenshots), icon: "camera.viewfinder")
            }
        }
        .padding(20)
        .feminineCard()
        .padding(.horizontal, 16)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(palette.rose.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    private func statItem(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(palette.lavender)
            Text("\(value)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(palette.textPrimary)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PhotoSearchBar: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(palette.lavender)

            TextField(settings.t(.searchPlaceholder), text: $text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(palette.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(palette.textSecondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(palette.searchBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.rose.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

struct CategoryFilterBar: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var viewModel: PhotoLibraryViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PhotoCategoryFilter.allCases) { filter in
                    FilterChip(
                        title: settings.categoryTitle(filter),
                        isSelected: viewModel.categoryFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.categoryFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct SortMenuButton: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @ObservedObject var viewModel: PhotoLibraryViewModel

    var body: some View {
        Menu {
            ForEach(PhotoSortOption.allCases) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    if viewModel.sortOption == option {
                        Label(settings.sortTitle(option), systemImage: "checkmark")
                    } else {
                        Text(settings.sortTitle(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(settings.t(.sortLabel))
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(palette.deepRose)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(palette.searchBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.rose.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
