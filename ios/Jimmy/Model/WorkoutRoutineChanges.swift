import Foundation

// A change to a workout started from a routine asks right away whether the routine takes it too
// (Michael, Nov 2): Update the routine, Save as new routine, or Just today. Swaps, adds, deletes,
// a new order and superset changes count. Styles never do: a style belongs to the exercise, not
// the routine.

/// The part of a workout a routine holds: which variations, in what order, in which groups.
struct WorkoutLineup: Equatable {
    var workoutId: String
    var items: [RoutineItem]
    var groups: [ExerciseGroup]

    init(_ w: Workout) {
        workoutId = w.id
        items = w.items.map { RoutineItem(versionId: $0.versionId, styleId: $0.styleId, groupId: $0.groupId) }
        groups = w.groups
    }

    init(workoutId: String, items: [RoutineItem], groups: [ExerciseGroup] = []) {
        self.workoutId = workoutId; self.items = items; self.groups = groups
    }
}

/// The question on screen after a change, until it is answered.
struct RoutineAsk: Identifiable, Equatable {
    let id = uid()
    var workoutId: String
    var routineId: String
    /// The workout before the first change this question covers.
    var base: WorkoutLineup
    /// The routine with that change made to it too.
    var proposed: Routine
    /// "Swapped Upright Row for Lateral Raise"
    var summary: String
}

/// One exercise in a list, told apart from another of the same variation by how many came before it.
private struct Slot: Hashable {
    var versionId: String
    var n: Int
}

private func slots(_ items: [RoutineItem]) -> [Slot] {
    var seen: [String: Int] = [:]
    return items.map { i in
        let n = seen[i.versionId, default: 0]
        seen[i.versionId] = n + 1
        return Slot(versionId: i.versionId, n: n)
    }
}

/// What one workout change (base to new) does to the routine.
struct RoutineFollow: Equatable {
    var routine: Routine
    /// The routine's exercises would differ. Nothing to ask otherwise.
    var changed: Bool
    var removed: [RoutineItem]
    var added: [RoutineItem]
    var reordered: Bool
    var regrouped: Bool
}

/// The routine with one workout change made to it too. Only what changed between `base` and
/// `new` reaches the routine, so an earlier "Just today" stays out of it: what left the workout
/// leaves the routine, what came in goes in after the exercise it follows, a new order is taken
/// up, and supersets follow. Exercises the routine keeps keep their own style.
func routineFollowing(_ r: Routine, from base: WorkoutLineup, to new: WorkoutLineup) -> RoutineFollow {
    let bS = slots(base.items), nS = slots(new.items)
    let bSet = Set(bS), nSet = Set(nS)
    let removedSlots = bSet.subtracting(nSet)
    let addedSlots = nSet.subtracting(bSet)
    let bIndex = Dictionary(zip(bS, bS.indices), uniquingKeysWith: { a, _ in a })
    let nIndex = Dictionary(zip(nS, nS.indices), uniquingKeysWith: { a, _ in a })

    // The routine's exercises, each with its slot, minus what left the workout.
    var rows = zip(slots(r.items), r.items).map { (slot: $0.0, item: $0.1) }
    let removed = rows.filter { removedSlots.contains($0.slot) }.map { $0.item }
    rows.removeAll { removedSlots.contains($0.slot) }

    // A new order among the exercises the workout kept: the routine's copies of them take it up,
    // in the places they already hold, so anything only the routine has stays where it is.
    let baseOrder = bS.filter { nSet.contains($0) }
    let newOrder = nS.filter { bSet.contains($0) }
    var reordered = false
    if baseOrder != newOrder {
        let spots = rows.indices.filter { nIndex[rows[$0].slot] != nil && bIndex[rows[$0].slot] != nil }
        let moving = spots.map { rows[$0] }.sorted { nIndex[$0.slot]! < nIndex[$1.slot]! }
        if moving.map({ $0.slot }) != spots.map({ rows[$0].slot }) {
            for (k, i) in spots.enumerated() { rows[i] = moving[k] }
            reordered = true
        }
    }

    // What came in goes after the nearest exercise before it that the routine has, or first.
    var added: [RoutineItem] = []
    for (j, s) in nS.enumerated() where addedSlots.contains(s) {
        let item = new.items[j]
        var at = 0
        for k in stride(from: j - 1, through: 0, by: -1) {
            if let i = rows.lastIndex(where: { $0.slot == nS[k] }) { at = i + 1; break }
        }
        rows.insert((slot: s, item: item), at: at)
        added.append(item)
    }

    // Supersets: an exercise whose group changed in the workout takes the workout's group.
    var regrouped = false
    for i in rows.indices {
        guard let b = bIndex[rows[i].slot], let n = nIndex[rows[i].slot] else { continue }
        let was = base.items[b].groupId, now = new.items[n].groupId
        if was != now, rows[i].item.groupId != now { rows[i].item.groupId = now; regrouped = true }
    }

    // Groups the routine now uses: its own first, then the workout's new ones. A group left with
    // one exercise is no longer a superset; a group left with none goes.
    var items = rows.map { $0.item }
    var groups = r.groups
    for g in new.groups where !groups.contains(where: { $0.id == g.id }) { groups.append(g) }
    for g in groups where items.filter({ $0.groupId == g.id }).count == 1 {
        for i in items.indices where items[i].groupId == g.id { items[i].groupId = nil }
    }
    groups.removeAll { g in !items.contains { $0.groupId == g.id } }

    var out = r
    out.items = items
    out.groups = groups
    return RoutineFollow(routine: out, changed: items != r.items, removed: removed, added: added,
                         reordered: reordered, regrouped: regrouped)
}

/// What the routine would take, in a few plain words: "Swapped Upright Row for Lateral Raise",
/// "Removed Upright Row", "Added Arnold Press", "Superset changed", "New order".
func routineFollowSummary(_ f: RoutineFollow, name: (RoutineItem) -> String) -> String {
    if f.removed.count == 1, f.added.count == 1 {
        return "Swapped \(name(f.removed[0])) for \(name(f.added[0]))"
    }
    var parts: [String] = []
    if !f.removed.isEmpty { parts.append("Removed " + f.removed.map(name).joined(separator: ", ")) }
    if !f.added.isEmpty { parts.append("Added " + f.added.map(name).joined(separator: ", ")) }
    // Making a superset can move its exercises together too; the superset is the news.
    if parts.isEmpty && f.regrouped { parts.append("Superset changed") }
    if parts.isEmpty && f.reordered { parts.append("New order") }
    return parts.joined(separator: " - ")
}
