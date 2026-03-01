import SwiftUI
import SwiftData

@main
struct krushnNotesApp: App {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var sync = SyncManager.shared
    @StateObject private var pusher = PusherManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Folder.self,
            Note.self,
            TaskList.self,
            TaskItem.self,
            SyncOperation.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(sync)
                .environmentObject(pusher)
                .onAppear {
                    let ctx = sharedModelContainer.mainContext
                    sync.configure(modelContext: ctx)
                    pusher.configure(modelContext: ctx)
                }
                .task {
                    if auth.isAuthenticated {
                        pusher.connect(userId: auth.userId)
                        await sync.sync()
                    }
                }
                .onOpenURL { url in
                    // krushnnotes://auth?token=<jwt>
                    // Handled by ASWebAuthenticationSession automatically,
                    // but kept here for manual deep link handling if needed.
                    guard url.scheme == "krushnnotes",
                          url.host == "auth",
                          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let token = components.queryItems?.first(where: { $0.name == "token" })?.value
                    else { return }

                    Keychain.saveToken(token)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
