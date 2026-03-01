import Foundation
import WidgetKit

// MARK: - Shared data written by SyncManager into the App Group container

/// Lightweight task model stored in App Group JSON for the widget.
/// Mirrors only what the widget needs.
struct WidgetTask: Codable, Identifiable {
    let id: String
    let content: String
    var completed: Bool
    let order: Int
}

struct WidgetTaskData: Codable {
    let listName: String
    let tasks: [WidgetTask]
    let updatedAt: Date
}

// MARK: - App Group helpers

enum AppGroupStore {
    static let groupId = "group.com.krushn.notes"
    static let tasksKey = "widget_tasks"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
    }

    // Written by SyncManager after every sync
    static func save(_ data: WidgetTaskData) {
        guard let url = containerURL?.appendingPathComponent("widget_tasks.json") else { return }
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: url, options: .atomic)
    }

    static func load() -> WidgetTaskData? {
        guard let url = containerURL?.appendingPathComponent("widget_tasks.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetTaskData.self, from: data)
    }
}
