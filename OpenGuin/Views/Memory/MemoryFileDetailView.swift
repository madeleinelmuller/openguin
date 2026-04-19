import SwiftUI

struct MemoryFileDetailView: View {
    @Bindable var vm: MemoryViewModel

    var body: some View {
        Group {
            if let file = vm.selectedFile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if vm.isEditing {
                            TextEditor(text: $vm.fileContent)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 300)
                                .padding()
                        } else {
                            Text(vm.fileContent)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .textSelection(.enabled)
                        }
                    }
                }
                .navigationTitle(file.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if vm.isEditing {
                            Button("Save") {
                                Task { await vm.saveContent() }
                            }
                            .fontWeight(.semibold)
                        } else {
                            Button("Edit") {
                                vm.isEditing = true
                            }
                        }
                    }
                    if vm.isEditing {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") {
                                vm.isEditing = false
                                Task { await vm.loadContent(for: file) }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a file",
                    systemImage: "doc.text",
                    description: Text("Choose a memory file from the list.")
                )
            }
        }
    }
}
