import SwiftUI
import WidgetKit

/// Jimmy's widget extension. For now it holds only the lock screen card shown during a workout.
@main
struct JimmyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutActivityWidget()
    }
}
