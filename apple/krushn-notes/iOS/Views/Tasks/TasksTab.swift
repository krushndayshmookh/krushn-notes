import SwiftUI
import SwiftData

struct TasksTab: View {
    @Query(sort: \TaskList.createdAt) private var lists: [TaskList]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthManager

    @State private var selectedListId: String?
    @State private var showNewListAlert = false
    @State private var newListName = ""

    var body: some View {
        NavigationSplitView {
            Group {
                if lists.isEmpty {
                    ContentUnavailableView {
                        Label("No Lists", systemImage: "checklist")
                    } description: {
                        Text("Tap + to create a task list.")
                    }
                } else {
                    List(lists, selection: $selectedListId) { list in
                        HStack {
                            Label(list.name, systemImage: list.isDefault ? "star.fill" : "list.bullet")
                            Spacer()
                        }
                        .tag(list.id)
                        .swipeActions(edge: .trailing) {
                            if !list.isDefault {
                                Button(role: .destructive) {
                                    Task { await deleteList(list) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewListAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New List", isPresented: $showNewListAlert) {
                TextField("List name", text: $newListName)
                Button("Create") {
                    Task { await createList() }
                }
                Button("Cancel", role: .cancel) {
                    newListName = ""
                }
            }
            .onAppear {
                if selectedListId == nil {
                    selectedListId = lists.first(where: \.isDefault)?.id ?? lists.first?.id
                }
            }
            .onChange(of: lists) { _, newLists in
                if selectedListId == nil {
                    selectedListId = newLists.first(where: \.isDefault)?.id ?? newLists.first?.id
                }
            }
        } detail: {
            if let listId = selectedListId,
               let list = lists.first(where: { $0.id == listId }) {
                TaskListView(list: list)
            } else {
                ContentUnavailableView("Select a list", systemImage: "checklist")
            }
        }
    }

    private func createList() async {
        let name = newListName.trimmingCharacters(in: .whitespaces)
        newListName = ""
        guard !name.isEmpty else { return }

        do {
            let dto = try await APIClient.shared.createList(name: name)
            modelContext.insert(TaskList(id: dto.id, userId: dto.userId, name: dto.name, isDefault: dto.isDefault, createdAt: dto.createdAt))
            try modelContext.save()
        } catch {
            let tempId = UUID().uuidString
            modelContext.insert(TaskList(id: tempId, userId: auth.userId, name: name))
            let body = try? JSONEncoder().encode(["name": name])
            modelContext.insert(SyncOperation(method: "POST", path: "/api/lists", body: body))
            try? modelContext.save()
        }
    }

    private func deleteList(_ list: TaskList) async {
        let id = list.id
        modelContext.delete(list)
        if selectedListId == id { selectedListId = lists.first?.id }
        try? modelContext.save()

        do {
            try await APIClient.shared.deleteList(id: id)
        } catch {
            modelContext.insert(SyncOperation(method: "DELETE", path: "/api/lists/\(id)"))
            try? modelContext.save()
        }
    }
}
