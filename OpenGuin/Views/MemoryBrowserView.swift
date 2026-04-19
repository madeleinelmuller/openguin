import SwiftUI

extension MemoryFile: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    public static func == (lhs: MemoryFile, rhs: MemoryFile) -> Bool {
        lhs.path == rhs.path
    }
}

struct MemoryBrowserView: View {
    @State private var memoryFiles: [MemoryFile] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if memoryFiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No memory files yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Your AI assistant's memory will appear here after your first conversation")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(memoryFiles) { file in
                            NavigationLink(value: file) {
                                HStack(spacing: 12) {
                                    Image(systemName: file.icon)
                                        .foregroundColor(file.color)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(file.fileName)
                                            .font(.headline)
                                        Text(file.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(file.lastModified.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                HStack {
                    Button(action: { loadMemoryFiles() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    Spacer()
                    Text("\(memoryFiles.count) file\(memoryFiles.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(uiColor: .systemGray6))
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MemoryFile.self) { file in
                MemoryFileDetailView(file: file)
            }
        }
        .onAppear {
            loadMemoryFiles()
        }
    }

    private func loadMemoryFiles() {
        isLoading = true
        Task {
            let files = await MemoryManager.shared.getAllMemoryFiles()
            memoryFiles = files
            isLoading = false
        }
    }
}

private struct MemoryFileDetailView: View {
    let file: MemoryFile

    var body: some View {
        ScrollView {
            Text(file.content.isEmpty ? "(empty)" : file.content)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(16)
        }
        .navigationTitle(file.fileName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MemoryBrowserView()
}
