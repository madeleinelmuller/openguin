import SwiftUI

struct OnboardingProviderView: View {
    @Bindable var vm: SettingsViewModel
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 10) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: appeared)

                Text("Connect your AI")
                    .font(.title.bold())
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.2), value: appeared)

                Text("Pick a provider and add your API key,\nor connect to a local model.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.3), value: appeared)
            }
            .padding(.bottom, 28)

            // Card
            GlassCard(cornerRadius: 24, padding: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    // Provider picker
                    sectionLabel("Provider")
                        .padding(.bottom, 8)
                    Picker("Provider", selection: $vm.provider) {
                        ForEach(LLMProvider.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    Divider().padding(.vertical, 16)

                    // Endpoint (local providers)
                    if vm.provider.hasCustomEndpoint {
                        sectionLabel("Server")
                            .padding(.bottom, 8)
                        EndpointField(provider: vm.provider, endpoint: endpointBinding)

                        fetchModelsButton
                            .padding(.top, 10)

                        if let err = vm.modelFetchError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.top, 4)
                        }

                        Divider().padding(.vertical, 16)
                    }

                    // Model
                    sectionLabel("Model")
                        .padding(.bottom, 8)
                    ModelPickerOrField(vm: vm)

                    // API key
                    if vm.provider.requiresAPIKey {
                        Divider().padding(.vertical, 16)
                        sectionLabel("API Key")
                            .padding(.bottom, 8)
                        apiKeyField
                        Text("Stored locally on your device.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4), value: appeared)

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button("I'll set this up later", action: onNext)
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    @ViewBuilder
    private var fetchModelsButton: some View {
        Button {
            Task { await vm.fetchModels() }
        } label: {
            HStack(spacing: 6) {
                if vm.isFetchingModels {
                    ProgressView().scaleEffect(0.75)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                }
                Text(vm.isFetchingModels ? "Fetching…" : "Fetch Models")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .adaptiveGlass(.interactive, shape: Capsule())
        }
        .buttonStyle(.plain)
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
