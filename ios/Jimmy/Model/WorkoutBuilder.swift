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

// MARK: - Groups in Overview

/// Keeps groups whole after any change in Overview. A group split apart keeps only its longest run,
/// a group left with one exercise dissolves, and every group is named by its count.
func tidyGroups(_ w: Workout) -> Workout {
    var w = w
    let n = w.items.count
    // Each group's runs of consecutive members; only the longest stays in the group.
    var runs: [String: [Range<Int>]] = [:]
    var i = 0
    while i < n {
        guard let g = w.items[i].groupId else { i += 1; continue }
        var j = i
        while j < n, w.items[j].groupId == g { j += 1 }
        runs[g, default: []].append(i..<j)
        i = j
    }
    for (_, rs) in runs {
        let keep = rs.firstIndex { $0.count == rs.map(\.count).max() } ?? 0
        for (k, r) in rs.enumerated() where k != keep { for x in r { w.items[x].groupId = nil } }
    }
    var counts: [String: Int] = [:]
    for it in w.items { if let g = it.groupId { counts[g, default: 0] += 1 } }
    for x in w.items.indices { if let g = w.items[x].groupId, counts[g, default: 0] < 2 { w.items[x].groupId = nil } }
    w.groups = w.groups.compactMap { g in
        guard let c = counts[g.id], c >= 2 else { return nil }
        return ExerciseGroup(id: g.id, type: .forCount(c))
    }
    return w
}

/// A drag in Overview. The moved exercise joins a group when dropped between two of its members,
/// stays in its own group while it still touches it, and otherwise leaves it.
func moveItem(_ w: Workout, from: IndexSet, to: Int) -> Workout {
    var w = w
    // The same as List's move(fromOffsets:toOffset:), which lives in SwiftUI.
    let picked = from.map { w.items[$0] }
    let moved = Set(picked.map(\.id))
    for i in from.reversed() { w.items.remove(at: i) }
    w.items.insert(contentsOf: picked, at: to - from.filter { $0 < to }.count)
    for i in w.items.indices where moved.contains(w.items[i].id) {
        let prev = i > 0 ? w.items[i - 1].groupId : nil
        let next = i + 1 < w.items.count ? w.items[i + 1].groupId : nil
        if let g = prev, g == next { w.items[i].groupId = g }
        else if let g = w.items[i].groupId, g != prev, g != next { w.items[i].groupId = nil }
    }
    return tidyGroups(w)
}

/// Ticked loose exercises become one group, pulled together at the first one's place.
func makeGroup(_ w: Workout, ids: Set<String>) -> Workout {
    var w = w
    let gid = uid()
    let chosen = w.items.filter { ids.contains($0.id) }.map { var it = $0; it.groupId = gid; return it }
    guard chosen.count >= 2, let at = w.items.firstIndex(where: { ids.contains($0.id) }) else { return w }
    w.items.removeAll { ids.contains($0.id) }
    w.items.insert(contentsOf: chosen, at: min(at, w.items.count))
    w.groups.append(ExerciseGroup(id: gid, type: .forCount(chosen.count)))
    return tidyGroups(w)
}

/// Ticked exercises leave their groups. If two or more stay, they keep together and the ones leaving
/// sit just below them, in order; otherwise the group dissolves where it is.
func ungroup(_ w: Workout, ids: Set<String>) -> Workout {
    var w = w
    let touched = w.items.filter { ids.contains($0.id) }.compactMap(\.groupId)
    let gids = touched.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    for gid in gids {
        let members = w.items.filter { $0.groupId == gid }
        let leaving = members.filter { ids.contains($0.id) }
        if members.count - leaving.count < 2 {
            for x in w.items.indices where w.items[x].groupId == gid { w.items[x].groupId = nil }
            continue
        }
        w.items.removeAll { $0.groupId == gid && ids.contains($0.id) }
        let end = (w.items.lastIndex { $0.groupId == gid } ?? -1) + 1
        w.items.insert(contentsOf: leaving.map { var it = $0; it.groupId = nil; return it }, at: end)
    }
    return tidyGroups(w)
}
