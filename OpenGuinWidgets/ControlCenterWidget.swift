import WidgetKit
import SwiftUI
import AppIntents

struct OpenGuinControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "OpenGuinControl") {
            ControlWidgetButton(action: OpenChatIntent()) {
                Label("Open Openguin", systemImage: "bubble.left.and.bubble.right.fill")
            }
        }
        .displayName("Openguin")
        .description("Open Openguin from Control Center.")
    }
}

struct OpenChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Openguin"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
