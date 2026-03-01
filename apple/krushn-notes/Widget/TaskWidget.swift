import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct TaskWidgetEntry: TimelineEntry {
    let date: Date
    let listName: String
    let tasks: [WidgetTask]
}

// MARK: - Provider

struct TaskWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskWidgetEntry {
        TaskWidgetEntry(
            date: .now,
            listName: "Tasks",
            tasks: [
                WidgetTask(id: "1", content: "Buy groceries", completed: false, order: 0),
                WidgetTask(id: "2", content: "Reply to emails", completed: true,  order: 1),
                WidgetTask(id: "3", content: "Write docs",     completed: false, order: 2),
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskWidgetEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskWidgetEntry>) -> Void) {
        let entry = entry(for: .now)
        // Refresh at most every 15 minutes (WidgetKit budget)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func entry(for date: Date) -> TaskWidgetEntry {
        guard let data = AppGroupStore.load() else {
            return TaskWidgetEntry(date: date, listName: "Tasks", tasks: [])
        }
        // Show up to 5 incomplete tasks first, then completed, total 5 max
        let incomplete = data.tasks.filter { !$0.completed }.prefix(5)
        let remaining  = max(0, 5 - incomplete.count)
        let completed  = data.tasks.filter { $0.completed }.prefix(remaining)
        let visible    = Array(incomplete) + Array(completed)

        return TaskWidgetEntry(date: date, listName: data.listName, tasks: visible)
    }
}

// MARK: - Widget Views

struct TaskWidgetEntryView: View {
    let entry: TaskWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium, .systemLarge:
            MediumWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: Small widget — just task count

struct SmallWidgetView: View {
    let entry: TaskWidgetEntry

    private var incompleteCount: Int {
        entry.tasks.filter { !$0.completed }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "checklist")
                .font(.title2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(incompleteCount)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("tasks left")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.listName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: Medium / Large — interactive task rows

struct MediumWidgetView: View {
    let entry: TaskWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .foregroundStyle(.secondary)
                Text(entry.listName)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 6)

            if entry.tasks.isEmpty {
                Spacer()
                Text("All done!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Task rows — interactive via Button + ToggleTaskIntent
                ForEach(entry.tasks) { task in
                    Button(intent: ToggleTaskIntent(taskId: task.id)) {
                        HStack(spacing: 8) {
                            Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.completed ? .green : .secondary)
                                .font(.system(size: 14))
                            Text(task.content)
                                .font(.caption)
                                .strikethrough(task.completed)
                                .foregroundStyle(task.completed ? .tertiary : .primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)

                    if task.id != entry.tasks.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configuration

struct TaskWidget: Widget {
    let kind = "TaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskWidgetProvider()) { entry in
            TaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tasks")
        .description("See and check off tasks from your default list.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct krushnNotesWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskWidget()
    }
}
