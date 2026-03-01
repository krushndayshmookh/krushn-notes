import Foundation
import SwiftData
import OSLog

private let log = Logger(subsystem: "com.krushn.notes", category: "PusherManager")

// NOTE: PusherManager wraps the PusherSwift SDK.
// Add via SPM: https://github.com/pusher/pusher-websocket-swift  (package: "pusher-websocket-swift")
// Import: import PusherSwift

// MARK: - PusherManager

/// Connects to Pusher Channels, subscribes to the private user channel,
/// and merges incoming events into SwiftData.
@MainActor
final class PusherManager: ObservableObject {
    static let shared = PusherManager()

    @Published var isConnected = false

    private var modelContext: ModelContext?

    // MARK: Pusher config (from Info.plist → Config.xcconfig)
    private let pusherKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "PUSHER_KEY") as? String ?? ""
    }()
    private let pusherCluster: String = {
        Bundle.main.object(forInfoDictionaryKey: "PUSHER_CLUSTER") as? String ?? "us2"
    }()

    // NOTE: Uncomment and fill in once PusherSwift SPM package is added:
    // private var pusher: Pusher?
    // private var channel: PusherChannel?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Connect

    func connect(userId: String) {
        // TODO: Uncomment after adding PusherSwift via SPM
        /*
        let options = PusherClientOptions(
            authMethod: .authRequestBuilder(authRequestBuilder: PusherAuthBuilder()),
            host: .cluster(pusherCluster)
        )
        pusher = Pusher(key: pusherKey, options: options)
        pusher?.connection.delegate = self

        pusher?.connect()

        channel = pusher?.subscribe("private-user-\(userId)")
        bindEvents()
        */

        log.info("PusherManager.connect() called for userId: \(userId). Add PusherSwift via SPM to enable.")
    }

    func disconnect() {
        // pusher?.disconnect()
        isConnected = false
    }

    // MARK: - Event binding

    private func bindEvents() {
        // NOTE: Uncomment after adding PusherSwift via SPM
        /*
        let events = [
            "folder:created", "folder:updated", "folder:deleted",
            "note:created",   "note:updated",   "note:deleted",
            "task:created",   "task:updated",   "task:deleted",
            "list:created",   "list:updated",   "list:deleted"
        ]
        for event in events {
            channel?.bind(eventName: event) { [weak self] event in
                self?.handleEvent(name: event.eventName, data: event.data)
            }
        }
        */
    }

    private func handleEvent(name: String, data: String?) {
        guard let ctx = modelContext,
              let data = data?.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            switch name {
            case "folder:created", "folder:updated":
                let dto = try decoder.decode(FolderDTO.self, from: data)
                upsertFolder(dto, ctx: ctx)

            case "folder:deleted":
                struct IDPayload: Decodable { let id: String }
                let p = try decoder.decode(IDPayload.self, from: data)
                deleteFolder(id: p.id, ctx: ctx)

            case "note:created", "note:updated":
                let dto = try decoder.decode(NoteDTO.self, from: data)
                upsertNote(dto, ctx: ctx)

            case "note:deleted":
                struct IDPayload: Decodable { let id: String }
                let p = try decoder.decode(IDPayload.self, from: data)
                deleteNote(id: p.id, ctx: ctx)

            case "list:created", "list:updated":
                let dto = try decoder.decode(TaskListDTO.self, from: data)
                upsertTaskList(dto, ctx: ctx)

            case "list:deleted":
                struct IDPayload: Decodable { let id: String }
                let p = try decoder.decode(IDPayload.self, from: data)
                deleteTaskList(id: p.id, ctx: ctx)

            case "task:created", "task:updated":
                let dto = try decoder.decode(TaskDTO.self, from: data)
                upsertTask(dto, ctx: ctx)

            case "task:deleted":
                struct IDPayload: Decodable { let id: String }
                let p = try decoder.decode(IDPayload.self, from: data)
                deleteTask(id: p.id, ctx: ctx)

            default:
                break
            }

            try ctx.save()
        } catch {
            log.error("Failed to handle event \(name): \(error.localizedDescription)")
        }
    }

    // MARK: - SwiftData upserts

    private func upsertFolder(_ dto: FolderDTO, ctx: ModelContext) {
        let id = dto.id
        if let existing = try? ctx.fetch(FetchDescriptor<Folder>(
            predicate: #Predicate { $0.id == id }
        )).first {
            existing.name = dto.name
        } else {
            ctx.insert(Folder(id: dto.id, userId: dto.userId, name: dto.name, createdAt: dto.createdAt))
        }
    }

    private func deleteFolder(id: String, ctx: ModelContext) {
        guard let item = try? ctx.fetch(FetchDescriptor<Folder>(
            predicate: #Predicate { $0.id == id }
        )).first else { return }
        ctx.delete(item)
    }

    private func upsertNote(_ dto: NoteDTO, ctx: ModelContext) {
        let id = dto.id
        if let existing = try? ctx.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == id }
        )).first {
            existing.title = dto.title
            existing.content = dto.content
            existing.tags = dto.tags
            existing.folderId = dto.folderId
            existing.updatedAt = dto.updatedAt
            existing.pendingSync = false
        } else {
            ctx.insert(Note(
                id: dto.id, userId: dto.userId, folderId: dto.folderId,
                title: dto.title, content: dto.content, tags: dto.tags,
                createdAt: dto.createdAt, updatedAt: dto.updatedAt, pendingSync: false
            ))
        }
    }

    private func deleteNote(id: String, ctx: ModelContext) {
        guard let item = try? ctx.fetch(FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == id }
        )).first else { return }
        ctx.delete(item)
    }

    private func upsertTaskList(_ dto: TaskListDTO, ctx: ModelContext) {
        let id = dto.id
        if let existing = try? ctx.fetch(FetchDescriptor<TaskList>(
            predicate: #Predicate { $0.id == id }
        )).first {
            existing.name = dto.name
            existing.isDefault = dto.isDefault
        } else {
            ctx.insert(TaskList(id: dto.id, userId: dto.userId, name: dto.name, isDefault: dto.isDefault, createdAt: dto.createdAt))
        }
    }

    private func deleteTaskList(id: String, ctx: ModelContext) {
        guard let item = try? ctx.fetch(FetchDescriptor<TaskList>(
            predicate: #Predicate { $0.id == id }
        )).first else { return }
        ctx.delete(item)
    }

    private func upsertTask(_ dto: TaskDTO, ctx: ModelContext) {
        let id = dto.id
        if let existing = try? ctx.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == id }
        )).first {
            existing.content = dto.content
            existing.completed = dto.completed
            existing.order = dto.order
            existing.updatedAt = dto.updatedAt
            existing.pendingSync = false
        } else {
            ctx.insert(TaskItem(
                id: dto.id, listId: dto.listId, userId: dto.userId,
                content: dto.content, completed: dto.completed, order: dto.order,
                createdAt: dto.createdAt, updatedAt: dto.updatedAt, pendingSync: false
            ))
        }
    }

    private func deleteTask(id: String, ctx: ModelContext) {
        guard let item = try? ctx.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == id }
        )).first else { return }
        ctx.delete(item)
    }
}

// MARK: - Pusher connection delegate stub
// NOTE: Uncomment after adding PusherSwift via SPM
/*
extension PusherManager: PusherDelegate {
    nonisolated func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        Task { @MainActor in
            self.isConnected = (new == .connected)
        }
    }

    nonisolated func failedToSubscribeToChannel(name: String, response: URLResponse?, data: String?, error: NSError?) {
        log.error("Failed to subscribe to \(name): \(error?.localizedDescription ?? "unknown")")
    }
}
*/

// MARK: - Pusher auth request builder stub
/*
final class PusherAuthBuilder: AuthRequestBuilderProtocol {
    func requestFor(socketID: String, channelName: String) -> URLRequest? {
        guard let token = Keychain.loadToken(),
              let url = URL(string: APIClient.shared.baseURL + "/auth/pusher") else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode([
            "socket_id": socketID,
            "channel_name": channelName
        ])
        return req
    }
}
*/
