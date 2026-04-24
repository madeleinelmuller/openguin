import SwiftUI

struct SettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $vm.userName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Label("Your Name", systemImage: "person.fill")
                }

                ProviderSettingsView(vm: vm)

                Section {
                    Stepper("Max tokens: \(vm.maxTokens)", value: $vm.maxTokens, in: 1024...32768, step: 1024)
                } header: {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }

                PermissionsSettingsView()

                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                } header: {
                    Label("About", systemImage: "info.circle.fill")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    SettingsView(vm: SettingsViewModel())
}
