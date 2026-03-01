import SwiftUI
import SwiftData

// MARK: - NotesTab

struct NotesTab: View {
    @State private var filter: NotesFilter = .all
    @State private var selectedNoteId: String?
    @State private var showNewNote = false
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NotesSidebar(filter: $filter)
        } content: {
            NoteListView(filter: filter, selectedNoteId: $selectedNoteId)
        } detail: {
            if let noteId = selectedNoteId {
                NoteDetailView(noteId: noteId, onDelete: { selectedNoteId = nil })
            } else {
                ContentUnavailableView("Select a note", systemImage: "note.text")
            }
        }
    }
}
