import Foundation
import Observation

@Observable
@MainActor
final class MemoryViewModel {
    private(set) var files: [MemoryFile] = []
    var isLoading = false
    var selectedFile: MemoryFile? = nil
    var fileContent: String = ""
    var isEditing = false

    func refresh() async {
        isLoading = true
        files = await MemoryManager.shared.allFiles()
        isLoading = false
    }

    func loadContent(for file: MemoryFile) async {
        selectedFile = file
        fileContent = await MemoryManager.shared.readFile(path: file.path)
    }

    func saveContent() async {
        guard let file = selectedFile else { return }
        _ = await MemoryManager.shared.writeFile(path: file.path, content: fileContent)
        await refresh()
        isEditing = false
    }

    func delete(file: MemoryFile) async {
        _ = await MemoryManager.shared.deleteFile(path: file.path)
        if selectedFile?.id == file.id {
            selectedFile = nil
            fileContent = ""
        }
        await refresh()
    }
}
