import SwiftUI

struct ProviderSettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Modern background with rainbow gradient from bottom
                VStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.gray.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    Spacer()
                }

                // Rainbow blur gradient radiating from bottom
                VStack(spacing: 0) {
                    Spacer()
                    ZStack {
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.15),
                                Color.orange.opacity(0.12),
                                Color.yellow.opacity(0.10),
                                Color.green.opacity(0.08),
                                Color.blue.opacity(0.06),
                                Color.purple.opacity(0.04),
                                Color.clear
                            ]),
                            center: .bottom,
                            startRadius: 0,
                            endRadius: 600
                        )
                        .blur(radius: 80)
                    }
                    .ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 24) {
                        // Header with icon
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(.black)
                                .frame(width: 100, height: 100)
                                .glassEffect(.regular, in: .circle)

                            VStack(spacing: 4) {
                                Text("OpenGuin Settings")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.black)

                                Text("Configure your AI assistant")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
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
        }
    }

    // MARK: - Provider Section

    private var providerSectionView: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("AI Provider", systemImage: "network")
                    .font(.headline)
                    .foregroundStyle(.black)
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
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedProvider = provider
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.black)
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                if viewModel.selectedProvider == provider {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.black)
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
        switch viewModel.selectedProvider {
        case .anthropic:
            anthropicSettingsView
        case .openai:
            openaiSettingsView
        case .openaiCompatible:
            customEndpointSettingsView(title: "OpenAI-Compatible Endpoint")
        case .lmstudio:
            customEndpointSettingsView(title: "LMStudio Settings")
        }
    }

    private var anthropicSettingsView: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Anthropic API Key", systemImage: "key.fill")
                        .font(.headline)
                        .foregroundStyle(.black)

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
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 10) {
                        Button {
                            viewModel.saveCurrentProvider()
                        } label: {
                            HStack {
                                Image(systemName: viewModel.showAPIKeySaved ? "checkmark" : "square.and.arrow.down")
                                Text(viewModel.showAPIKeySaved ? "Saved" : "Save")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(.black)
                            .cornerRadius(10)
                        }

                        if !viewModel.anthropicKeyInput.isEmpty {
                            Button(role: .destructive) {
                                viewModel.clearCurrentProvider()
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(.white)
                                    .background(.red)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Text("Get your key at console.anthropic.com")
                    .font(.caption)
                    .foregroundStyle(.gray)
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
                        .foregroundStyle(.black)

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
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 10) {
                        Button {
                            viewModel.saveCurrentProvider()
                        } label: {
                            HStack {
                                Image(systemName: viewModel.showAPIKeySaved ? "checkmark" : "square.and.arrow.down")
                                Text(viewModel.showAPIKeySaved ? "Saved" : "Save")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(.black)
                            .cornerRadius(10)
                        }

                        if !viewModel.openaiKeyInput.isEmpty {
                            Button(role: .destructive) {
                                viewModel.clearCurrentProvider()
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(.white)
                                    .background(.red)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Text("Get your key at platform.openai.com")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func customEndpointSettingsView(title: String) -> some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: "server.rack")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                VStack(spacing: 10) {
                    // Endpoint
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Endpoint URL")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)

                        TextField("http://localhost:8000/v1/chat/completions", text: $viewModel.customEndpointInput)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Model name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)

                        TextField("model-name", text: $viewModel.customModelNameInput)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                    }

                    HStack(spacing: 10) {
                        Button {
                            viewModel.saveCurrentProvider()
                        } label: {
                            HStack {
                                Image(systemName: viewModel.showAPIKeySaved ? "checkmark" : "square.and.arrow.down")
                                Text(viewModel.showAPIKeySaved ? "Saved" : "Save")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(.black)
                            .cornerRadius(10)
                        }

                        if !viewModel.customEndpointInput.isEmpty {
                            Button(role: .destructive) {
                                viewModel.clearCurrentProvider()
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(.white)
                                    .background(.red)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
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
                    .foregroundStyle(.black)
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
                                    .foregroundStyle(.black)
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }

                            Spacer()

                            if viewModel.selectedAnthropicModel == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.black)
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
                    .foregroundStyle(.black)
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
                                    .foregroundStyle(.black)
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }

                            Spacer()

                            if viewModel.selectedOpenAIModel == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.black)
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
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Toggle(isOn: $viewModel.hapticFeedbackEnabled) {
                    HStack {
                        Image(systemName: "hand.tap")
                            .foregroundStyle(.black)
                        Text("Haptic Feedback")
                            .foregroundStyle(.black)
                    }
                }
                .tint(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
                    .foregroundStyle(.black)
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
            Text("This will permanently delete all of OpenGuin's memories. This cannot be undone.")
        }
    }
}

#Preview {
    ProviderSettingsView()
}
