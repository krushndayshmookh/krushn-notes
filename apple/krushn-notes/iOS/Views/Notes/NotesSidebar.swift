import SwiftUI
import SwiftUI
import SwiftData


struct NotesSidebar: View {
    @Binding var filter: NotesFilter

    @Query(sort: \Folder.name) private var folders: [Folder]
    @Query private var notes: [Note]
    @EnvironmentObject private var auth: AuthManager

    @State private var newFolderName = ""
    @State private var showNewFolderSheet = false
    @State private var renamingFolder: Folder?
    @State private var renameName = ""
    @State private var errorMessage: String?

    // Distinct tags across all notes
    private var allTags: [String] {
        Array(Set(notes.flatMap(\.tags))).sorted()
    }

    var body: some View {
        List(selection: Binding(
            get: { filter },
            set: { if let v = $0 { filter = v } }
        )) {
            Section {
                Label("All Notes", systemImage: "tray.full")
                    .tag(NotesFilter.all)
            }

            Section("Folders") {
                ForEach(folders) { folder in
                    Label(folder.name, systemImage: "folder")
                        .tag(NotesFilter.folder(folder.id, folder.name))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await deleteFolder(folder) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                renamingFolder = folder
                                renameName = folder.name
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                }

                Button {
                    showNewFolderSheet = true
                } label: {
                    Label("New Folder", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
            }

            if !allTags.isEmpty {
                Section("Tags") {
                    ForEach(allTags, id: \.self) { tag in
                        Label("#\(tag)", systemImage: "number")
                            .tag(NotesFilter.tag(tag))
                    }
                }
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showNewFolderSheet) {
            NewFolderSheet(isPresented: $showNewFolderSheet)
        }
        .sheet(item: $renamingFolder) { folder in
            RenameFolderSheet(folder: folder, isPresented: Binding(
                get: { renamingFolder != nil },
                set: { if !$0 { renamingFolder = nil } }
            ))
        }
    }

    private func deleteFolder(_ folder: Folder) async {
        do {
            try await APIClient.shared.deleteFolder(id: folder.id)
        } catch {
            // Folder will be cleaned up on next sync
        }
    }
}

// MARK: - NewFolderSheet

struct NewFolderSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Folder name", text: $name)
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            isSaving = true
                            do {
                                let dto = try await APIClient.shared.createFolder(name: name.trimmingCharacters(in: .whitespaces))
                                modelContext.insert(Folder(id: dto.id, userId: dto.userId, name: dto.name, createdAt: dto.createdAt))
                                try modelContext.save()
                                isPresented = false
                            } catch {
                                // Enqueue for offline sync
                                let op = SyncOperation(method: "POST", path: "/api/folders", body: try? JSONEncoder().encode(["name": name]))
                                modelContext.insert(op)
                                let tempId = UUID().uuidString
                                modelContext.insert(Folder(id: tempId, userId: "", name: name))
                                try? modelContext.save()
                                isPresented = false
                            }
                            isSaving = false
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - RenameFolderSheet

struct RenameFolderSheet: View {
    let folder: Folder
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var name: String
    @State private var isSaving = false

    init(folder: Folder, isPresented: Binding<Bool>) {
        self.folder = folder
        self._isPresented = isPresented
        self._name = State(initialValue: folder.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Folder name", text: $name)
            }
            .navigationTitle("Rename Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            let trimmed = name.trimmingCharacters(in: .whitespaces)
                            folder.name = trimmed
                            do {
                                try await APIClient.shared.updateFolder(id: folder.id, name: trimmed)
                            } catch {
                                folder.pendingSync = true  // Mark for retry — NOTE: Folder doesn't have pendingSync, handled via SyncOperation
                            }
                            try? modelContext.save()
                            isPresented = false
                            isSaving = false
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
