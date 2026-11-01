import Foundation

/// What the lock screen card says during a workout. It's all worked out here, in the app, so the
/// card only draws it. Your set is the one the Workout page lands on (Focus.point), so the card
/// and the page always agree.
enum ActivityState {
    typealias State = WorkoutActivityAttributes.ContentState

    /// Nil while the workout waits for Start, and once it's finished: there's no card then.
    static func make(_ w: Workout, store: AppStore) -> State? {
        guard w.isActive, let started = w.startedAt, let point = Focus.point(w),
              let item = w.items.first(where: { $0.id == point.itemId }),
              let v = store.version(item.versionId) else { return nil }
        let colors = Palette.accentHex(store.settings.scheme, dark: true)
        var state = State(workoutName: w.name, startedAt: Date(timeIntervalSince1970: started / 1000),
                          exercise: store.workoutName(v), tags: store.variationTags(v), groupLabel: groupLabel(item, in: w),
                          setLine: "All sets done", setMark: nil, setOf: nil, side: nil, allDone: true, accent: colors.accent, onAccent: colors.onAccent)
        // Every set logged: the point is the last exercise, with no set.
        guard let setId = point.setId, let s = item.sets.first(where: { $0.id == setId }) else { return state }
        let words = setWords(s, in: item.sets)
        state.allDone = false
        state.setMark = words.mark
        state.setOf = words.of
        state.side = s.side.map { $0 == .L ? "Left" : "Right" }
        state.setLine = [words.line, state.side].compactMap { $0 }.joined(separator: " - ")
        return state
    }

    /// "Triset 2" when the exercise shares its page with others, the same words as its chip.
    static func groupLabel(_ item: WorkoutItem, in w: Workout) -> String? {
        guard let pane = panes(w.items).first(where: { $0.contains { $0.id == item.id } }), pane.count > 1,
              let n = pane.firstIndex(where: { $0.id == item.id }) else { return nil }
        return groupLabels(count: pane.count)[n]
    }

    /// "Set 1 of 2", with "1" and "of 2" for a big number. Warm-ups and drop sets go by name, like
    /// their W and D labels. One arm counts a left and its right as one set, like 1L and 1R.
    static func setWords(_ s: SetEntry, in sets: [SetEntry]) -> (line: String, mark: String, of: String?) {
        switch s.kind {
        case .warmup: return ("Warm-up", "W", nil)
        case .drop: return ("Drop set", "D", nil)
        case .working:
            let working = sets.filter { $0.kind == .working && ($0.side == nil || $0.side == s.side) }
            let n = (working.firstIndex { $0.id == s.id } ?? 0) + 1
            return ("Set \(n) of \(working.count)", String(n), "of \(working.count)")
        }
    }
}
