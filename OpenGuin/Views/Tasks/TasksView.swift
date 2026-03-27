import SwiftUI

struct TasksView: View {
    @State private var store = TaskStore.shared
    @State private var showAddSheet = false
    @State private var showCompleted = false

    var body: some View {
        NavigationStack {
            ZStack {
                RainbowBlobsBackground()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if store.pendingTasks.isEmpty && store.completedTasks.isEmpty {
                            emptyState
                        } else {
                            pendingSection
                            completedSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Tasks")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddTaskSheet(store: store)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No tasks yet")
                .font(.title3.weight(.semibold))
            Text("Tasks will appear here when openguin creates them from your conversations, or when you add them manually.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Pending

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.pendingTasks.isEmpty {
                Text("To Do")
                    .font(.headline)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                ForEach(store.pendingTasks) { task in
                    TaskRow(task: task, store: store)
                }
            }
        }
    }

    // MARK: - Completed

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.completedTasks.isEmpty {
                Button {
                    withAnimation(.smooth) { showCompleted.toggle() }
                } label: {
                    HStack {
                        Text("Completed")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(showCompleted ? 90 : 0))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 12)
                }
                .buttonStyle(.plain)

                if showCompleted {
                    ForEach(store.completedTasks) { task in
                        TaskRow(task: task, store: store)
                    }
                }
            }
        }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: TaskItem
    let store: TaskStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.smooth) {
                    if task.isCompleted {
                        store.uncompleteTask(id: task.id)
                    } else {
                        _ = store.completeTask(id: task.id)
                    }
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let note = task.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let due = task.dueDate {
                        Label(due.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(due < Date() && !task.isCompleted ? .red : .secondary)
                    }

                    sourceLabel
                }
            }

            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                store.deleteTask(id: task.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var sourceLabel: some View {
        Group {
            switch task.source {
            case .agent:
                Label("Agent", systemImage: "sparkles")
            case .transcript:
                Label("Recording", systemImage: "waveform")
            case .user:
                EmptyView()
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}

// MARK: - Add Task Sheet

private struct AddTaskSheet: View {
    let store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                TextField("Task", text: $title)
                TextField("Note (optional)", text: $note)

                Toggle("Due Date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("When", selection: $dueDate, in: Date()...)
                }
            }
            .navigationTitle("New Task")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        _ = store.addTask(
                            title: trimmed,
                            note: note.isEmpty ? nil : note,
                            dueDate: hasDueDate ? dueDate : nil,
                            source: .user
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TasksView()
}
