import WidgetKit
import SwiftUI

@main
struct OpenGuinWidgetBundle: WidgetBundle {
    var body: some Widget {
        OpenGuinLockScreenWidget()
        OpenGuinControlWidget()
        RecordingLiveActivity()
    }
}
