import SwiftUI

struct FolderManageSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @ObservedObject var viewModel: LocalLibraryViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var folderToRename: ImportFolder?
    @State private var folderToDelete: ImportFolder?
    @State private var showDeleteDialog = false
    @State private var renameText = ""
    @State private var folderErrorKey: L10nKey?

    var body: some View {
        NavigationView {
            Group {
                if viewModel.folders.isEmpty {
                    emptyState
                } else {
                    folderList
                }
            }
            .background(palette.backgroundGradient.ignoresSafeArea())
            .navigationTitle(settings.t(.manageFolders))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(settings.t(.done)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(palette.deepRose)
                }
            }
            .sheet(item: $folderToRename) { folder in
                renameSheet(for: folder)
            }
            .confirmationDialog(
                settings.t(.deleteFolderTitle),
                isPresented: $showDeleteDialog,
                presenting: folderToDelete
            ) { folder in
                if viewModel.count(in: folder.id) == 0 {
                    Button(settings.t(.delete), role: .destructive) {
                        performDelete(folder: folder, deletePhotos: false)
                    }
                } else {
                    Button(settings.t(.moveToAll)) {
                        performDelete(folder: folder, deletePhotos: false)
                    }
                    Button(settings.t(.deleteFolderAndPhotos), role: .destructive) {
                        performDelete(folder: folder, deletePhotos: true)
                    }
                }
                Button(settings.t(.cancel), role: .cancel) {
                    folderToDelete = nil
                }
            } message: { folder in
                Text(deleteMessage(for: folder))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(palette.lavender)
            Text(settings.t(.noCustomFolders))
                .font(.system(.body, design: .rounded))
                .foregroundColor(palette.textSecondary)
        }
        .padding(.top, 80)
    }

    private var folderList: some View {
        List {
            ForEach(viewModel.folders) { folder in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(palette.rose.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "folder.fill")
                            .foregroundColor(palette.deepRose)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(folder.name)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(palette.textPrimary)
                        Text(settings.format(.folderPhotoCount, viewModel.count(in: folder.id)))
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(palette.textSecondary)
                    }

                    Spacer()

                    Menu {
                        Button {
                            renameText = folder.name
                            folderErrorKey = nil
                            folderToRename = folder
                        } label: {
                            Label(settings.t(.renameFolder), systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            folderToDelete = folder
                            showDeleteDialog = true
                        } label: {
                            Label(settings.t(.deleteFolder), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(palette.deepRose)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(palette.cardHighlight.opacity(0.5))
            }
        }
        .listStyle(.insetGrouped)
    }

    private func renameSheet(for folder: ImportFolder) -> some View {
        NavigationView {
            ZStack {
                palette.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    TextField(settings.t(.newFolderPlaceholder), text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 20)

                    if let key = folderErrorKey {
                        Text(settings.t(key))
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                    }

                    Button {
                        performRename(folder: folder)
                    } label: {
                        Text(settings.t(.save))
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(palette.accentGradient)
                            .cornerRadius(16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle(settings.t(.renameFolderTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(settings.t(.cancel)) {
                        folderToRename = nil
                    }
                    .foregroundColor(palette.textSecondary)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func deleteMessage(for folder: ImportFolder) -> String {
        let count = viewModel.count(in: folder.id)
        if count == 0 {
            return settings.format(.deleteEmptyFolderMessage, folder.name)
        }
        return settings.format(.deleteFolderMessage, folder.name, count)
    }

    private func performRename(folder: ImportFolder) {
        do {
            _ = try viewModel.renameFolder(id: folder.id, name: renameText)
            folderToRename = nil
        } catch ImportFolderError.emptyName {
            folderErrorKey = .folderNameEmpty
        } catch ImportFolderError.duplicateName {
            folderErrorKey = .folderNameExists
        } catch {
            folderErrorKey = .folderNameEmpty
        }
    }

    private func performDelete(folder: ImportFolder, deletePhotos: Bool) {
        try? viewModel.deleteFolder(id: folder.id, deletePhotos: deletePhotos, settings: settings)
        folderToDelete = nil
        showDeleteDialog = false
        if viewModel.folders.isEmpty {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
