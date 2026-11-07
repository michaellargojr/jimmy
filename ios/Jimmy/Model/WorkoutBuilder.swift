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
    return Workout(name: r.name, date: today(), gymId: gymId, routineId: r.id, pickedAt: nowMs(), items: items, groups: r.groups)
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
/// 1L 1R > 1R 1L (you started with the other arm) > WL WR > DL DR > 1L 1R. Only the first tap
/// swaps sides; warm-up and drop pairs always read left then right, like the warm-ups up top.
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
        for (k, i) in group.enumerated() { out[i].kind = .warmup; out[i].side = k == 0 ? .L : .R }
        if group.count == 1 {
            out.insert(SetEntry(kind: .warmup, unit: head.unit, side: .R, bar: head.bar), at: first + 1)
        }
    case .warmup:
        for i in group { out[i].kind = .drop }
    case .drop:
        for (k, i) in group.enumerated() { out[i].kind = .working; out[i].side = k == 0 ? .L : .R }
    }
    return out
}

/// The set rows cut into what a press-and-hold drag moves together: a one-arm L/R pair, or a row
/// alone, read from the top the same way as setGroup.
func setUnits(_ sets: [SetEntry]) -> [[Int]] {
    var units: [[Int]] = []
    var i = 0
    while i < sets.count {
        let g = setGroup(sets, at: i)
        units.append(g.isEmpty ? [i] : g)
        i = (g.last ?? i) + 1
    }
    return units
}

/// A drop after a press-and-hold drag: the unit at `from` (a row, or a one-arm pair) ends up at
/// unit position `to`. The sets keep their ids, kinds and numbers; only the order changes, so the
/// labels count again from the top (a blank row dragged above set 1 and tapped to W is the warm-up).
func moveSetUnit(_ sets: [SetEntry], from: Int, to: Int) -> [SetEntry] {
    var units = setUnits(sets).map { $0.map { sets[$0] } }
    guard units.indices.contains(from), units.indices.contains(to), from != to else { return sets }
    let moved = units.remove(at: from)
    units.insert(moved, at: to)
    return units.flatMap { $0 }
}

/// Where a lifted unit would land. Its leading edge passing a neighbour's middle takes that
/// neighbour's place, so a tall pair can still reach past a short row at either end.
/// `heights` are the units' heights on screen, `offset` how far the finger has moved it.
func setDropIndex(heights: [CGFloat], from: Int, offset: CGFloat) -> Int {
    guard heights.indices.contains(from) else { return from }
    var y: CGFloat = 0
    var tops: [CGFloat] = []
    for h in heights { tops.append(y); y += h }
    let top = tops[from] + offset, bottom = top + heights[from]
    // The units that end up above it: the ones above whose middle it hasn't risen to, and the
    // ones below whose middle it has sunk past.
    return heights.indices.filter { j in
        let mid = tops[j] + heights[j] / 2
        return j < from ? top > mid : (j > from && bottom >= mid)
    }.count
}

/// One-arm sets always carry a side. A row without one (from a workout started on an older build,
/// or a variation switched to one arm mid-workout) becomes L, with an empty R partner after it.
func pairSides(_ sets: [SetEntry]) -> [SetEntry] {
    sets.flatMap { s -> [SetEntry] in
        guard s.side == nil else { return [s] }
        var l = s
        l.side = .L
        return [l, SetEntry(kind: s.kind, unit: s.unit, side: .R, bar: s.bar)]
    }
}

/// Every set has its numbers in. Only then does the card show its verdict.
func setsComplete(_ sets: [SetEntry], bodyweight: Bool) -> Bool {
    !sets.isEmpty && sets.allSatisfy { $0.reps != nil && ($0.weight != nil || bodyweight) }
}

/// A pane is finished when every exercise in it that wasn't skipped has every set checked.
/// Adding a set opens it again until that set is checked too. Skipping never fills it: a pane
/// with nothing but skipped exercises stays open, a visible gap.
func paneFinished(_ pane: [WorkoutItem], versions: [Version]) -> Bool {
    let done = pane.filter { $0.skipped != true }
    return !done.isEmpty && done.allSatisfy { item in
        setsComplete(item.sets, bodyweight: versions.first { $0.id == item.versionId }?.family == .body)
    }
}

/// The last set of the last exercise has its check: the end of the workout is reached, so the big
/// Done shows under it. "Last" is the order sets are done in (see Focus.order), so in a closing
/// superset it's the final round's last set. Skipped exercises don't count.
func lastSetChecked(_ w: Workout, versions: [Version]) -> Bool {
    guard let last = Focus.order(w.items.filter { $0.skipped != true }).last else { return false }
    return setsComplete([last.set], bodyweight: versions.first { $0.id == last.item.versionId }?.family == .body)
}

/// What each exercise in a group is called on its card: "Superset 1", "Superset 2"; "Triset 1" to 3;
/// "Circuit 1" and on. Numbered so it's clear which one is which when they share a screen.
func groupLabels(count: Int) -> [String] {
    guard count >= 2 else { return [] }
    let name = GroupType.forCount(count).label
    return (1...count).map { "\(name) \($0)" }
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
