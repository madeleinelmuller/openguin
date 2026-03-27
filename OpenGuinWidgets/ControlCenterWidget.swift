import WidgetKit
import SwiftUI
import AppIntents

struct OpenGuinControlWidget: ControlWidget {
    let kind = "OpenGuinControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: LaunchOpenGuinIntent()) {
                Label("openguin", systemImage: "message")
            }
        }
        .displayName("Open openguin")
        .description("Quickly open openguin chat.")
    }
}

// MARK: - Launch Intent

struct LaunchOpenGuinIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Open openguin"
    nonisolated static let description: IntentDescription = "Opens the openguin app"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
