import SwiftUI

struct ProviderSettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Namespace private var settingsNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated rainbow blob glow from the bottom
                RainbowBlobsBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(.blue)
                                .frame(width: 100, height: 100)
                                .glassEffect(.regular, in: .circle)

                            VStack(spacing: 4) {
                                Text("openguin Settings")
                                    .font(.title.weight(.bold))

                                Text("Configure your AI assistant")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)

                        // Provider Selection
                        providerSectionView

                        // Provider-specific settings
                        providerSpecificSettingsView

                        // Model selection
                        modelSelectionView

                        // Preferences
                        preferencesSection

                        // Danger Zone
                        dangerZoneSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadCurrentSettings()
            }
            .onChange(of: viewModel.selectedProvider) {
                viewModel.loadCurrentSettings()
            }
        }
    }

    // MARK: - Provider Section

    private var providerSectionView: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("AI Provider", systemImage: "network")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                VStack(spacing: 10) {
                    ForEach(LLMProvider.allCases) { provider in
                        providerButton(for: provider)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func providerButton(for provider: LLMProvider) -> some View {
        Button {
            withAnimation(.bouncy) {
                viewModel.selectedProvider = provider
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.body.weight(.semibold))
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.selectedProvider == provider {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .glassEffect(
                viewModel.selectedProvider == provider
                    ? .regular.tint(.blue.opacity(0.2)).interactive()
                    : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Provider Specific Settings

    @ViewBuilder
    private var providerSpecificSettingsView: some View {
        Group {
            switch viewModel.selectedProvider {
            case .anthropic:
                anthropicSettingsView
            case .openai:
                openaiSettingsView
            case .lmstudio:
                lmstudioSettingsView
            }
        }
        .animation(.smooth, value: viewModel.selectedProvider)
    }

    private var anthropicSettingsView: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Anthropic API Key", systemImage: "key.fill")
                        .font(.headline)

                    Spacer()

                    Button {
                        viewModel.openProviderAuthURL()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if viewModel.hasAPIKey && viewModel.selectedProvider == .anthropic {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        if viewModel.isUsingDevKey {
                            Text("Using development key")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(viewModel.currentMaskedAPIKey)
                                .font(.subheadline.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 10) {
                    HStack {
                        if viewModel.isAnthropicKeyVisible {
                            TextField("sk-ant-...", text: $viewModel.anthropicKeyInput)
                                .font(.body.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("sk-ant-...", text: $viewModel.anthropicKeyInput)
                                .font(.body.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Button {
                            viewModel.isAnthropicKeyVisible.toggle()
                        } label: {
                            Image(systemName: viewModel.isAnthropicKeyVisible ? "eye.slash" : "eye")
                                .font(.caption.weight(.semibold))
                                .frame(width: 30, height: 30)
                                .background(.regularMaterial, in: Circle())
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))

                    saveAndClearButtons(hasValue: !viewModel.anthropicKeyInput.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Text("Get your key at console.anthropic.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var openaiSettingsView: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("OpenAI API Key", systemImage: "key.fill")
                        .font(.headline)

                    Spacer()

                    Button {
                        viewModel.openProviderAuthURL()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if viewModel.hasAPIKey && viewModel.selectedProvider == .openai {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(viewModel.currentMaskedAPIKey)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 10) {
                    HStack {
                        if viewModel.isOpenAIKeyVisible {
                            TextField("sk-...", text: $viewModel.openaiKeyInput)
                                .font(.body.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("sk-...", text: $viewModel.openaiKeyInput)
                                .font(.body.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Button {
                            viewModel.isOpenAIKeyVisible.toggle()
                        } label: {
                            Image(systemName: viewModel.isOpenAIKeyVisible ? "eye.slash" : "eye")
                                .font(.caption.weight(.semibold))
                                .frame(width: 30, height: 30)
                                .background(.regularMaterial, in: Circle())
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))

                    saveAndClearButtons(hasValue: !viewModel.openaiKeyInput.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Text("Get your key at platform.openai.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - LMStudio Settings

    private var lmstudioSettingsView: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("LMStudio Settings", systemImage: "server.rack")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                VStack(spacing: 10) {
                    // Endpoint
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server URL")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField(LLMProvider.lmstudio.defaultEndpoint,
                                  text: $viewModel.customEndpointInput)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Model name (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Name (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("Uses currently loaded model", text: $viewModel.customModelNameInput)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                    }

                    saveAndClearButtons(hasValue: !viewModel.customEndpointInput.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Help text
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Make sure LMStudio's local server is running.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("Default endpoint: \(LLMProvider.lmstudio.defaultEndpoint)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Shared Save/Clear Buttons

    private func saveAndClearButtons(hasValue: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                viewModel.saveCurrentProvider()
            } label: {
                HStack {
                    Image(systemName: viewModel.showAPIKeySaved ? "checkmark" : "square.and.arrow.down")
                    Text(viewModel.showAPIKeySaved ? "Saved" : "Save")
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.tint(.blue).interactive(),
                in: RoundedRectangle(cornerRadius: 10)
            )

            if hasValue {
                Button(role: .destructive) {
                    viewModel.clearCurrentProvider()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .glassEffect(
                    .regular.tint(.red).interactive(),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
        }
    }

    // MARK: - Model Selection

    @ViewBuilder
    private var modelSelectionView: some View {
        switch viewModel.selectedProvider {
        case .anthropic:
            anthropicModelSelectionView
        case .openai:
            openaiModelSelectionView
        default:
            EmptyView()
        }
    }

    private var anthropicModelSelectionView: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Model", systemImage: "cpu")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ForEach(AnthropicModel.allCases) { model in
                    Button {
                        withAnimation(.bouncy) {
                            viewModel.selectedAnthropicModel = model
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                    .font(.body.weight(.medium))
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if viewModel.selectedAnthropicModel == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.primary)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .glassEffect(
                            viewModel.selectedAnthropicModel == model
                                ? .regular.tint(.blue.opacity(0.2)).interactive()
                                : .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var openaiModelSelectionView: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Model", systemImage: "cpu")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ForEach(OpenAIModel.allCases) { model in
                    Button {
                        withAnimation(.bouncy) {
                            viewModel.selectedOpenAIModel = model
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                    .font(.body.weight(.medium))
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if viewModel.selectedOpenAIModel == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.primary)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .glassEffect(
                            viewModel.selectedOpenAIModel == model
                                ? .regular.tint(.blue.opacity(0.2)).interactive()
                                : .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Preferences", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Toggle(isOn: $viewModel.hapticFeedbackEnabled) {
                    HStack {
                        Image(systemName: "hand.tap")
                        Text("Haptic Feedback")
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Text("Haptics are used for tactile feedback while chatting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Data", systemImage: "externaldrive")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Button(role: .destructive) {
                    viewModel.showClearConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Memory Files")
                        Spacer()
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.tint(.red.opacity(0.2)).interactive(), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
        .alert("Clear Memory", isPresented: $viewModel.showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                Task {
                    await MemoryManager.shared.resetToDefaults()
                }
            }
        } message: {
            Text("This will permanently delete all of openguin's memories. This cannot be undone.")
        }
    }
}

#Preview {
    ProviderSettingsView()
}
