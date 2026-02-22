import SwiftUI

struct MemoryFileView: View {
    let file: MemoryFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedRainbowBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // File info header
                        GlassEffectContainer {
                            HStack(spacing: 12) {
                                Image(systemName: file.icon)
                                    .font(.title2)
                                    .foregroundStyle(file.color)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(.regular.tint(file.color.opacity(0.3)), in: RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.fileName)
                                        .font(.headline)

                                    Text("Modified \(file.lastModified, style: .relative)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text("Path: \(file.path)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                Spacer()
                            }
                            .padding(16)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                        }

                        // File content
                        GlassEffectContainer {
                            Text(LocalizedStringKey(file.content))
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(file.fileName)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MemoryFileView(file: MemoryFile(
        path: "about_me.md",
        content: "# About Me\n\nI am OpenGuin, a personal AI assistant.",
        lastModified: Date()
    ))
}
