import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sync: SyncManager

    var body: some View {
        TabView {
            NotesTab()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }

            TasksTab()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
        }
        .overlay(alignment: .top) {
            if sync.isSyncing {
                SyncIndicator()
            }
        }
    }
}

private struct SyncIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text("Syncing…")
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
