import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var bSideManager: BSideManager
    @Environment(\.palette) private var palette

    @State private var versionTapCount = 0
    @State private var showDevIdCopiedToast = false
    @State private var versionTapResetTask: Task<Void, Never>?

    private let versionTapThreshold = 10

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                settingsSection(title: settings.t(.settingsLanguage)) {
                    ForEach(AppLanguage.allCases) { lang in
                        SettingsOptionRow(
                            title: languageTitle(lang),
                            isSelected: settings.language == lang
                        ) {
                            settings.language = lang
                        }
                    }
                }

                settingsSection(title: settings.t(.settingsAppearance)) {
                    ForEach(AppearanceMode.allCases) { mode in
                        SettingsOptionRow(
                            title: appearanceTitle(mode),
                            isSelected: settings.appearance == mode
                        ) {
                            settings.appearance = mode
                        }
                    }
                }

                settingsSection(title: settings.t(.settingsLocalLibrary)) {
                    SettingsToggleRow(
                        title: settings.t(.settingsShowHiddenPhotos),
                        subtitle: settings.t(.settingsShowHiddenPhotosHint),
                        isOn: $settings.showHiddenPhotos
                    )
                }

                if bSideManager.canSwitchToBSide {
                    settingsSection(title: settings.t(.settingsBSideTitle)) {
                        BSideSwitchSection()
                    }
                }

                settingsSection(title: settings.t(.settingsLegal)) {
                    NavigationLink {
                        LegalDocumentView(document: .userAgreement)
                    } label: {
                        SettingsLinkRow(icon: "doc.text", title: settings.t(.userAgreement))
                    }
                    .buttonStyle(.plain)

                    Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)

                    NavigationLink {
                        LegalDocumentView(document: .privacyPolicy)
                    } label: {
                        SettingsLinkRow(icon: "hand.raised", title: settings.t(.privacyPolicy))
                    }
                    .buttonStyle(.plain)
                }

                settingsSection(title: settings.t(.settingsAbout)) {
                    VStack(spacing: 0) {
                        InfoRow(icon: "sparkles", label: settings.t(.settingsVersion), value: appVersion)
                            .contentShape(Rectangle())
                            .onTapGesture { handleVersionTap() }
                        Divider().background(palette.rose.opacity(0.15)).padding(.leading, 44)
                        Text(settings.t(.settingsDescription))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(palette.backgroundGradient.ignoresSafeArea())
        .navigationTitle(settings.t(.settingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showDevIdCopiedToast {
                Text(settings.t(.settingsDevIdCopied))
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
        .onDisappear {
            versionTapResetTask?.cancel()
            versionTapResetTask = nil
        }
    }

    private func handleVersionTap() {
        versionTapResetTask?.cancel()
        versionTapCount += 1

        guard versionTapCount >= versionTapThreshold else {
            versionTapResetTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { versionTapCount = 0 }
            }
            return
        }

        versionTapCount = 0
        Task {
            let deviceId = await VivideDeviceManager.shared.getDeviceId()
            await MainActor.run {
                UIPasteboard.general.string = deviceId
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDevIdCopiedToast = true
                }
            }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDevIdCopiedToast = false
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(palette.accentGradient)
                    .frame(width: 64, height: 64)
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.t(.settingsTitle))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(palette.textPrimary)
                Text(settings.t(.settingsDescription))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(palette.textSecondary)
            }
            Spacer()
        }
        .padding(20)
        .feminineCard()
        .padding(.top, 8)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(palette.accentGradient).frame(width: 8, height: 8)
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(palette.textPrimary)
            }

            VStack(spacing: 0) {
                content()
            }
        }
        .padding(20)
        .feminineCard()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func languageTitle(_ language: AppLanguage) -> String {
        switch language {
        case .system: return settings.t(.languageSystem)
        case .zhHans: return settings.t(.languageZhHans)
        case .english: return settings.t(.languageEnglish)
        }
    }

    private func appearanceTitle(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return settings.t(.appearanceSystem)
        case .light: return settings.t(.appearanceLight)
        case .dark: return settings.t(.appearanceDark)
        }
    }
}

struct SettingsToggleRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(SwitchToggleStyle(tint: palette.deepRose))
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsOptionRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(palette.deepRose)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
