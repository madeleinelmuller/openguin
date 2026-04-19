import SwiftUI

struct OnboardingProviderView: View {
    @Bindable var vm: SettingsViewModel
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: appeared)

                Text("Connect your AI")
                    .font(.title.bold())
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.2), value: appeared)

                Text("Choose a provider and add your API key, or use a local model with Ollama.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.3), value: appeared)
            }
            .padding(.bottom, 32)

            // Provider settings in a glass card
            GlassCard(cornerRadius: 24, padding: 20) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Provider picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Provider")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Picker("Provider", selection: $vm.provider) {
                                ForEach(LLMProvider.allCases) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        // Model / endpoint fields
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Model")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            if vm.provider == .ollama {
                                HStack {
                                    Text("Endpoint")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    TextField("http://localhost:11434", text: $vm.ollamaEndpoint)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(.secondary)
                                }
                                Divider()
                                HStack {
                                    Text("Model name")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    TextField("Model name", text: $vm.model)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(.secondary)
                                }
                            } else if vm.provider == .lmStudio {
                                HStack {
                                    Text("Endpoint")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    TextField("http://localhost:1234", text: $vm.lmStudioEndpoint)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(.secondary)
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
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Key")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
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
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4), value: appeared)

            Spacer()

            VStack(spacing: 12) {
                HapticButton(.medium, action: onNext) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                Button("I'll set this up later") {
                    onNext()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut.delay(0.55), value: appeared)
        }
        .onAppear { appeared = true }
    }
}
