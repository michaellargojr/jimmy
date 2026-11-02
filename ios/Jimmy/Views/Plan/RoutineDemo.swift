import SwiftUI

#if DEBUG
/// Simulator screenshots of the routine sheets without tapping: launch with `-routineDemo <step>`.
/// split: the active split's page. edit: its first routine open in the edit sheet. ask: the same
/// with one exercise removed and Done tapped. duplicate: that routine's page with the Duplicate
/// sheet open. routines: Plan › Routines. build, buildOpen, buildExercises: the New routine builder
/// with a name and a few ticks, on Routines, inside the first routine, or on Exercises. taken: the
/// "You already have" alert over Plan › Routines. Each step fires once per launch.
enum RoutineDemo {
    static let step: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-routineDemo"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()
    private static var fired: Set<String> = []

    /// True once for each place, and only when the launch asked for one of `steps`.
    static func once(_ place: String, for steps: Set<String>) -> Bool {
        guard let s = step, steps.contains(s), !fired.contains(place) else { return false }
        fired.insert(place)
        return true
    }
}
#endif
