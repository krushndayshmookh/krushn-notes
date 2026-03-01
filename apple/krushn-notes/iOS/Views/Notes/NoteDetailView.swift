import SwiftUI
import SwiftUI
import SwiftData
import Combine


struct NoteDetailView: View {
    let noteId: String
    let onDelete: () -> Void

    @Query private var notes: [Note]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var content = ""
    @State private var folderId: String?
    @State private var isRendered = false
    @State private var saveTask: Task<Void, Never>?

    private var note: Note? {
        notes.first { $0.id == noteId }
    }

    var body: some View {
        Group {
            if let note {
                VStack(spacing: 0) {
                    // Title field
                    TextField("Title", text: $title, axis: .vertical)
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .onChange(of: title) { _, _ in scheduleSave(note) }

                    Divider().padding(.top, 8)

                    // Tags (read-only chips, auto-extracted)
                    if !note.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(note.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.quaternary)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }

                    // Content: plaintext or rendered
                    if isRendered {
                        MarkdownTextView(content: content)
                    } else {
                        TextEditor(text: $content)
                            .font(.body)
                            .padding(.horizontal, 8)
                            .onChange(of: content) { _, _ in scheduleSave(note) }
                    }
                }
                .onAppear {
                    title = note.title
                    content = note.content
                    folderId = note.folderId
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            // Folder picker
                            Menu("Move to Folder") {
                                Button("No Folder") {
                                    folderId = nil
                                    scheduleSave(note)
                                }
                                ForEach(folders) { folder in
                                    Button(folder.name) {
                                        folderId = folder.id
                                        scheduleSave(note)
                                    }
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                deleteNote(note)
                            } label: {
                                Label("Delete Note", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation { isRendered.toggle() }
                        } label: {
                            Image(systemName: isRendered ? "pencil" : "eye")
                        }
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Note not found", systemImage: "note.text.badge.plus")
            }
        }
    }

    // MARK: - Debounced save

    private func scheduleSave(_ note: Note) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await saveNote(note)
        }
    }

    private func saveNote(_ note: Note) async {
        note.title = title
        note.content = content
        note.folderId = folderId
        note.updatedAt = .now
        note.pendingSync = true
        try? modelContext.save()

        do {
            let dto = try await APIClient.shared.updateNote(id: note.id, title: title, content: content, folderId: folderId)
            note.tags = dto.tags
            note.updatedAt = dto.updatedAt
            note.pendingSync = false
            try? modelContext.save()
        } catch {
            // Remains pendingSync = true — SyncManager will retry
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
            do {
                try await APIClient.shared.deleteNote(id: id)
            } catch {
                modelContext.insert(SyncOperation(method: "DELETE", path: "/api/notes/\(id)"))
                try? modelContext.save()
            }
        }
    }
}
