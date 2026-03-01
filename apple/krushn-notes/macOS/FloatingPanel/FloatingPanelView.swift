import SwiftUI
import SwiftData

/// SwiftUI content shown inside the floating NSPanel.
/// Displays the default task list for quick add + check-off.
struct FloatingPanelView: View {
    @Query(sort: \TaskList.createdAt) private var lists: [TaskList]
    @Query private var allTasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthManager

    @State private var newTaskContent = ""
    @FocusState private var inputFocused: Bool

    private var defaultList: TaskList? {
        lists.first(where: \.isDefault) ?? lists.first
    }

    private var tasks: [TaskItem] {
        guard let list = defaultList else { return [] }
        return allTasks
            .filter { $0.listId == list.id }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(defaultList?.name ?? "Tasks")
                    .font(.headline)
                Spacer()
                Button {
                    FloatingPanelController.shared.hide()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close panel  ⌘⌥T")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Task list
            if tasks.isEmpty && defaultList == nil {
                Spacer()
                Text("No task list found.\nCreate one in the main app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(tasks) { task in
                            PanelTaskRow(task: task, onToggle: {
                                Task { await toggleTask(task) }
                            })
                            Divider().padding(.leading, 36)
                        }
                    }
                }
            }

            Divider()

            // Add task input
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                TextField("Add a task…", text: $newTaskContent)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit { Task { await addTask() } }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func addTask() async {
        guard let list = defaultList else { return }
        let content = newTaskContent.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        newTaskContent = ""
        let order = (tasks.map(\.order).max() ?? -1) + 1

        do {
            let dto = try await APIClient.shared.createTask(listId: list.id, content: content, order: order)
            modelContext.insert(TaskItem(
                id: dto.id, listId: dto.listId, userId: dto.userId,
                content: dto.content, completed: false, order: dto.order,
                createdAt: dto.createdAt, updatedAt: dto.updatedAt, pendingSync: false
            ))
            try modelContext.save()
        } catch {
            let tempId = UUID().uuidString
            modelContext.insert(TaskItem(id: tempId, listId: list.id, userId: auth.userId, content: content, order: order, pendingSync: true))
            struct Body: Encodable { let content: String; let order: Int }
            let body = try? JSONEncoder().encode(Body(content: content, order: order))
            modelContext.insert(SyncOperation(method: "POST", path: "/api/lists/\(list.id)/tasks", body: body))
            try? modelContext.save()
        }
    }

    private func toggleTask(_ task: TaskItem) async {
        task.completed.toggle()
        task.updatedAt = .now
        task.pendingSync = true
        try? modelContext.save()

        do {
            let dto = try await APIClient.shared.updateTask(id: task.id, completed: task.completed)
            task.updatedAt = dto.updatedAt
            task.pendingSync = false
            try? modelContext.save()
        } catch {
            struct Body: Encodable { let completed: Bool }
            let body = try? JSONEncoder().encode(Body(completed: task.completed))
            modelContext.insert(SyncOperation(method: "PUT", path: "/api/tasks/\(task.id)", body: body))
            try? modelContext.save()
        }
    }
}

// MARK: - PanelTaskRow

struct PanelTaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.completed ? .green : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            Text(task.content)
                .strikethrough(task.completed)
                .foregroundStyle(task.completed ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
