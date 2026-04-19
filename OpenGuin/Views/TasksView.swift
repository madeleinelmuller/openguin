import SwiftUI

struct TasksView: View {
    @State private var selectedSegment = 0
    private let taskStore = TaskStore.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $selectedSegment) {
                    Text("Pending").tag(0)
                    Text("Completed").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(12)

                if selectedSegment == 0 {
                    pendingTasksList
                } else {
                    completedTasksList
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var pendingTasksList: some View {
        Group {
            if taskStore.pendingTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("All caught up!")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("No pending tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
            } else {
                List {
                    ForEach(taskStore.pendingTasks) { task in
                        taskRow(task)
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { taskStore.pendingTasks[$0].id }
                        ids.forEach { taskStore.deleteTask(id: $0) }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var completedTasksList: some View {
        Group {
            if taskStore.completedTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "inbox")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No completed tasks")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Tasks you complete will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
            } else {
                List {
                    ForEach(taskStore.completedTasks) { task in
                        taskRow(task)
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { taskStore.completedTasks[$0].id }
                        ids.forEach { taskStore.deleteTask(id: $0) }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                if task.isCompleted {
                    taskStore.uncompleteTask(id: task.id)
                } else {
                    _ = taskStore.completeTask(id: task.id)
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)

                if let note = task.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Label(task.source.rawValue, systemImage: sourceIcon(task.source))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }

    private func sourceIcon(_ source: TaskItem.TaskSource) -> String {
        switch source {
        case .agent:
            return "sparkles"
        case .transcript:
            return "waveform"
        case .user:
            return "person.fill"
        }
    }
}

#Preview {
    TasksView()
}
