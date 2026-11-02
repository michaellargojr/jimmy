import Foundation

/// Your set: where the Workout page lands when it comes back to you.
///
/// It is the next set to fill, the first open one after the set you logged last, so it follows
/// you even when you work out of order. Before anything is logged it's the first open set; with
/// everything logged it's the last exercise, so Done is in reach. Skipped exercises don't count.
///
/// Sets are walked the way you do them: one exercise at a time, and inside a superset round by
/// round (A1, B1, A2, B2). A one-arm pair, left then right, counts as one turn.
enum Focus {
    struct Point: Equatable {
        var itemId: String
        /// The open set, or nil when every set is logged and the point is the last exercise.
        var setId: String?
    }

    static func point(_ w: Workout) -> Point? {
        let items = w.items.filter { $0.skipped != true }
        guard let last = items.last else { return nil }
        let flat = order(items)
        // The set logged last; a tie goes to the later one in the order.
        var from = 0
        var latest = -Double.infinity
        for (i, pair) in flat.enumerated() {
            if let t = pair.set.loggedAt, t >= latest { latest = t; from = i + 1 }
        }
        let open = { (p: (item: WorkoutItem, set: SetEntry)) in p.set.reps == nil }
        if let i = flat[from...].firstIndex(where: open) ?? flat.firstIndex(where: open) {
            return Point(itemId: flat[i].item.id, setId: flat[i].set.id)
        }
        return Point(itemId: last.id, setId: nil)
    }

    /// Every set in the order it's done: pane by pane, a group round by round.
    static func order(_ items: [WorkoutItem]) -> [(item: WorkoutItem, set: SetEntry)] {
        var out: [(item: WorkoutItem, set: SetEntry)] = []
        for pane in panes(items) {
            let turns = pane.map { ($0, Self.turns($0.sets)) }
            let rounds = turns.map { $0.1.count }.max() ?? 0
            for r in 0..<rounds {
                for (item, ts) in turns where r < ts.count {
                    for s in ts[r] { out.append((item, s)) }
                }
            }
        }
        return out
    }

    /// A set is a turn; a left set followed by its right set is one turn.
    static func turns(_ sets: [SetEntry]) -> [[SetEntry]] {
        var out: [[SetEntry]] = []
        var i = 0
        while i < sets.count {
            if sets[i].side == .L, i + 1 < sets.count, sets[i + 1].side == .R {
                out.append([sets[i], sets[i + 1]]); i += 2
            } else {
                out.append([sets[i]]); i += 1
            }
        }
        return out
    }

    /// Marks when each set got its reps, so the page knows which one was logged last. A set that
    /// loses its reps loses its mark. A set that already has reps keeps whatever mark it has, so
    /// editing a number later doesn't move you.
    static func stamp(_ w: inout Workout, before old: Workout?, now: Double) {
        let was = Dictionary((old?.items ?? []).flatMap(\.sets).map { ($0.id, $0.reps != nil) }, uniquingKeysWith: { a, _ in a })
        for i in w.items.indices {
            for j in w.items[i].sets.indices {
                if w.items[i].sets[j].reps == nil {
                    w.items[i].sets[j].loggedAt = nil
                } else if old != nil, was[w.items[i].sets[j].id] != true {
                    w.items[i].sets[j].loggedAt = now
                }
            }
        }
    }
}
