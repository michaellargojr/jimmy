import Foundation

// Building workouts from routines, ported from src/workout.ts.

func defaultSets(for v: Version, style: Style? = nil, unit: WeightUnit, workouts: [Workout]) -> [SetEntry] {
    var bar: Bar? = v.isBarbell ? (lastBar(versionId: v.id, workouts: workouts) ?? (v.equipment == .ezbar ? .ez : .straight)) : nil
    if let bt = style?.barType { bar = bt == .ez ? .ez : .straight }
    var sets: [SetEntry] = []
    if v.defaultWarmup { sets.append(SetEntry(kind: .warmup, unit: unit, bar: bar)) }
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

/// Label for a set row: W, 1, 2, 1L, 2R ...
func setLabels(_ sets: [SetEntry]) -> [String] {
    var n = 0
    var seen: [Side: Int] = [:]
    return sets.map { s in
        if s.kind == .warmup { return "W" }
        if let side = s.side {
            seen[side, default: 0] += 1
            return "\(seen[side]!)\(side.rawValue)"
        }
        n += 1
        return String(n)
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
