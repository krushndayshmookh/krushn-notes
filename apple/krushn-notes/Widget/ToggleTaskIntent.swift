import AppIntents
import WidgetKit

// MARK: - ToggleTaskIntent (iOS 17+ interactive widget)

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    static var description = IntentDescription("Mark a task complete or incomplete.")

    // The task ID to toggle
    @Parameter(title: "Task ID")
    var taskId: String

    init() {}
    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        // 1. Load current data from App Group
        guard var data = AppGroupStore.load() else {
            return .result()
        }

        // 2. Toggle locally
        guard let idx = data.tasks.firstIndex(where: { $0.id == taskId }) else {
            return .result()
        }
        data.tasks[idx].completed.toggle()
        let newCompleted = data.tasks[idx].completed
        AppGroupStore.save(data)

        // 3. Call API (best-effort — widget has network access)
        if let token = Keychain.loadToken() {
            let baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? ""
            guard let url = URL(string: "\(baseURL)/api/tasks/\(taskId)") else { return .result() }
            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONEncoder().encode(["completed": newCompleted])
            _ = try? await URLSession.shared.data(for: req)
        }

        // 4. Invalidate widget timeline so it re-renders
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
