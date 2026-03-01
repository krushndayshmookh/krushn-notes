import SwiftUI
import SwiftUI
import SwiftData


struct NoteListView: View {
    let filter: NotesFilter
    @Binding var selectedNoteId: String?

    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthManager

    private var filteredNotes: [Note] {
        switch filter {
        case .all:
            return allNotes
        case .folder(let id, _):
            return allNotes.filter { $0.folderId == id }
        case .tag(let tag):
            return allNotes.filter { $0.tags.contains(tag) }
        }
    }

    private var title: String {
        switch filter {
        case .all:           return "All Notes"
        case .folder(_, let name): return name
        case .tag(let tag): return "#\(tag)"
        }
    }

    var body: some View {
        Group {
            if filteredNotes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes", systemImage: "note.text")
                } description: {
                    Text("Tap + to create your first note.")
                }
            } else {
                List(filteredNotes, selection: $selectedNoteId) { note in
                    NoteRow(note: note)
                        .tag(note.id)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await deleteNote(note) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await createNote() }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }

    private func createNote() async {
        let folderId: String? = {
            if case .folder(let id, _) = filter { return id }
            return nil
        }()

        do {
            let dto = try await APIClient.shared.createNote(title: "Untitled", content: "", folderId: folderId)
            let note = Note(
                id: dto.id, userId: dto.userId, folderId: dto.folderId,
                title: dto.title, content: dto.content, tags: dto.tags,
                createdAt: dto.createdAt, updatedAt: dto.updatedAt, pendingSync: false
            )
            modelContext.insert(note)
            try modelContext.save()
            selectedNoteId = dto.id
        } catch {
            // Offline: create locally with temp id
            let tempId = UUID().uuidString
            let note = Note(id: tempId, userId: auth.userId, folderId: folderId, title: "Untitled", content: "", pendingSync: true)
            modelContext.insert(note)

            let body = try? JSONEncoder().encode(["title": "Untitled", "content": "", "folderId": folderId ?? ""])
            modelContext.insert(SyncOperation(method: "POST", path: "/api/notes", body: body))
            try? modelContext.save()
            selectedNoteId = tempId
        }
    }

    private func deleteNote(_ note: Note) async {
        let id = note.id
        modelContext.delete(note)
        try? modelContext.save()
        if selectedNoteId == id { selectedNoteId = nil }

        do {
            try await APIClient.shared.deleteNote(id: id)
        } catch {
            modelContext.insert(SyncOperation(method: "DELETE", path: "/api/notes/\(id)"))
            try? modelContext.save()
        }
    }
}

// MARK: - NoteRow

struct NoteRow: View {
    let note: Note

    private var preview: String {
        let lines = note.content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.dropFirst().prefix(2).joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if note.pendingSync {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !preview.isEmpty {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(note.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
