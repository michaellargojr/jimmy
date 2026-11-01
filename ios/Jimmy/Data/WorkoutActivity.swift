import ActivityKit
import Foundation
import Observation

/// Keeps the lock screen card in step with the live workout. It watches the store instead of
/// being called from each place that changes a workout, so Start, a logged set, Finish, Discard,
/// a new color scheme or a restore all reach the card the same way. On launch it also tidies up:
/// a card left from a workout that's over goes, and a running workout without one gets one.
///
/// The app never depends on it: with Live Activities turned off for Jimmy in iOS Settings it
/// starts nothing, and any error from the system is only logged.
@MainActor
final class WorkoutActivity {
    private struct Shown: Equatable {
        var workoutId: String
        var state: WorkoutActivityAttributes.ContentState
    }

    private let store: AppStore
    private var shown: Shown?
    private var started = false

    init(store: AppStore) { self.store = store }

    func start() {
        guard !started else { return }
        started = true
        watch()
    }

    /// Reads what the card should say and asks to be told when anything it read changes.
    private func watch() {
        let want: Shown?? = withObservationTracking {
            // Until the data is loaded there are no workouts yet, which would read as "none running".
            guard store.loaded else { return nil }
            guard let w = store.activeWorkout, let state = ActivityState.make(w, store: store) else { return .some(nil) }
            return .some(Shown(workoutId: w.id, state: state))
        } onChange: { [weak self] in
            Task { @MainActor in self?.watch() }
        }
        if let want { sync(want) }
    }

    private func sync(_ want: Shown?) {
        if want == shown, shown != nil { return }
        let all = Activity<WorkoutActivityAttributes>.activities
        let mine = all.first { a in
            a.attributes.workoutId == want?.workoutId && (a.activityState == .active || a.activityState == .stale)
        }
        // Finish, Discard, or a card left from another workout: gone at once.
        for a in all where a.id != mine?.id {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        shown = want
        guard let want else { return }
        let content = ActivityContent(state: want.state, staleDate: nil)
        if let mine {
            Task { await mine.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: WorkoutActivityAttributes(workoutId: want.workoutId), content: content, pushType: nil)
            } catch {
                print("Jimmy: lock screen card not started: \(error)")
                shown = nil
            }
        }
    }
}
