import Foundation

// The routine builder (Michael's picks A and 2): one sheet with your routines and the exercise
// list. Routines first, the main way to build: open one and tick its exercises. Then exercises by
// muscle group, the ones in the most workouts first: open one and tick its variations, or set up
// a new one.

/// One tick in the builder: an exercise out of a routine, or a variation from your list.
enum BuilderPick: Hashable {
    case routine(RoutinePick)
    case variation(versionId: String, styleId: String?)

    var versionId: String? {
        if case let .variation(v, _) = self { return v }
        return nil
    }
}

/// The ticks as rows of the new routine, in the order they were ticked. A superset, triset or
/// circuit whose members were all ticked stays one, under a fresh group id, where its first
/// member was ticked; one ticked only in part comes apart.
func builtExercises(_ picks: [BuilderPick], routines: [Routine]) -> PickedExercises {
    let byId = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let ticked: Set<RoutinePick> = Set(picks.compactMap { if case let .routine(p) = $0 { return p }; return nil })
    var out = PickedExercises()
    var done: Set<RoutinePick> = []
    for pick in picks {
        switch pick {
        case let .variation(v, s):
            out.items.append(RoutineItem(versionId: v, styleId: s))
        case let .routine(p):
            guard !done.contains(p), let r = byId[p.routineId], r.items.indices.contains(p.index) else { continue }
            let item = r.items[p.index]
            if let gid = item.groupId, let g = r.groups.first(where: { $0.id == gid }) {
                let members = r.items.indices.filter { r.items[$0].groupId == gid }
                if members.count > 1, members.allSatisfy({ ticked.contains(RoutinePick(routineId: r.id, index: $0)) }) {
                    let id = uid()
                    out.groups.append(ExerciseGroup(id: id, type: g.type))
                    for i in members {
                        var it = r.items[i]
                        it.groupId = id
                        out.items.append(it)
                        done.insert(RoutinePick(routineId: r.id, index: i))
                    }
                    continue
                }
            }
            var it = item
            it.groupId = nil
            out.items.append(it)
            done.insert(p)
        }
    }
    return out
}

/// One of your variations in the builder and how many finished workouts had it.
struct VariationUse: Identifiable, Hashable {
    var id: String { version.id }
    var version: Version
    var workouts: Int
    /// Day of its latest workout, "2026-10-15"; empty when never done.
    var last: String
    /// "3 Workouts", or "Not done yet".
    var note: String { workouts == 0 ? "Not done yet" : workoutsText(workouts) }
}

/// A base exercise in the builder (Michael's pick 2: the exercise first, then its variations).
struct BaseUse: Identifiable, Hashable {
    var id: String { exercise.id }
    var exercise: Exercise
    /// Your variations of it, most workouts first.
    var variations: [VariationUse]
    /// Workouts with any of its variations; a workout with two of them counts once.
    var workouts: Int
    var last: String
    var mine: Bool { !variations.isEmpty }
}

/// A muscle group and its exercises, in the builder's order.
struct MuscleBases: Identifiable, Hashable {
    var id: String { muscle.rawValue }
    var muscle: MuscleGroup
    var bases: [BaseUse]
}

/// Every base exercise with your variations of it. Most workouts first, then the most recent,
/// then yours before the library's, then by name. Variations the same way.
func baseUses(exercises: [Exercise], versions: [Version], workouts: [Workout]) -> [BaseUse] {
    let history = Dictionary(variationHistories(versions: versions, workouts: workouts).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let byBase = Dictionary(grouping: versions, by: { $0.exerciseId })
    let list = exercises.map { e -> BaseUse in
        let vs = (byBase[e.id] ?? []).map { v -> VariationUse in
            let h = history[v.id]
            return VariationUse(version: v, workouts: h?.sessions ?? 0, last: h?.last ?? "")
        }
        .sorted { a, b in
            if a.workouts != b.workouts { return a.workouts > b.workouts }
            if a.last != b.last { return a.last > b.last }
            return a.version.name < b.version.name
        }
        let ids = Set(vs.compactMap { history[$0.id] }.flatMap(\.workoutIds))
        return BaseUse(exercise: e, variations: vs, workouts: ids.count, last: vs.map(\.last).max() ?? "")
    }
    return list.sorted { a, b in
        if a.workouts != b.workouts { return a.workouts > b.workouts }
        if a.last != b.last { return a.last > b.last }
        if a.mine != b.mine { return a.mine }
        return a.exercise.name < b.exercise.name
    }
}

/// Grouped like Plan › Exercises: all exercises or only yours; with a muscle picked, every
/// exercise that works it, otherwise each under its main group. Groups in chip order, empty ones
/// left out, exercises in the order given.
func basesByMuscle(_ bases: [BaseUse], mineOnly: Bool, muscle: MuscleGroup?) -> [MuscleBases] {
    let pool = bases.filter { !mineOnly || $0.mine }
    return (muscle.map { [$0] } ?? MuscleGroup.chipOrder).compactMap { m in
        let here = pool.filter { muscle == nil ? $0.exercise.muscleGroup == m : $0.exercise.groups.contains(m) }
        return here.isEmpty ? nil : MuscleBases(muscle: m, bases: here)
    }
}

/// Search, as in Plan › Exercises (searchRank): best match first, then the order given.
func searchBases(_ bases: [BaseUse], query: String, muscle: MuscleGroup?) -> [BaseUse] {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    let ranked = bases.enumerated().compactMap { (i, b) -> (base: BaseUse, rank: Int, at: Int)? in
        if let m = muscle, !b.exercise.groups.contains(m) { return nil }
        guard let r = searchRank(b.exercise, q) else { return nil }
        return (base: b, rank: r, at: i)
    }
    return ranked.sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.at < $1.at }.map(\.base)
}

/// The style a variation was last logged with in a finished workout, for a variation ticked from
/// the list (a routine stores the exact style). Nil when never logged with one.
func lastStyleId(_ versionId: String, workouts: [Workout]) -> String? {
    for w in workouts.filter(\.isFinished).sorted(by: { $0.date > $1.date }) {
        if let item = w.items.first(where: { $0.versionId == versionId && $0.sets.contains { $0.hasData } }) { return item.styleId }
    }
    return nil
}
