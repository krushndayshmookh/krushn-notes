import SwiftUI
import SwiftData
import AppKit

@main
struct krushnNotesApp: App {
    @StateObject private var auth    = AuthManager.shared
    @StateObject private var sync    = SyncManager.shared
    @StateObject private var pusher  = PusherManager.shared
    @StateObject private var panel   = FloatingPanelController.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Folder.self, Note.self, TaskList.self, TaskItem.self, SyncOperation.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // MARK: - Main window
        WindowGroup {
            MacRootView()
                .environmentObject(auth)
                .environmentObject(sync)
                .environmentObject(pusher)
                .environmentObject(panel)
                .onAppear {
                    let ctx = sharedModelContainer.mainContext
                    sync.configure(modelContext: ctx)
                    pusher.configure(modelContext: ctx)
                    panel.configure(modelContext: ctx)
                }
                .task {
                    if auth.isAuthenticated {
                        pusher.connect(userId: auth.userId)
                        await sync.sync()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // ⌘⌥T — toggle floating panel
            CommandMenu("Panel") {
                Button("Toggle Task Panel") {
                    panel.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
            }
        }

        // MARK: - Settings window (⌘,)
        Settings {
            MacSettingsView()
                .environmentObject(auth)
        }
    }
}
