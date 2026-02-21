import SwiftUI

/// Legacy entry point kept for compatibility.
///
/// `ProviderSettingsView` is the actively maintained settings implementation.
struct SettingsView: View {
    var body: some View {
        ProviderSettingsView()
    }
}

#Preview {
    SettingsView()
}
