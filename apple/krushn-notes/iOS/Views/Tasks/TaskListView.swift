import SwiftUI
import SwiftData

struct TaskListView: View {
    let list: TaskList

    @Query private var allTasks: [TaskItem]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthManager

    @State private var newTaskContent = ""
    @FocusState private var isInputFocused: Bool

    private var tasks: [TaskItem] {
        allTasks
            .filter { $0.listId == list.id }
            .sorted { $0.order < $1.order }
    }

    private var incompleteTasks: [TaskItem] { tasks.filter { !$0.completed } }
    private var completedTasks: [TaskItem]  { tasks.filter { $0.completed } }

    var body: some View {
        List {
            // Add task input
            Section {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                    TextField("Add a task…", text: $newTaskContent)
                        .focused($isInputFocused)
                        .onSubmit { Task { await addTask() } }
                }
            }

            // Incomplete tasks
            if !incompleteTasks.isEmpty {
                Section {
                    ForEach(incompleteTasks) { task in
                        TaskRow(task: task, onToggle: { Task { await toggleTask(task) } })
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deleteTask(task) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { indices, destination in
                        Task { await reorderTasks(from: indices, to: destination, in: incompleteTasks) }
                    }
                }
            }

            // Completed tasks
            if !completedTasks.isEmpty {
                Section("Completed") {
                    ForEach(completedTasks) { task in
                        TaskRow(task: task, onToggle: { Task { await toggleTask(task) } })
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await deleteTask(task) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            EditButton()
        }
        .animation(.default, value: tasks.map(\.id))
    }

    // MARK: - Actions

    private func addTask() async {
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

    private func deleteTask(_ task: TaskItem) async {
        let id = task.id
        modelContext.delete(task)
        try? modelContext.save()

        do {
            try await APIClient.shared.deleteTask(id: id)
        } catch {
            modelContext.insert(SyncOperation(method: "DELETE", path: "/api/tasks/\(id)"))
            try? modelContext.save()
        }
    }

    private func reorderTasks(from source: IndexSet, to destination: Int, in taskList: [TaskItem]) async {
        var reordered = taskList
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reordered.enumerated() {
            task.order = index
            task.pendingSync = true
        }
        try? modelContext.save()

        // Sync new orders
        for task in reordered {
            do {
                let dto = try await APIClient.shared.updateTask(id: task.id, order: task.order)
                task.updatedAt = dto.updatedAt
                task.pendingSync = false
            } catch {
                struct Body: Encodable { let order: Int }
                let body = try? JSONEncoder().encode(Body(order: task.order))
                modelContext.insert(SyncOperation(method: "PUT", path: "/api/tasks/\(task.id)", body: body))
            }
        }
        try? modelContext.save()
    }
}

// MARK: - TaskRow

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    @State private var isEditing = false
    @State private var editContent = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.completed ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("Task", text: $editContent, onCommit: {
                    Task { await saveEdit() }
                })
                .onAppear { editContent = task.content }
            } else {
                Text(task.content)
                    .strikethrough(task.completed)
                    .foregroundStyle(task.completed ? .secondary : .primary)
                    .onTapGesture(count: 2) {
                        isEditing = true
                    }
            }

            Spacer()

            if task.pendingSync {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveEdit() async {
        let content = editContent.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { isEditing = false; return }

        task.content = content
        task.updatedAt = .now
        task.pendingSync = true
        try? modelContext.save()
        isEditing = false

        do {
            let dto = try await APIClient.shared.updateTask(id: task.id, content: content)
            task.updatedAt = dto.updatedAt
            task.pendingSync = false
            try? modelContext.save()
        } catch {
            struct Body: Encodable { let content: String }
            let body = try? JSONEncoder().encode(Body(content: content))
            modelContext.insert(SyncOperation(method: "PUT", path: "/api/tasks/\(task.id)", body: body))
            try? modelContext.save()
        }
    }
}
