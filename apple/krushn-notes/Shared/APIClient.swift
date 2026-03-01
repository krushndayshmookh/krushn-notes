import Foundation

// MARK: - API Errors

enum APIError: LocalizedError {
    case unauthorized
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    case noToken

    var errorDescription: String? {
        switch self {
        case .unauthorized:          return "Session expired. Please log in again."
        case .serverError(let c, let m): return "Server error \(c): \(m)"
        case .decodingError(let e):  return "Decode error: \(e.localizedDescription)"
        case .networkError(let e):   return e.localizedDescription
        case .noToken:               return "Not authenticated."
        }
    }
}

// MARK: - APIClient

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()

    // Injected at startup from Config.xcconfig / Info.plist
    let baseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
            ?? "http://localhost:3000"
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    private var iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    // MARK: - Core request

    func request<T: Decodable>(
        method: String = "GET",
        path: String,
        body: Encodable? = nil
    ) async throws -> T {
        guard let token = Keychain.loadToken() else { throw APIError.noToken }
        guard let url = URL(string: baseURL + path) else {
            throw APIError.networkError(URLError(.badURL))
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(http.statusCode, msg)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // Convenience for DELETE / void responses
    func requestVoid(method: String = "DELETE", path: String, body: Encodable? = nil) async throws {
        guard let token = Keychain.loadToken() else { throw APIError.noToken }
        guard let url = URL(string: baseURL + path) else {
            throw APIError.networkError(URLError(.badURL))
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (_, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode, "Request failed")
        }
    }

    // MARK: - Pusher auth endpoint

    func pusherAuth(socketId: String, channel: String) async throws -> [String: String] {
        struct PusherAuthBody: Encodable {
            let socket_id: String
            let channel_name: String
        }
        return try await request(
            method: "POST",
            path: "/auth/pusher",
            body: PusherAuthBody(socket_id: socketId, channel_name: channel)
        )
    }

    // MARK: - Folders

    func getFolders() async throws -> [FolderDTO] {
        try await request(path: "/api/folders")
    }

    func createFolder(name: String) async throws -> FolderDTO {
        struct Body: Encodable { let name: String }
        return try await request(method: "POST", path: "/api/folders", body: Body(name: name))
    }

    func updateFolder(id: String, name: String) async throws -> FolderDTO {
        struct Body: Encodable { let name: String }
        return try await request(method: "PUT", path: "/api/folders/\(id)", body: Body(name: name))
    }

    func deleteFolder(id: String) async throws {
        try await requestVoid(method: "DELETE", path: "/api/folders/\(id)")
    }

    // MARK: - Notes

    func getNotes(folderId: String? = nil, tag: String? = nil) async throws -> [NoteDTO] {
        var path = "/api/notes"
        if let folderId {
            path += "?folderId=\(folderId)"
        } else if let tag {
            path += "?tag=\(tag)"
        }
        return try await request(path: path)
    }

    func getNote(id: String) async throws -> NoteDTO {
        try await request(path: "/api/notes/\(id)")
    }

    func createNote(title: String, content: String, folderId: String?) async throws -> NoteDTO {
        struct Body: Encodable { let title: String; let content: String; let folderId: String? }
        return try await request(method: "POST", path: "/api/notes", body: Body(title: title, content: content, folderId: folderId))
    }

    func updateNote(id: String, title: String, content: String, folderId: String?) async throws -> NoteDTO {
        struct Body: Encodable { let title: String; let content: String; let folderId: String? }
        return try await request(method: "PUT", path: "/api/notes/\(id)", body: Body(title: title, content: content, folderId: folderId))
    }

    func deleteNote(id: String) async throws {
        try await requestVoid(method: "DELETE", path: "/api/notes/\(id)")
    }

    func getTags() async throws -> [String] {
        try await request(path: "/api/tags")
    }

    // MARK: - Task Lists

    func getLists() async throws -> [TaskListDTO] {
        try await request(path: "/api/lists")
    }

    func createList(name: String) async throws -> TaskListDTO {
        struct Body: Encodable { let name: String }
        return try await request(method: "POST", path: "/api/lists", body: Body(name: name))
    }

    func updateList(id: String, name: String) async throws -> TaskListDTO {
        struct Body: Encodable { let name: String }
        return try await request(method: "PUT", path: "/api/lists/\(id)", body: Body(name: name))
    }

    func deleteList(id: String) async throws {
        try await requestVoid(method: "DELETE", path: "/api/lists/\(id)")
    }

    // MARK: - Tasks

    func getTasks(listId: String) async throws -> [TaskDTO] {
        try await request(path: "/api/lists/\(listId)/tasks")
    }

    func createTask(listId: String, content: String, order: Int) async throws -> TaskDTO {
        struct Body: Encodable { let content: String; let order: Int }
        return try await request(method: "POST", path: "/api/lists/\(listId)/tasks", body: Body(content: content, order: order))
    }

    func updateTask(id: String, content: String? = nil, completed: Bool? = nil, order: Int? = nil) async throws -> TaskDTO {
        struct Body: Encodable { let content: String?; let completed: Bool?; let order: Int? }
        return try await request(method: "PUT", path: "/api/tasks/\(id)", body: Body(content: content, completed: completed, order: order))
    }

    func deleteTask(id: String) async throws {
        try await requestVoid(method: "DELETE", path: "/api/tasks/\(id)")
    }

    // MARK: - Sync

    func sync(since: Date?) async throws -> SyncResponse {
        var path = "/api/sync"
        if let since {
            let ts = since.ISO8601Format()
            path += "?since=\(ts.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ts)"
        }
        return try await request(path: path)
    }
}
