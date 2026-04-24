import SwiftUI

struct ProviderSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Section("Provider") {
            Picker("Provider", selection: $vm.provider) {
                ForEach(LLMProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }

        if vm.provider.hasCustomEndpoint {
            Section {
                EndpointField(provider: vm.provider, endpoint: endpointBinding)
            } header: {
                Text("Server")
            } footer: {
                Text("Just enter host and port. The \u{2018}/v1\u{2019} path is added automatically.")
            }
        }

        Section("Model") {
            ModelPickerOrField(vm: vm)
        }

        if vm.provider.requiresAPIKey {
            Section {
                if vm.provider == .anthropic {
                    SecureField("sk-ant-…", text: $vm.anthropicKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else if vm.provider == .openAI {
                    SecureField("sk-…", text: $vm.openAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("API Key")
            } footer: {
                Text("Stored locally on your device. Only sent to the provider you choose.")
            }
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

// MARK: - Endpoint field with live normalization preview

struct EndpointField: View {
    let provider: LLMProvider
    @Binding var endpoint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Endpoint")
                    .foregroundStyle(.primary)
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
        switch vm.provider {
        case .anthropic, .openAI:
            Picker("Model", selection: $vm.model) {
                ForEach(vm.provider.availableModels, id: \.self) { m in
                    Text(m).tag(m)
                }
                // Accept stored models that aren't in the hardcoded list
                // (e.g. newer model names) so the picker can still select them.
                if !vm.provider.availableModels.contains(vm.model), !vm.model.isEmpty {
                    Text("\(vm.model) (custom)").tag(vm.model)
                }
            }
        case .ollama, .lmStudio:
            HStack {
                Text("Name")
                Spacer()
                TextField(vm.provider.defaultModel, text: $vm.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
