import SwiftUI
import SwiftUI
import SwiftData


struct MacNoteDetailView: View {
    let noteId: String
    let onDelete: () -> Void

    @Query private var notes: [Note]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Environment(\.modelContext) private var modelContext

    @State private var title   = ""
    @State private var content = ""
    @State private var folderId: String?
    @State private var isRendered = false
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var editorFocused: Bool

    private var note: Note? { notes.first { $0.id == noteId } }

    var body: some View {
        Group {
            if let note {
                VSplitView {
                    // Header: title + toolbar row
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Title", text: $title)
                            .font(.title2.bold())
                            .textFieldStyle(.plain)
                            .padding([.horizontal, .top], 16)
                            .onChange(of: title) { _, _ in scheduleSave(note) }

                        // Tags
                        if !note.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(note.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(.quaternary)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.top, 6)
                        }
                        Divider().padding(.top, 8)
                    }
                    .frame(minHeight: 60)

                    // Body: plaintext editor or rendered view
                    if isRendered {
                        MarkdownTextView(content: content)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        TextEditor(text: $content)
                            .font(.body)
                            .focused($editorFocused)
                            .padding(8)
                            .onChange(of: content) { _, _ in scheduleSave(note) }
                    }
                }
                .onAppear {
                    title    = note.title
                    content  = note.content
                    folderId = note.folderId
                }
                .onChange(of: noteId) { _, _ in
                    // Note switched — reload fields
                    if let n = notes.first(where: { $0.id == noteId }) {
                        title    = n.title
                        content  = n.content
                        folderId = n.folderId
                    }
                }
                .toolbar {
                    // Plaintext ↔ rendered toggle
                    ToolbarItem {
                        Button {
                            withAnimation { isRendered.toggle() }
                        } label: {
                            Label(
                                isRendered ? "Edit" : "Preview",
                                systemImage: isRendered ? "pencil" : "eye"
                            )
                        }
                        .help(isRendered ? "Switch to editor" : "Render markdown")
                    }

                    // Folder picker
                    ToolbarItem {
                        Menu {
                            Button("No Folder") {
                                folderId = nil
                                if let n = note as Note? { scheduleSave(n) }
                            }
                            Divider()
                            ForEach(folders) { folder in
                                Button(folder.name) {
                                    folderId = folder.id
                                    if let n = note as Note? { scheduleSave(n) }
                                }
                            }
                        } label: {
                            Label("Folder", systemImage: "folder")
                        }
                        .help("Move to folder")
                    }

                    // Delete
                    ToolbarItem {
                        Button(role: .destructive) {
                            deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .help("Delete note")
                    }
                }
            } else {
                ContentUnavailableView("Note not found", systemImage: "note.text.badge.plus")
            }
        }
        .navigationTitle(note?.title ?? "")
    }

    // MARK: - Save

    private func scheduleSave(_ note: Note) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await saveNote(note)
        }
    }

    private func saveNote(_ note: Note) async {
        note.title    = title
        note.content  = content
        note.folderId = folderId
        note.updatedAt = .now
        note.pendingSync = true
        try? modelContext.save()

        do {
            let dto = try await APIClient.shared.updateNote(id: note.id, title: title, content: content, folderId: folderId)
            note.tags      = dto.tags
            note.updatedAt = dto.updatedAt
            note.pendingSync = false
            try? modelContext.save()
        } catch {
            struct Body: Encodable { let title: String; let content: String; let folderId: String? }
            let body = try? JSONEncoder().encode(Body(title: title, content: content, folderId: folderId))
            modelContext.insert(SyncOperation(method: "PUT", path: "/api/notes/\(note.id)", body: body))
            try? modelContext.save()
        }
    }

    private func deleteNote(_ note: Note) {
        let id = note.id
        modelContext.delete(note)
        try? modelContext.save()
        onDelete()
        Task {
            do { try await APIClient.shared.deleteNote(id: id) }
            catch { modelContext.insert(SyncOperation(method: "DELETE", path: "/api/notes/\(id)")) }
            try? modelContext.save()
        }
    }
}
