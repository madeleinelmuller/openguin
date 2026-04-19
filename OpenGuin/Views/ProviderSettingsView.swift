import SwiftUI

struct ProviderSettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("LLM Provider") {
                    Picker("Provider", selection: $viewModel.selectedProvider) {
                        ForEach([LLMProvider.anthropic, LLMProvider.openai, LLMProvider.lmstudio], id: \.self) { provider in
                            Text(provider.rawValue.capitalized).tag(provider)
                        }
                    }
                    .onChange(of: viewModel.selectedProvider) {
                        viewModel.loadCurrentSettings()
                    }
                }

                if viewModel.selectedProvider == .anthropic {
                    anthropicSection
                } else if viewModel.selectedProvider == .openai {
                    openaiSection
                } else if viewModel.selectedProvider == .lmstudio {
                    lmstudioSection
                }

                Section("Preferences") {
                    Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedbackEnabled)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadCurrentSettings()
            }
            .alert("API Key Saved", isPresented: $viewModel.showAPIKeySaved) {
                Button("OK") { }
            }
        }
    }

    @ViewBuilder
    private var anthropicSection: some View {
        Section("Anthropic") {
            Picker("Model", selection: $viewModel.selectedAnthropicModel) {
                ForEach([
                    AnthropicModel.opus46,
                    AnthropicModel.sonnet46,
                    AnthropicModel.haiku45,
                ], id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            }

            SecureField("API Key", text: $viewModel.anthropicKeyInput)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack {
                Button("Masked: \(viewModel.currentMaskedAPIKey)") {
                    viewModel.loadCurrentSettings()
                }
                .foregroundColor(.secondary)
                .font(.caption)
                .disabled(true)

                Spacer()

                Button(role: .destructive) {
                    viewModel.clearCurrentProvider()
                } label: {
                    Text("Clear")
                }
            }

            HStack {
                Button(action: { viewModel.saveCurrentProvider() }) {
                    Text("Save API Key")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var openaiSection: some View {
        Section("OpenAI") {
            Picker("Model", selection: $viewModel.selectedOpenAIModel) {
                ForEach([
                    OpenAIModel.gpt4o,
                    OpenAIModel.gpt4turbo,
                    OpenAIModel.gpt4,
                ], id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            }

            SecureField("API Key", text: $viewModel.openaiKeyInput)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack {
                Button("Masked: \(viewModel.currentMaskedAPIKey)") {
                    viewModel.loadCurrentSettings()
                }
                .foregroundColor(.secondary)
                .font(.caption)
                .disabled(true)

                Spacer()

                Button(role: .destructive) {
                    viewModel.clearCurrentProvider()
                } label: {
                    Text("Clear")
                }
            }

            HStack {
                Button(action: { viewModel.saveCurrentProvider() }) {
                    Text("Save API Key")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var lmstudioSection: some View {
        Section("LM Studio") {
            TextField("Host (e.g., 192.168.1.100:1234)", text: $viewModel.customEndpointInput)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("Model Name", text: $viewModel.customModelNameInput)
                .autocorrectionDisabled()

            HStack {
                Button(action: { viewModel.saveCurrentProvider() }) {
                    Text("Save Configuration")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    viewModel.clearCurrentProvider()
                } label: {
                    Text("Clear")
                }
            }
        }

        Section("About LM Studio") {
            Text("Make sure LM Studio is running on your network and the model is loaded before using it with OpenGuin.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ProviderSettingsView()
}
