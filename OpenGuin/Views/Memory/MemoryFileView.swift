import SwiftUI

struct MemoryFileView: View {
    let file: MemoryFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.teal.opacity(0.1),
                        Color.green.opacity(0.06),
                        Color.cyan.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // File info header
                        GlassEffectContainer {
                            HStack(spacing: 12) {
                                Image(systemName: iconForFile)
                                    .font(.title2)
                                    .foregroundStyle(colorForFile)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(.regular.tint(colorForFile.opacity(0.3)), in: RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.fileName)
                                        .font(.headline)

                                    Text("Last modified: \(file.lastModified, style: .relative) ago")
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
                            VStack(alignment: .leading) {
                                Text(LocalizedStringKey(file.content))
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
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

    private var iconForFile: String {
        if file.fileName == "about_me.md" { return "person.text.rectangle" }
        if file.fileName == "about_user.md" { return "person.crop.circle" }
        if file.fileName.hasSuffix(".md") { return "doc.text" }
        return "doc"
    }

    private var colorForFile: Color {
        if file.fileName == "about_me.md" { return .blue }
        if file.fileName == "about_user.md" { return .green }
        return .orange
    }
}

#Preview {
    MemoryFileView(file: MemoryFile(
        path: "about_me.md",
        content: "# About Me\n\nI am OpenGuin, a personal AI assistant.",
        lastModified: Date()
    ))
}
