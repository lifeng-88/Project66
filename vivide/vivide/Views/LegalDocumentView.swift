import SwiftUI

struct LegalDocumentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette

    let document: LegalDocumentType

    private var languageCode: String {
        settings.language.l10nCode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(LegalDocuments.sections(for: document, languageCode: languageCode)) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(palette.textPrimary)
                        Text(section.body)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .feminineCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(palette.backgroundGradient.ignoresSafeArea())
        .navigationTitle(LegalDocuments.title(for: document, languageCode: languageCode))
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
    }
}

struct SettingsLinkRow: View {
    @Environment(\.palette) private var palette
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(palette.deepRose)
                .frame(width: 24)

            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(palette.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(palette.textSecondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
