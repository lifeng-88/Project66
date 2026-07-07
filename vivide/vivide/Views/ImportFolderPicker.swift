import SwiftUI

struct ImportFolderPicker: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @Binding var selectedFolderId: String?
    let folders: [ImportFolder]
    let onFoldersChanged: () -> Void

    @State private var showNewFolderSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(settings.t(.importFolderLabel))
                .font(.system(.caption, design: .rounded))
                .foregroundColor(palette.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterChip(
                        title: settings.t(.folderAll),
                        isSelected: selectedFolderId == nil
                    ) {
                        selectedFolderId = nil
                    }

                    ForEach(folders) { folder in
                        FilterChip(
                            title: folder.name,
                            isSelected: selectedFolderId == folder.id
                        ) {
                            selectedFolderId = folder.id
                        }
                    }

                    Button {
                        showNewFolderSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text(settings.t(.newFolder))
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(palette.deepRose)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(palette.rose.opacity(0.12))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet(
                selectedFolderId: $selectedFolderId,
                onCreated: onFoldersChanged
            )
            .environmentObject(settings)
        }
    }
}

private struct NewFolderSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.palette) private var palette
    @Environment(\.presentationMode) private var presentationMode

    @Binding var selectedFolderId: String?
    let onCreated: () -> Void

    @State private var folderName = ""
    @State private var errorKey: L10nKey?
    @FocusState private var nameFieldFocused: Bool

    private var trimmedName: String {
        folderName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationView {
            ZStack {
                palette.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    TextField(settings.t(.newFolderPlaceholder), text: $folderName)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { createFolder() }
                        .padding(.horizontal, 20)

                    if let key = errorKey {
                        Text(settings.t(key))
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                    }

                    Button(action: createFolder) {
                        Text(settings.t(.createFolder))
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                trimmedName.isEmpty
                                    ? AnyView(palette.rose.opacity(0.35))
                                    : AnyView(palette.accentGradient)
                            )
                            .cornerRadius(16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedName.isEmpty)
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle(settings.t(.newFolderTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(settings.t(.cancel)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(palette.textSecondary)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            folderName = ""
            errorKey = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                nameFieldFocused = true
            }
        }
    }

    private func createFolder() {
        errorKey = nil
        guard !trimmedName.isEmpty else {
            errorKey = .folderNameEmpty
            return
        }

        do {
            let folder = try LocalPhotoStorage.createFolder(name: trimmedName)
            selectedFolderId = folder.id
            onCreated()
            presentationMode.wrappedValue.dismiss()
        } catch ImportFolderError.emptyName {
            errorKey = .folderNameEmpty
        } catch ImportFolderError.duplicateName {
            errorKey = .folderNameExists
        } catch {
            errorKey = .folderNameEmpty
        }
    }
}
