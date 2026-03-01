import Foundation
import Foundation
import SwiftData

// MARK: - Filter Types

enum NotesFilter: Hashable {
    case all
    case folder(String, String)  // (id, name)
    case tag(String)
}

// MARK: - SwiftData Models

@Model
final class Folder {
    @Attribute(.unique) var id: String
    var userId: String
    var name: String
    var createdAt: Date

    init(id: String, userId: String, name: String, createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class Note {
    @Attribute(.unique) var id: String
    var userId: String
    var folderId: String?
    var title: String
    var content: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var pendingSync: Bool

    init(
        id: String,
        userId: String,
        folderId: String? = nil,
        title: String,
        content: String,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pendingSync: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.folderId = folderId
        self.title = title
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
    }
}

@Model
final class TaskList {
    @Attribute(.unique) var id: String
    var userId: String
    var name: String
    var isDefault: Bool
    var createdAt: Date

    init(id: String, userId: String, name: String, isDefault: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

@Model
final class TaskItem {
    @Attribute(.unique) var id: String
    var listId: String
    var userId: String
    var content: String
    var completed: Bool
    var order: Int
    var createdAt: Date
    var updatedAt: Date
    var pendingSync: Bool

    init(
        id: String,
        listId: String,
        userId: String,
        content: String,
        completed: Bool = false,
        order: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pendingSync: Bool = false
    ) {
        self.id = id
        self.listId = listId
        self.userId = userId
        self.content = content
        self.completed = completed
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
    }
}

// Stores pending offline mutations to be replayed in order
@Model
final class SyncOperation {
    @Attribute(.unique) var id: String
    var method: String       // "POST", "PUT", "DELETE"
    var path: String         // e.g. "/api/notes/abc123"
    var body: Data?          // JSON-encoded body for POST/PUT
    var createdAt: Date

    init(id: String = UUID().uuidString, method: String, path: String, body: Data? = nil) {
        self.id = id
        self.method = method
        self.path = path
        self.body = body
        self.createdAt = .now
    }
}

// MARK: - API Response DTOs (Codable, not SwiftData)

struct FolderDTO: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, name, createdAt
    }
}

struct NoteDTO: Codable, Identifiable {
    let id: String
    let userId: String
    let folderId: String?
    let title: String
    let content: String
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, folderId, title, content, tags, createdAt, updatedAt
    }
}

struct TaskListDTO: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let isDefault: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId, name, isDefault, createdAt
    }
}

struct TaskDTO: Codable, Identifiable {
    let id: String
    let listId: String
    let userId: String
    let content: String
    let completed: Bool
    let order: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case listId, userId, content, completed, order, createdAt, updatedAt
    }
}

struct SyncResponse: Codable {
    let folders: [FolderDTO]
    let notes: [NoteDTO]
    let taskLists: [TaskListDTO]
    let tasks: [TaskDTO]
}
