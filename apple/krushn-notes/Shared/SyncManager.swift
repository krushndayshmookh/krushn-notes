import Foundation
import SwiftData
import Network
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

private let log = Logger(subsystem: "com.krushn.notes", category: "SyncManager")

// MARK: - SyncManager

/// Handles offline queue flush and delta sync on reconnect / app foreground.
@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var isSyncing = false
    @Published var lastSyncedAt: Date? {
        didSet {
            if let date = lastSyncedAt {
                UserDefaults.standard.set(date, forKey: "lastSyncedAt")
            }
        }
    }

    private var modelContext: ModelContext?
    private let monitor = NWPathMonitor()
    private var isOnline = false
    private var syncTask: Task<Void, Never>?

    private init() {
        lastSyncedAt = UserDefaults.standard.object(forKey: "lastSyncedAt") as? Date
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        startNetworkMonitor()
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied
                if !wasOnline && self.isOnline {
                    log.info("Network restored — starting sync")
                    await self.sync()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.krushn.notes.network"))
    }

    // MARK: - Public sync entry point

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await flushQueue()
            try await deltaSync()
        } catch {
            log.error("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Offline queue flush

    private func flushQueue() async throws {
        guard let ctx = modelContext else { return }

        let ops = try ctx.fetch(FetchDescriptor<SyncOperation>(
            sortBy: [SortDescriptor(\.createdAt)]
        ))

        for op in ops {
            do {
                try await replayOperation(op)
                ctx.delete(op)
                try ctx.save()
            } catch {
                log.error("Failed to replay op \(op.id): \(error.localizedDescription)")
                break // stop on first failure to preserve order
            }
        }
    }

    private func replayOperation(_ op: SyncOperation) async throws {
        let api = APIClient.shared
        switch op.method {
        case "DELETE":
            try await api.requestVoid(method: "DELETE", path: op.path)
        case "POST", "PUT":
            guard let bodyData = op.body else {
                try await api.requestVoid(method: op.method, path: op.path)
                return
            }
            // Replay raw — decode generic JSON and re-encode
            let _: [String: AnyCodable] = try await api.request(
                method: op.method,
                path: op.path,
                body: RawBodyWrapper(data: bodyData)
            )
        default:
            break
        }
    }

    // MARK: - Delta sync

    private func deltaSync() async throws {
        guard let ctx = modelContext else { return }

        let syncResult = try await APIClient.shared.sync(since: lastSyncedAt)

        // Merge folders
        for dto in syncResult.folders {
            let id = dto.id
            let existing = try ctx.fetch(FetchDescriptor<Folder>(
                predicate: #Predicate { $0.id == id }
            )).first

            if let existing {
                existing.name = dto.name
            } else {
                ctx.insert(Folder(id: dto.id, userId: dto.userId, name: dto.name, createdAt: dto.createdAt))
            }
        }

        // Merge notes
        for dto in syncResult.notes {
            let id = dto.id
            let existing = try ctx.fetch(FetchDescriptor<Note>(
                predicate: #Predicate { $0.id == id }
            )).first

            if let existing {
                // Server wins — only update if server is newer
                if dto.updatedAt > existing.updatedAt || !existing.pendingSync {
                    existing.title = dto.title
                    existing.content = dto.content
                    existing.tags = dto.tags
                    existing.folderId = dto.folderId
                    existing.updatedAt = dto.updatedAt
                    existing.pendingSync = false
                }
            } else {
                ctx.insert(Note(
                    id: dto.id, userId: dto.userId, folderId: dto.folderId,
                    title: dto.title, content: dto.content, tags: dto.tags,
                    createdAt: dto.createdAt, updatedAt: dto.updatedAt, pendingSync: false
                ))
            }
        }

        // Merge task lists
        for dto in syncResult.taskLists {
            let id = dto.id
            let existing = try ctx.fetch(FetchDescriptor<TaskList>(
                predicate: #Predicate { $0.id == id }
            )).first

            if let existing {
                existing.name = dto.name
                existing.isDefault = dto.isDefault
            } else {
                ctx.insert(TaskList(id: dto.id, userId: dto.userId, name: dto.name, isDefault: dto.isDefault, createdAt: dto.createdAt))
            }
        }

        // Merge tasks
        for dto in syncResult.tasks {
            let id = dto.id
            let existing = try ctx.fetch(FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.id == id }
            )).first

            if let existing {
                if dto.updatedAt > existing.updatedAt || !existing.pendingSync {
                    existing.content = dto.content
                    existing.completed = dto.completed
                    existing.order = dto.order
                    existing.updatedAt = dto.updatedAt
                    existing.pendingSync = false
                }
            } else {
                ctx.insert(TaskItem(
                    id: dto.id, listId: dto.listId, userId: dto.userId,
                    content: dto.content, completed: dto.completed, order: dto.order,
                    createdAt: dto.createdAt, updatedAt: dto.updatedAt, pendingSync: false
                ))
            }
        }

        try ctx.save()
        lastSyncedAt = .now
        log.info("Delta sync complete — merged \(syncResult.notes.count) notes, \(syncResult.tasks.count) tasks")

        // Write widget data to App Group container
        updateWidgetData(ctx: ctx)
    }

    /// Writes the default task list's tasks to the App Group container so
    /// the WidgetKit extension can read them without a network call.
    private func updateWidgetData(ctx: ModelContext) {
        let defaultList: TaskList? = {
            if let d = try? ctx.fetch(FetchDescriptor<TaskList>(
                predicate: #Predicate { $0.isDefault == true }
            )).first { return d }
            return try? ctx.fetch(FetchDescriptor<TaskList>(
                sortBy: [SortDescriptor(\.createdAt)]
            )).first
        }()
        guard let defaultList else { return }

        let listId = defaultList.id
        let allTasks = (try? ctx.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.listId == listId },
            sortBy: [SortDescriptor(\.order)]
        ))) ?? []

        let widgetTasks = allTasks.map {
            WidgetTask(id: $0.id, content: $0.content, completed: $0.completed, order: $0.order)
        }
        let widgetData = WidgetTaskData(listName: defaultList.name, tasks: widgetTasks, updatedAt: .now)
        AppGroupStore.save(widgetData)

        // Invalidate widget timeline so it picks up the new data
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Queue pending mutation

    func enqueue(method: String, path: String, body: Encodable?) throws {
        guard let ctx = modelContext else { return }
        var bodyData: Data?
        if let body {
            bodyData = try JSONEncoder().encode(body)
        }
        ctx.insert(SyncOperation(method: method, path: path, body: bodyData))
        try ctx.save()
    }
}

// MARK: - Helpers

/// Wraps raw Data as Encodable so we can replay raw JSON bodies.
private struct RawBodyWrapper: Encodable {
    let data: Data
    func encode(to encoder: Encoder) throws {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let reEncoded = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: reEncoded, encoding: .utf8) else { return }
        var container = encoder.singleValueContainer()
        try container.encode(str)
    }
}

/// Minimal AnyCodable for decoding arbitrary JSON responses during queue replay.
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self)    { value = i; return }
        if let d = try? c.decode(Double.self)  { value = d; return }
        if let b = try? c.decode(Bool.self)    { value = b; return }
        if let s = try? c.decode(String.self)  { value = s; return }
        value = NSNull()
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let i as Int:    try c.encode(i)
        case let d as Double: try c.encode(d)
        case let b as Bool:   try c.encode(b)
        case let s as String: try c.encode(s)
        default:              try c.encodeNil()
        }
    }
}
