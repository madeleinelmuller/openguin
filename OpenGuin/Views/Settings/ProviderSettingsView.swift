import SwiftUI

struct ProviderSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Section {
            Picker("Provider", selection: $vm.provider) {
                ForEach(LLMProvider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        } header: {
            Label("Provider", systemImage: "cpu")
        }

        if vm.provider.hasCustomEndpoint {
            Section {
                EndpointField(provider: vm.provider, endpoint: endpointBinding)
                fetchModelsRow
            } header: {
                Text("Server")
            } footer: {
                if let err = vm.modelFetchError {
                    Text(err).foregroundStyle(.red)
                } else {
                    Text("Enter your local server address, then tap Fetch Models.")
                }
            }
        }

        Section {
            ModelPickerOrField(vm: vm)
        } header: {
            Label("Model", systemImage: "sparkles")
        }

        if vm.provider.requiresAPIKey {
            Section {
                apiKeyField
            } header: {
                Label("API Key", systemImage: "key.fill")
            } footer: {
                Text("Stored locally. Only sent to the provider you choose.")
            }
        }
    }

    @ViewBuilder
    private var fetchModelsRow: some View {
        Button {
            Task { await vm.fetchModels() }
        } label: {
            HStack {
                Label("Fetch Models", systemImage: "arrow.clockwise")
                Spacer()
                if vm.isFetchingModels {
                    ProgressView().scaleEffect(0.8)
                }
            }
        }
        .disabled(vm.isFetchingModels)
    }

    @ViewBuilder
    private var apiKeyField: some View {
        if vm.provider == .anthropic {
            SecureField("sk-ant-…", text: $vm.anthropicKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } else if vm.provider == .openAI {
            SecureField("sk-…", text: $vm.openAIKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var endpointBinding: Binding<String> {
        switch vm.provider {
        case .ollama: return $vm.ollamaEndpoint
        case .lmStudio: return $vm.lmStudioEndpoint
        default: return .constant("")
        }
    }
}

// MARK: - Endpoint field

struct EndpointField: View {
    let provider: LLMProvider
    @Binding var endpoint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Endpoint")
                Spacer()
                TextField(provider.defaultEndpoint, text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .multilineTextAlignment(.trailing)
            }
            Text("→ \(fullURL)")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    private var fullURL: String {
        provider.normalizedEndpoint(from: endpoint) + provider.chatPath
    }
}

// MARK: - Model picker / free-text

struct ModelPickerOrField: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        let p = vm.provider
        let fetched = vm.fetchedModels(for: p)

        switch p {
        case .anthropic, .openAI:
            Picker("Model", selection: $vm.model) {
                ForEach(p.availableModels, id: \.self) { m in
                    Text(m).tag(m)
                }
                if !p.availableModels.contains(vm.model), !vm.model.isEmpty {
                    Text("\(vm.model) (custom)").tag(vm.model)
                }
            }

        case .ollama, .lmStudio:
            if fetched.isEmpty {
                HStack {
                    Text("Model")
                    Spacer()
                    TextField(p.defaultModel, text: $vm.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker("Model", selection: $vm.model) {
                    ForEach(fetched, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
            }
        }
    }
}
