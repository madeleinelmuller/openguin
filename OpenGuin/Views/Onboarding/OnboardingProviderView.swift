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

                Text("Pick a provider and add your API key, or connect to a local model.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.3), value: appeared)
            }
            .padding(.bottom, 32)

            GlassCard(cornerRadius: 24, padding: 20) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        sectionLabel("Provider")
                        Picker("Provider", selection: $vm.provider) {
                            ForEach(LLMProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)

                        if vm.provider.hasCustomEndpoint {
                            Divider()
                            sectionLabel("Server")
                            EndpointField(provider: vm.provider, endpoint: endpointBinding)
                            Text("Just host and port — the \u{2018}/v1\u{2019} path is added automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                        sectionLabel("Model")
                        ModelPickerOrField(vm: vm)

                        if vm.provider.requiresAPIKey {
                            Divider()
                            sectionLabel("API Key")
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var endpointBinding: Binding<String> {
        switch vm.provider {
        case .ollama: return $vm.ollamaEndpoint
        case .lmStudio: return $vm.lmStudioEndpoint
        default: return .constant("")
        }
    }
}
