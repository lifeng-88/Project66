import SwiftUI

struct DateFilterBar: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var viewModel: PhotoLibraryViewModel

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DateFilter.allCases) { filter in
                        FilterChip(
                            title: settings.dateFilterTitle(filter),
                            isSelected: viewModel.dateFilter == filter
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.dateFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if viewModel.dateFilter == .custom {
                HStack(spacing: 12) {
                    DatePicker("", selection: $viewModel.customStartDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .accentColor(paletteAccent)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(paletteSecondary)

                    DatePicker("", selection: $viewModel.customEndDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .accentColor(paletteAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .feminineCard()
                .padding(.horizontal, 16)
            }
        }
    }

    @Environment(\.palette) private var palette

    private var paletteAccent: Color { palette.rose }
    private var paletteSecondary: Color { palette.textSecondary }
}

struct FilterChip: View {
    @Environment(\.palette) private var palette

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : palette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            palette.accentGradient
                        } else {
                            palette.searchBackground
                        }
                    }
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : palette.rose.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
