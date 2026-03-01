import SwiftUI
import SwiftData

/// Column 2 on macOS for the Tasks section.
/// Shows tasks inline — no separate detail column needed.
struct MacTaskListView: View {
    let listId: String

    @Query private var allTasks: [TaskItem]
    @Query private var allLists: [TaskList]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthManager

    @State private var newTaskContent = ""
    @FocusState private var inputFocused: Bool

    private var list: TaskList? { allLists.first { $0.id == listId } }

    private var tasks: [TaskItem] {
        allTasks
            .filter { $0.listId == listId }
            .sorted { $0.order < $1.order }
    }

    private var incompleteTasks: [TaskItem] { tasks.filter { !$0.completed } }
    private var completedTasks:  [TaskItem] { tasks.filter { $0.completed } }

    var body: some View {
        List {
            // Add task row
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.secondary)
                TextField("Add a task…", text: $newTaskContent)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit { Task { await addTask() } }
            }
            .padding(.vertical, 2)

            // Incomplete
            ForEach(incompleteTasks) { task in
                MacTaskRow(task: task, onToggle: { Task { await toggleTask(task) } })
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { await deleteTask(task) }
                        }
                    }
            }
            .onMove { indices, dest in
                Task { await reorderTasks(from: indices, to: dest, in: incompleteTasks) }
            }

            // Completed
            if !completedTasks.isEmpty {
                Section("Completed") {
                    ForEach(completedTasks) { task in
                        MacTaskRow(task: task, onToggle: { Task { await toggleTask(task) } })
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    Task { await deleteTask(task) }
                                }
                            }
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 340)
        .navigationTitle(list?.name ?? "Tasks")
        .animation(.default, value: tasks.map(\.id))
    }

    // MARK: - Actions

    private func addTask() async {
        let content = newTaskContent.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        newTaskContent = ""
        let order = (tasks.map(\.order).max() ?? -1) + 1

        do {
            let dto = try await APIClient.shared.createTask(listId: listId, content: content, order: order)
            modelContext.insert(TaskItem(
                id: dto.id, listId: dto.listId, userId: dto.userId,
                content: dto.content, completed: false, order: dto.order,
                createdAt: dto.createdAt, updatedAt: dto.updatedAt, pendingSync: false
            ))
            try modelContext.save()
        } catch {
            let tempId = UUID().uuidString
            modelContext.insert(TaskItem(id: tempId, listId: listId, userId: auth.userId, content: content, order: order, pendingSync: true))
            struct Body: Encodable { let content: String; let order: Int }
            let body = try? JSONEncoder().encode(Body(content: content, order: order))
            modelContext.insert(SyncOperation(method: "POST", path: "/api/lists/\(listId)/tasks", body: body))
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
        do { try await APIClient.shared.deleteTask(id: id) }
        catch { modelContext.insert(SyncOperation(method: "DELETE", path: "/api/tasks/\(id)")) }
        try? modelContext.save()
    }

    private func reorderTasks(from source: IndexSet, to destination: Int, in taskList: [TaskItem]) async {
        var reordered = taskList
        reordered.move(fromOffsets: source, toOffset: destination)
        for (i, task) in reordered.enumerated() {
            task.order = i
            task.pendingSync = true
        }
        try? modelContext.save()
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

// MARK: - MacTaskRow

struct MacTaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    @State private var isEditing = false
    @State private var editContent = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("", text: $editContent, onCommit: {
                    Task { await saveEdit() }
                })
                .textFieldStyle(.plain)
                .onAppear { editContent = task.content }
            } else {
                Text(task.content)
                    .strikethrough(task.completed)
                    .foregroundStyle(task.completed ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) { isEditing = true }
            }

            if task.pendingSync {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 1)
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
