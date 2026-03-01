import SwiftUI
import SwiftData

/// Column 1 of the 3-column split view.
/// Top: section picker (Notes / Tasks).
/// Below: folder+tag tree (Notes) or task list picker (Tasks).
struct MacSidebarColumn: View {
    @Binding var section: AppSection
    @Binding var noteFilter: NotesFilter
    @Binding var selectedListId: String?

    @Query(sort: \Folder.name)        private var folders: [Folder]
    @Query(sort: \TaskList.createdAt) private var lists: [TaskList]
    @Query private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthManager

    @State private var showNewFolderAlert = false
    @State private var newFolderName      = ""
    @State private var showRenameAlert    = false
    @State private var renamingFolder: Folder?
    @State private var renameName         = ""
    @State private var showNewListAlert   = false
    @State private var newListName        = ""

    private var allTags: [String] {
        Array(Set(notes.flatMap(\.tags))).sorted()
    }

    var body: some View {
        List {
            // Section switcher
            Section("Section") {
                ForEach(AppSection.allCases) { s in
                    Label(s.rawValue, systemImage: s == .notes ? "note.text" : "checklist")
                        .foregroundStyle(section == s ? .primary : .secondary)
                        .contentShape(Rectangle())
                        .onTapGesture { section = s }
                }
            }

            // Notes sub-navigation
            if section == .notes {
                Section("Notes") {
                    notesSidebarContent
                }
            }

            // Tasks sub-navigation
            if section == .tasks {
                Section("Lists") {
                    tasksListContent
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .toolbar {
            ToolbarItem {
                if section == .notes {
                    Button { showNewFolderAlert = true } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("New Folder")
                } else {
                    Button { showNewListAlert = true } label: {
                        Image(systemName: "plus")
                    }
                    .help("New List")
                }
            }
        }
        // New folder alert
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") { Task { await createFolder() } }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
        // Rename folder alert — triggered by context menu
        .alert("Rename Folder", isPresented: $showRenameAlert) {
            TextField("Folder name", text: $renameName)
            Button("Save") { Task { await renameFolder() } }
            Button("Cancel", role: .cancel) { renamingFolder = nil }
        }
        // New list alert
        .alert("New List", isPresented: $showNewListAlert) {
            TextField("List name", text: $newListName)
            Button("Create") { Task { await createList() } }
            Button("Cancel", role: .cancel) { newListName = "" }
        }
        .onAppear {
            if selectedListId == nil {
                selectedListId = lists.first(where: \.isDefault)?.id ?? lists.first?.id
            }
        }
        .onChange(of: lists) { _, newLists in
            if selectedListId == nil {
                selectedListId = newLists.first(where: \.isDefault)?.id ?? newLists.first?.id
            }
        }
    }

    // MARK: - Notes sidebar content

    @ViewBuilder
    private var notesSidebarContent: some View {
        Label("All Notes", systemImage: "tray.full")
            .foregroundStyle(noteFilter == .all ? .primary : .secondary)
            .contentShape(Rectangle())
            .onTapGesture { noteFilter = .all }

        DisclosureGroup("Folders") {
            ForEach(folders) { folder in
                let isSelected = noteFilter == .folder(folder.id, folder.name)
                Label(folder.name, systemImage: "folder")
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .contentShape(Rectangle())
                    .onTapGesture { noteFilter = .folder(folder.id, folder.name) }
                    .contextMenu {
                        Button("Rename") {
                            renamingFolder = folder
                            renameName = folder.name
                            showRenameAlert = true
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            Task { await deleteFolder(folder) }
                        }
                    }
            }
        }

        if !allTags.isEmpty {
            DisclosureGroup("Tags") {
                ForEach(allTags, id: \.self) { tag in
                    Label("#\(tag)", systemImage: "number")
                        .foregroundStyle(noteFilter == .tag(tag) ? .primary : .secondary)
                        .contentShape(Rectangle())
                        .onTapGesture { noteFilter = .tag(tag) }
                }
            }
        }
    }

    // MARK: - Tasks list content

    @ViewBuilder
    private var tasksListContent: some View {
        ForEach(lists) { list in
            Label(list.name, systemImage: list.isDefault ? "star.fill" : "list.bullet")
                .foregroundStyle(selectedListId == list.id ? .primary : .secondary)
                .contentShape(Rectangle())
                .onTapGesture { selectedListId = list.id }
                .contextMenu {
                    if !list.isDefault {
                        Button("Delete", role: .destructive) {
                            Task { await deleteList(list) }
                        }
                    }
                }
        }
    }

    // MARK: - Actions

    private func createFolder() async {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        newFolderName = ""
        guard !name.isEmpty else { return }
        do {
            let dto = try await APIClient.shared.createFolder(name: name)
            modelContext.insert(Folder(id: dto.id, userId: dto.userId, name: dto.name, createdAt: dto.createdAt))
        } catch {
            let tempId = UUID().uuidString
            modelContext.insert(Folder(id: tempId, userId: auth.userId, name: name))
            let body = try? JSONEncoder().encode(["name": name])
            modelContext.insert(SyncOperation(method: "POST", path: "/api/folders", body: body))
        }
        try? modelContext.save()
    }

    private func renameFolder() async {
        guard let folder = renamingFolder else { return }
        let name = renameName.trimmingCharacters(in: .whitespaces)
        renamingFolder = nil
        guard !name.isEmpty else { return }
        folder.name = name
        try? modelContext.save()
        do {
            _ = try await APIClient.shared.updateFolder(id: folder.id, name: name)
        } catch {
            let body = try? JSONEncoder().encode(["name": name])
            modelContext.insert(SyncOperation(method: "PUT", path: "/api/folders/\(folder.id)", body: body))
            try? modelContext.save()
        }
    }

    private func deleteFolder(_ folder: Folder) async {
        modelContext.delete(folder)
        try? modelContext.save()
        do { try await APIClient.shared.deleteFolder(id: folder.id) }
        catch { modelContext.insert(SyncOperation(method: "DELETE", path: "/api/folders/\(folder.id)")) }
        try? modelContext.save()
    }

    private func createList() async {
        let name = newListName.trimmingCharacters(in: .whitespaces)
        newListName = ""
        guard !name.isEmpty else { return }
        do {
            let dto = try await APIClient.shared.createList(name: name)
            modelContext.insert(TaskList(id: dto.id, userId: dto.userId, name: dto.name, isDefault: dto.isDefault, createdAt: dto.createdAt))
        } catch {
            let tempId = UUID().uuidString
            modelContext.insert(TaskList(id: tempId, userId: auth.userId, name: name))
            let body = try? JSONEncoder().encode(["name": name])
            modelContext.insert(SyncOperation(method: "POST", path: "/api/lists", body: body))
        }
        try? modelContext.save()
    }

    private func deleteList(_ list: TaskList) async {
        if selectedListId == list.id { selectedListId = nil }
        modelContext.delete(list)
        try? modelContext.save()
        do { try await APIClient.shared.deleteList(id: list.id) }
        catch { modelContext.insert(SyncOperation(method: "DELETE", path: "/api/lists/\(list.id)")) }
        try? modelContext.save()
    }
}
