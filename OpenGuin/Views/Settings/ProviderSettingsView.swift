import SwiftUI

struct ProviderSettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        Section("AI Provider") {
            Picker("Provider", selection: $vm.provider) {
                ForEach(LLMProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }

        Section("Model") {
            if vm.provider == .ollama {
                LabeledContent("Endpoint") {
                    TextField("http://localhost:11434", text: $vm.ollamaEndpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                TextField("Model name", text: $vm.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else if vm.provider == .lmStudio {
                LabeledContent("Endpoint") {
                    TextField("http://localhost:1234", text: $vm.lmStudioEndpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
            } else {
                Picker("Model", selection: $vm.model) {
                    ForEach(vm.provider.availableModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
            }
        }

        if vm.provider.requiresAPIKey {
            Section("API Key") {
                if vm.provider == .anthropic {
                    SecureField("Anthropic API Key", text: $vm.anthropicKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else if vm.provider == .openAI {
                    SecureField("OpenAI API Key", text: $vm.openAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
    }
}
