import SwiftUI

struct BSideSwitchSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var bSideManager: BSideManager
    @Environment(\.palette) private var palette
    @State private var isSwitching = false

    var body: some View {
        if bSideManager.canSwitchToBSide {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(palette.lavender)
                    Text(settings.t(.settingsBSideTitle))
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(palette.textPrimary)
                }

                Text(settings.t(.settingsBSideHint))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(palette.textSecondary)

                Button {
                    openBSide()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 18, weight: .semibold))
                        Text(settings.t(.settingsBSideOpen))
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        if isSwitching {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(palette.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isSwitching)
            }
        }
    }

    private func openBSide() {
        isSwitching = true
        Task {
            await bSideManager.switchToBSide()
            isSwitching = false
        }
    }
}
