import SwiftUI
import WebKit

struct BSideView: View {
    let url: URL

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var bSideManager: BSideManager
    @Environment(\.palette) private var palette
    @StateObject private var viewModel: BSideViewModel

    init(url: URL) {
        self.url = url
        _viewModel = StateObject(wrappedValue: BSideViewModel(pageURL: url))
    }

    var body: some View {
        ZStack {
            BSideWebView(viewModel: viewModel)
                .opacity(viewModel.isReady ? 1 : 0)
                .ignoresSafeArea(edges: .bottom)

            if !viewModel.isReady, viewModel.errorMessage == nil {
                BSideLoadingView()
            }

            if let errorMessage = viewModel.errorMessage {
                BSideErrorView(message: errorMessage) {
                    viewModel.reload()
                }
            }
        }
        .background(Color("LaunchBackground"))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay(alignment: .topTrailing) {
            Button(action: bSideManager.switchToNative) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .padding(.top, 8)
            .accessibilityLabel(settings.t(.bsideClose))
        }
    }
}

struct AppLaunchLoadingView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.2)
        }
    }
}

private struct BSideWebView: UIViewRepresentable {
    @ObservedObject var viewModel: BSideViewModel

    func makeUIView(context: Context) -> WKWebView {
        viewModel.loadIfNeeded()
        return viewModel.webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

private struct BSideLoadingView: View {
    var body: some View {
        Image("LaunchIllustration")
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 160)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("LaunchBackground"))
    }
}

private struct BSideErrorView: View {
    @EnvironmentObject private var settings: AppSettings
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(settings.t(.bsideLoadFailed))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button(action: retry) {
                Text(settings.t(.retry))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 128, height: 46)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("LaunchBackground"))
    }
}
