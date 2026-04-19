import SwiftUI

struct SettingsView: View {
    @Bindable var vm: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Name") {
                    TextField("Name", text: $vm.userName)
                        .textInputAutocapitalization(.words)
                }

                ProviderSettingsView(vm: vm)

                Section("Advanced") {
                    Stepper("Max tokens: \(vm.maxTokens)", value: $vm.maxTokens, in: 1024...32768, step: 1024)
                }

                PermissionsSettingsView()

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(vm: SettingsViewModel())
}
