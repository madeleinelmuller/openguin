import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated rainbow background
                AnimatedRainbowBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        apiKeySection
                        modelSection
                        preferencesSection
                        dangerZoneSection
                        aboutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadCurrentKey()
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("API Key", systemImage: "key.fill")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                if viewModel.hasAPIKey {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        if viewModel.isUsingDevKey {
                            Text("Using development key")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(viewModel.maskedAPIKey)
                                .font(.subheadline.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 10) {
                    HStack {
                        if viewModel.isAPIKeyVisible {
                            TextField("sk-ant-...", text: $viewModel.apiKeyInput)
                                .font(.body.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("sk-ant-...", text: $viewModel.apiKeyInput)
                                .font(.body.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Button {
                            viewModel.isAPIKeyVisible.toggle()
                        } label: {
                            Image(systemName: viewModel.isAPIKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

                    HStack(spacing: 10) {
                        Button {
                            viewModel.saveAPIKey()
                        } label: {
                            HStack {
                                Image(systemName: viewModel.showAPIKeySaved ? "checkmark" : "square.and.arrow.down")
                                Text(viewModel.showAPIKeySaved ? "Saved" : "Save Key")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .glassEffect(
                            .regular.tint(.blue).interactive(),
                            in: RoundedRectangle(cornerRadius: 14)
                        )

                        if !viewModel.apiKeyInput.isEmpty {
                            Button {
                                viewModel.clearAPIKey()
                            } label: {
                                HStack {
                                    Image(systemName: "xmark")
                                    Text("Clear")
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                            }
                            .glassEffect(
                                .regular.tint(.red).interactive(),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Text("Your API key is stored locally on this device. Get one at console.anthropic.com")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Model", systemImage: "cpu")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ForEach(ClaudeModel.allCases) { model in
                    Button {
                        withAnimation(.bouncy) {
                            viewModel.selectedModel = model
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if viewModel.selectedModel == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(
                            viewModel.selectedModel == model
                                ? .regular.tint(.blue.opacity(0.3)).interactive()
                                : .regular.interactive(),
                            in: RoundedRectangle(cornerRadius: 14)
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
                            .foregroundStyle(.purple)
                        Text("Haptic Feedback")
                    }
                }
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.tint(.red.opacity(0.2)).interactive(), in: RoundedRectangle(cornerRadius: 14))
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

    // MARK: - About

    private var aboutSection: some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                Image("OpenGuinIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .glassEffect(.regular, in: .circle)

                Text("OpenGuin")
                    .font(.title2.weight(.bold))

                Text("AI Assistant with Persistent Memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

#Preview {
    SettingsView()
}
