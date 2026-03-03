import SwiftUI

@main
struct OpenGuinApp: App {
    init() {
        // Register notification delegate before the app finishes launching
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 26.0, *) {
                    ContentView()
                        .task {
                            // Request permission on first launch (system only shows dialog once)
                            await NotificationManager.shared.requestPermission()
                        }
                } else {
                    UnsupportedVersionView()
                }
            }
        }
    }
}

private struct UnsupportedVersionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.orange)
            Text("iOS 26 Required")
                .font(.title3.bold())
            Text("This build preserves iOS 26-only capabilities. Please update your device to iOS 26 or later.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background {
            RainbowBlobsBackground()
                .ignoresSafeArea()
        }
    }
}
