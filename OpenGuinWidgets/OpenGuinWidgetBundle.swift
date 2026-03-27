import WidgetKit
import SwiftUI

@main
struct OpenGuinWidgetBundle: WidgetBundle {
    var body: some Widget {
        TasksWidget()
        TasksLockScreenWidget()
        OpenGuinControlWidget()
        RecordingLiveActivity()
    }
}
