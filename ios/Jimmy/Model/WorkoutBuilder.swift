import Foundation

// Building workouts from routines, ported from src/workout.ts.

func defaultSets(for v: Version, style: Style? = nil, unit: WeightUnit, workouts: [Workout]) -> [SetEntry] {
    var bar: Bar? = v.isBarbell ? (lastBar(versionId: v.id, workouts: workouts) ?? (v.equipment == .ezbar ? .ez : .straight)) : nil
    if let bt = style?.barType { bar = bt == .ez ? .ez : .straight }
    var sets: [SetEntry] = []
    if v.defaultWarmup {
        if v.arms == .one {
            sets.append(SetEntry(kind: .warmup, unit: unit, side: .L, bar: bar))
            sets.append(SetEntry(kind: .warmup, unit: unit, side: .R, bar: bar))
        } else {
            sets.append(SetEntry(kind: .warmup, unit: unit, bar: bar))
        }
    }
    for _ in 0..<max(0, v.defaultSets) {
        if v.arms == .one {
            sets.append(SetEntry(kind: .working, unit: unit, side: .L, bar: bar))
            sets.append(SetEntry(kind: .working, unit: unit, side: .R, bar: bar))
        } else {
            sets.append(SetEntry(kind: .working, unit: unit, bar: bar))
        }
    }
    return sets
}

func newItem(for v: Version, style: Style? = nil, unit: WeightUnit, workouts: [Workout], groupId: String? = nil) -> WorkoutItem {
    WorkoutItem(versionId: v.id, styleId: style?.id, groupId: groupId, sets: defaultSets(for: v, style: style, unit: unit, workouts: workouts))
}

func workoutFromRoutine(_ r: Routine, versions: [Version], styles: [Style] = [], unit: WeightUnit, workouts: [Workout], gymId: String? = nil) -> Workout {
    let vmap = Dictionary(versions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let smap = Dictionary(styles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let items = r.items.compactMap { ri -> WorkoutItem? in
        guard let v = vmap[ri.versionId] else { return nil }
        return newItem(for: v, style: ri.styleId.flatMap { smap[$0] }, unit: unit, workouts: workouts, groupId: ri.groupId)
    }
    return Workout(name: r.name, date: today(), gymId: gymId, routineId: r.id, startedAt: nowMs(), items: items, groups: r.groups)
}

/// Label for a set row: W, D, 1, 2, and for one arm WL, WR, 1L, 1R, DL ...
func setLabels(_ sets: [SetEntry]) -> [String] {
    var n = 0
    var seen: [Side: Int] = [:]
    return sets.map { s in
        let side = s.side?.rawValue ?? ""
        switch s.kind {
        case .warmup: return "W" + side
        case .drop: return "D" + side
        case .working:
            if let sd = s.side {
                seen[sd, default: 0] += 1
                return "\(seen[sd]!)\(side)"
            }
            n += 1
            return String(n)
        }
    }
}

/// The rows a label tap changes together: a one-arm L/R pair of the same kind, or the row alone.
/// Pairs are read from the top, so rows 1-2, 3-4 ... pair up when they are opposite sides.
func setGroup(_ sets: [SetEntry], at index: Int) -> [Int] {
    var i = 0
    while i < sets.count {
        let a = sets[i]
        if i + 1 < sets.count, let sa = a.side, let sb = sets[i + 1].side, sa != sb, a.kind == sets[i + 1].kind {
            if index == i || index == i + 1 { return [i, i + 1] }
            i += 2
        } else {
            if index == i { return [i] }
            i += 1
        }
    }
    return []
}

/// Tapping a set label. Two arms: 1 > W > D > 1. One arm, the L/R pair moves together:
/// 1L 1R > 1R 1L (you started with the other arm) > WR WL > DR DL > 1L 1R.
/// A lone one-arm row that becomes a warm-up gets its other side added, so warm-ups come in pairs.
func cycleSetKind(_ sets: [SetEntry], at index: Int) -> [SetEntry] {
    let group = setGroup(sets, at: index)
    guard let first = group.first else { return sets }
    var out = sets
    let head = sets[first]
    let flip: (Side) -> Side = { $0 == .L ? .R : .L }
    if head.side == nil {
        out[first].kind = head.kind == .working ? .warmup : head.kind == .warmup ? .drop : .working
        return out
    }
    switch head.kind {
    case .working where head.side == .L:
        for i in group { out[i].side = out[i].side.map(flip) }
    case .working:
        for i in group { out[i].kind = .warmup }
        if group.count == 1, let sd = head.side {
            out.insert(SetEntry(kind: .warmup, unit: head.unit, side: flip(sd), bar: head.bar), at: first + 1)
        }
    case .warmup:
        for i in group { out[i].kind = .drop }
    case .drop:
        for (k, i) in group.enumerated() { out[i].kind = .working; out[i].side = k == 0 ? .L : .R }
    }
    return out
}

/// Every set has its numbers in. Only then does the card show its verdict.
func setsComplete(_ sets: [SetEntry], bodyweight: Bool) -> Bool {
    !sets.isEmpty && sets.allSatisfy { $0.reps != nil && ($0.weight != nil || bodyweight) }
}

/// Consecutive items sharing a groupId form one pane.
func panes(_ items: [WorkoutItem]) -> [[WorkoutItem]] {
    var out: [[WorkoutItem]] = []
    for it in items {
        if let gid = it.groupId, let last = out.last, last.first?.groupId == gid {
            out[out.count - 1].append(it)
        } else {
            out.append([it])
        }
    }
    return out
}
