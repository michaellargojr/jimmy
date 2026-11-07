import ActivityKit
import Foundation

/// The card on the lock screen while a workout runs. Built into both the app, which works out
/// every word and number, and the widget extension, which only draws what it's given: the
/// extension never reads the app's data.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Shoulders", in the accent color, with the clock beside it.
        var workoutName: String
        /// When Start was tapped. The card's clock counts up from it by itself, so nothing has to
        /// update it while you rest.
        var startedAt: Date
        /// Your set's exercise, named like the Workout card: "Dumbbell Shoulder Press".
        var exercise: String
        /// The variation chip's words, as on the Workout card: "Two arms", "Seated".
        var tags: [String]
        /// "Triset 1" when the exercise is part of a group, like its chip on the Workout card.
        var groupLabel: String?
        /// "Set 1 of 2", "Set 1 of 2 - Left", "Warm-up", "Drop set", or "All sets done".
        var setLine: String
        /// The set on its own: "1", "W" or "D". Nil once every set is logged.
        var setMark: String?
        /// "of 2" beside the set number. Nil for a warm-up or a drop set.
        var setOf: String?
        /// "Left" or "Right" for one arm.
        var side: String?
        var allDone: Bool
        /// The color scheme from Settings: the accent, and the text that sits on it.
        var accent: UInt32
        var onAccent: UInt32
    }

    /// Which workout the card belongs to, so a card left over from another one can be ended.
    var workoutId: String
}
