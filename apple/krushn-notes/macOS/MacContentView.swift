import SwiftUI

// The three columns:
//   1. Section picker  (Notes / Tasks)
//   2. List            (folders+tags or task lists — depends on section)
//   3. Detail          (note editor or task list)

enum AppSection: String, CaseIterable, Identifiable {
    case notes = "Notes"
    case tasks = "Tasks"
    var id: String { rawValue }
}

struct MacContentView: View {
    @State private var section: AppSection = .notes
    @State private var noteFilter: NotesFilter = .all
    @State private var selectedListId: String?
    @State private var selectedNoteId: String?
    @EnvironmentObject private var sync: SyncManager

    var body: some View {
        NavigationSplitView {
            // Column 1 — section + sidebar content
            MacSidebarColumn(
                section: $section,
                noteFilter: $noteFilter,
                selectedListId: $selectedListId
            )
        } content: {
            // Column 2 — note list or task list
            switch section {
            case .notes:
                MacNoteListView(filter: noteFilter, selectedNoteId: $selectedNoteId)
            case .tasks:
                if let listId = selectedListId {
                    MacTaskListView(listId: listId)
                } else {
                    ContentUnavailableView("Select a list", systemImage: "checklist")
                }
            }
        } detail: {
            // Column 3 — note editor (tasks are inline in column 2 on mac)
            switch section {
            case .notes:
                if let noteId = selectedNoteId {
                    MacNoteDetailView(noteId: noteId, onDelete: { selectedNoteId = nil })
                } else {
                    ContentUnavailableView("Select a note", systemImage: "note.text")
                }
            case .tasks:
                ContentUnavailableView("Tasks are shown in the list", systemImage: "checklist")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if sync.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .help("Syncing…")
                }
            }
        }
    }
}
