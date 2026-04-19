import SwiftUI

struct MemoryBrowserView: View {
    @State var vm: MemoryViewModel
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                } else if vm.files.isEmpty {
                    ContentUnavailableView(
                        "No memory files",
                        systemImage: "brain.head.profile",
                        description: Text("Openguin will create memory files when you start chatting.")
                    )
                } else {
                    List {
                        ForEach(vm.files) { file in
                            fileRow(file: file)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Memory")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await vm.refresh() }
            .task { await vm.refresh() }
        }
    }

    @ViewBuilder
    private func fileRow(file: MemoryFile) -> some View {
        if file.isDirectory {
            Section(header: Label(file.name, systemImage: "folder.fill").textCase(nil)) {
                ForEach(file.children) { child in
                    if !child.isDirectory {
                        navigationLink(for: child)
                    }
                }
            }
        } else {
            navigationLink(for: file)
        }
    }

    private func navigationLink(for file: MemoryFile) -> some View {
        NavigationLink {
            MemoryFileDetailView(vm: vm)
                .task { await vm.loadContent(for: file) }
        } label: {
            HStack {
                Image(systemName: iconName(for: file.name))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.subheadline.weight(.medium))
                    Text(file.modifiedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await vm.delete(file: file) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func iconName(for filename: String) -> String {
        switch filename.lowercased() {
        case "soul.md": return "sparkles"
        case "user.md": return "person.fill"
        case "memory.md": return "brain.head.profile"
        default:
            if filename.hasSuffix(".md") { return "doc.text.fill" }
            if filename.hasSuffix(".json") { return "curlybraces" }
            return "doc.fill"
        }
    }
}

#Preview {
    MemoryBrowserView(vm: MemoryViewModel())
        .environment(AppEnvironment.shared)
}
