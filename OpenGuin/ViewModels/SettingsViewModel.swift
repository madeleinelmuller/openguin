import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    private let settings: SettingsManager

    var provider: LLMProvider {
        get { settings.provider }
        set {
            guard newValue != settings.provider else { return }
            settings.provider = newValue
            // Reset fetched models for new provider on switch
            switch newValue {
            case .ollama: fetchedOllamaModels = []
            case .lmStudio: fetchedLMStudioModels = []
            default: break
            }
            modelFetchError = nil
        }
    }

    var model: String {
        get { settings.activeModel(for: settings.provider) }
        set { settings.setActiveModel(newValue, for: settings.provider) }
    }

    var anthropicKey: String {
        get { settings.anthropicKey }
        set { settings.anthropicKey = newValue }
    }

    var openAIKey: String {
        get { settings.openAIKey }
        set { settings.openAIKey = newValue }
    }

    var ollamaEndpoint: String {
        get { settings.ollamaEndpoint }
        set { settings.ollamaEndpoint = newValue }
    }

    var lmStudioEndpoint: String {
        get { settings.lmStudioEndpoint }
        set { settings.lmStudioEndpoint = newValue }
    }

    var userName: String {
        get { settings.userName }
        set { settings.userName = newValue }
    }

    var maxTokens: Int {
        get { settings.maxTokens }
        set { settings.maxTokens = newValue }
    }

    // MARK: - Remote model fetching (Ollama / LM Studio)

    var fetchedOllamaModels: [String] = []
    var fetchedLMStudioModels: [String] = []
    var isFetchingModels = false
    var modelFetchError: String? = nil

    func fetchedModels(for p: LLMProvider) -> [String] {
        switch p {
        case .ollama:
            return fetchedOllamaModels.isEmpty ? [] : fetchedOllamaModels
        case .lmStudio:
            return fetchedLMStudioModels.isEmpty ? [] : fetchedLMStudioModels
        default:
            return p.availableModels
        }
    }

    func fetchModels() async {
        let p = provider
        guard p == .ollama || p == .lmStudio else { return }

        isFetchingModels = true
        modelFetchError = nil

        let rawEndpoint = p == .ollama ? settings.ollamaEndpoint : settings.lmStudioEndpoint
        let base = p.normalizedEndpoint(from: rawEndpoint)

        do {
            let models: [String]
            if p == .ollama {
                models = try await fetchOllamaModels(from: base)
                fetchedOllamaModels = models
                if let first = models.first, settings.ollamaModel.isEmpty || !models.contains(settings.ollamaModel) {
                    settings.ollamaModel = first
                }
            } else {
                models = try await fetchLMStudioModels(from: base)
                fetchedLMStudioModels = models
                if let first = models.first, settings.lmStudioModel.isEmpty || !models.contains(settings.lmStudioModel) {
                    settings.lmStudioModel = first
                }
            }
            if models.isEmpty {
                modelFetchError = "No models found. Is the server running?"
            }
        } catch {
            modelFetchError = "Connection failed: \(error.localizedDescription)"
            if p == .ollama { fetchedOllamaModels = [] }
            else { fetchedLMStudioModels = [] }
        }

        isFetchingModels = false
    }

    private func fetchOllamaModels(from base: String) async throws -> [String] {
        guard let url = URL(string: base + "/api/tags") else { throw URLError(.badURL) }
        let req = URLRequest(url: url, timeoutInterval: 8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["name"] as? String }
    }

    private func fetchLMStudioModels(from base: String) async throws -> [String] {
        guard let url = URL(string: base + "/v1/models") else { throw URLError(.badURL) }
        let req = URLRequest(url: url, timeoutInterval: 8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["data"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["id"] as? String }
    }

    init(settings: SettingsManager = .shared) {
        self.settings = settings
    }
}
