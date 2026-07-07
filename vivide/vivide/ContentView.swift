import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @StateObject private var viewModel = PhotoLibraryViewModel()
    @StateObject private var localLibrary = LocalLibraryViewModel()

    var body: some View {
        TabView {
            albumTab
                .tabItem {
                    Label(settings.t(.tabAlbum), systemImage: "photo.on.rectangle.angled")
                }

            localTab
                .tabItem {
                    Label(settings.t(.tabLocal), systemImage: "internaldrive")
                }

            settingsTab
                .tabItem {
                    Label(settings.t(.tabSettings), systemImage: "gearshape")
                }
        }
        .accentColor(palette.deepRose)
        .onAppear {
            viewModel.checkAuthorization()
            localLibrary.reload()
            viewModel.syncImportedAssets()
            settings.validateImportFolder()
        }
    }

    private var albumTab: some View {
        NavigationView {
            ZStack {
                palette.backgroundGradient.ignoresSafeArea()

                Group {
                    switch viewModel.authState {
                    case .notDetermined:
                        PermissionView(
                            title: settings.t(.permissionExploreTitle),
                            message: settings.t(.permissionExploreMessage),
                            buttonTitle: settings.t(.permissionAllow),
                            action: viewModel.requestAuthorization
                        )
                    case .authorized, .limited:
                        PhotoGridView(viewModel: viewModel, localLibrary: localLibrary)
                    case .denied, .restricted:
                        PermissionView(
                            title: settings.t(.permissionDeniedTitle),
                            message: settings.t(.permissionDeniedMessage),
                            buttonTitle: settings.t(.permissionOpenSettings),
                            action: openSystemSettings
                        )
                    }
                }
            }
            .overlay(alignment: .top) {
                if let message = viewModel.importResultMessage {
                    ImportResultBanner(message: message) {
                        viewModel.clearImportResult()
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.importResultMessage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(palette.rose)
                        Text(viewModel.isSelectionMode ? settings.t(.selectPhotos) : settings.t(.appName))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(palette.textPrimary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.authState == .authorized || viewModel.authState == .limited {
                        importMenu
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var localTab: some View {
        NavigationView {
            ZStack {
                palette.backgroundGradient.ignoresSafeArea()
                LocalLibraryView(viewModel: localLibrary)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var settingsTab: some View {
        NavigationView {
            SettingsView()
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var importMenu: some View {
        if viewModel.isSelectionMode {
            EmptyView()
        } else {
            Menu {
                Button {
                    withAnimation { viewModel.enterSelectionMode() }
                } label: {
                    Label(settings.t(.importSelect), systemImage: "checkmark.circle")
                }

                Button {
                    Task {
                        await viewModel.importFiltered(
                            localLibrary: localLibrary,
                            folderId: settings.importFolderId,
                            settings: settings
                        )
                    }
                } label: {
                    Label(settings.t(.importFiltered), systemImage: "square.and.arrow.down.on.square")
                }
                .disabled(viewModel.photos.isEmpty)
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(palette.deepRose)
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ThemedRootView()
            .environmentObject(AppSettings())
    }
}
