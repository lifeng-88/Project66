import SwiftUI

@main
struct VivideApp: App {
    @UIApplicationDelegateAdaptor(VivideAppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()
    @ObservedObject private var bSideManager = BSideManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch bSideManager.phase {
                case .loading:
                    AppLaunchLoadingView()
                case .native:
                    ThemedRootView()
                        .environmentObject(settings)
                        .environmentObject(bSideManager)
                        .environment(\.locale, settings.language.locale)
                case .web(let url):
                    BSideView(url: url)
                        .environmentObject(settings)
                        .environmentObject(bSideManager)
                        .environment(\.locale, settings.language.locale)
                        .environment(\.palette, AppTheme.palette(for: settings.resolvedColorScheme(.light)))
                }
            }
            .onOpenURL { url in
                if VividePaymentRedirectReturnURL.matches(url) {
                    VividePaymentCallbackManager.shared.handle(url: url)
                }
            }
            .task {
                await VivideAFManager.shared.initAFAsync(channelId: VivideAppConfig.resolvedChannel())
                await bSideManager.bootstrapFromRemote()
                #if DEBUG
                if BSideConfig.debugEnvURL() != nil,
                   ProcessInfo.processInfo.environment["AUTO_OPEN_B_SIDE"] == "1" {
                    await bSideManager.switchToBSide()
                }
                #endif
            }
        }
    }
}

struct ThemedRootView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var systemScheme

    private var resolvedScheme: ColorScheme {
        settings.resolvedColorScheme(systemScheme)
    }

    var body: some View {
        ContentView()
            .preferredColorScheme(settings.appearance.colorScheme)
            .environment(\.palette, AppTheme.palette(for: resolvedScheme))
    }
}
