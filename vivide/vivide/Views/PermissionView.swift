import SwiftUI

struct PermissionView: View {
    @Environment(\.palette) private var palette

    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(palette.accentGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: palette.lavender.opacity(0.4), radius: 16, y: 8)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(palette.textPrimary)

                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(palette.accentGradient)
                    .cornerRadius(16)
                    .shadow(color: palette.rose.opacity(0.35), radius: 10, y: 5)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding()
    }
}
