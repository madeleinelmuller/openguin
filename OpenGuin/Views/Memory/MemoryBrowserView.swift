import SwiftUI

struct MemoryBrowserView: View {
    @State private var memoryStructure: MemoryDirectory?
    @State private var selectedFile: MemoryFile?

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated rainbow blob glow from the bottom
                RainbowBlobsBackground()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let structure = memoryStructure {
                            ForEach(structure.files) { file in
                                MemoryFileRow(file: file) {
                                    selectedFile = file
                                }
                            }

                            ForEach(structure.subdirectories) { dir in
                                MemoryDirectorySection(directory: dir) { file in
                                    selectedFile = file
                                }
                            }
                        } else {
                            GlassEffectContainer {
                                VStack(spacing: 12) {
                                    ProgressView()
                                    Text("Loading memories...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(24)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await refreshMemory()
                }
            }
            .navigationTitle("Memory")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshMemory() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(item: $selectedFile) { file in
                MemoryFileView(file: file)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task {
                await refreshMemory()
            }
        }
    }

    private func refreshMemory() async {
        let structure = await MemoryManager.shared.getMemoryStructure()
        withAnimation(.smooth) {
            memoryStructure = structure
        }
    }
}

// MARK: - File Row

struct MemoryFileRow: View {
    let file: MemoryFile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: file.icon)
                    .font(.title3)
                    .foregroundStyle(file.color)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(file.color.opacity(0.3)), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.fileName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(file.content.prefix(80).replacingOccurrences(of: "\n", with: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(file.lastModified, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Directory Section

struct MemoryDirectorySection: View {
    let directory: MemoryDirectory
    let onSelectFile: (MemoryFile) -> Void
    @State private var isExpanded = true

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 8) {
                // Directory header
                Button {
                    withAnimation(.bouncy) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)

                        Text(directory.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("\(directory.files.count) files")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                if isExpanded {
                    ForEach(directory.files) { file in
                        MemoryFileRow(file: file) {
                            onSelectFile(file)
                        }
                        .padding(.leading, 16)
                    }

                    ForEach(directory.subdirectories) { subdir in
                        MemoryDirectorySection(directory: subdir, onSelectFile: onSelectFile)
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }
}

#Preview {
    MemoryBrowserView()
}
