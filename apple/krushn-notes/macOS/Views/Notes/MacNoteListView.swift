import SwiftUI
import SwiftUI
import SwiftData


struct MacNoteListView: View {
    let filter: NotesFilter
    @Binding var selectedNoteId: String?

    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthManager

    private var filteredNotes: [Note] {
        switch filter {
        case .all:                     return allNotes
        case .folder(let id, _):       return allNotes.filter { $0.folderId == id }
        case .tag(let tag):            return allNotes.filter { $0.tags.contains(tag) }
        }
    }

    private var title: String {
        switch filter {
        case .all:                return "All Notes"
        case .folder(_, let n):  return n
        case .tag(let t):        return "#\(t)"
        }
    }

    var body: some View {
        Group {
            if filteredNotes.isEmpty {
                ContentUnavailableView("No Notes", systemImage: "note.text")
            } else {
                List(filteredNotes, selection: $selectedNoteId) { note in
                    MacNoteRow(note: note)
                        .tag(note.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await deleteNote(note) }
                            }
                        }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { Task { await createNote() } } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Note")
            }
        }
        .navigationTitle(title)
    }

    private func createNote() async {
        let folderId: String? = {
            if case .folder(let id, _) = filter { return id }
            return nil
        }()
        do {
            let dto = try await APIClient.shared.createNote(title: "Untitled", content: "", folderId: folderId)
            let note = Note(id: dto.id, userId: dto.userId, folderId: dto.folderId,
                            title: dto.title, content: dto.content, tags: dto.tags,
                            createdAt: dto.createdAt, updatedAt: dto.updatedAt, pendingSync: false)
            modelContext.insert(note)
            try modelContext.save()
            selectedNoteId = dto.id
        } catch {
            let tempId = UUID().uuidString
            let note = Note(id: tempId, userId: auth.userId, folderId: folderId,
                            title: "Untitled", content: "", pendingSync: true)
            modelContext.insert(note)
            let body = try? JSONEncoder().encode(["title": "Untitled", "content": "", "folderId": folderId ?? ""])
            modelContext.insert(SyncOperation(method: "POST", path: "/api/notes", body: body))
            try? modelContext.save()
            selectedNoteId = tempId
        }
    }

    private func deleteNote(_ note: Note) async {
        let id = note.id
        if selectedNoteId == id { selectedNoteId = nil }
        modelContext.delete(note)
        try? modelContext.save()
        do { try await APIClient.shared.deleteNote(id: id) }
        catch { modelContext.insert(SyncOperation(method: "DELETE", path: "/api/notes/\(id)")) }
        try? modelContext.save()
    }
}

// MARK: - MacNoteRow

struct MacNoteRow: View {
    let note: Note

    private var preview: String {
        note.content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .dropFirst()
            .prefix(1)
            .joined()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                if note.pendingSync {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                ForEach(note.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
