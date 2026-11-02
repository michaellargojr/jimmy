import Foundation

// The routine builder (Michael's picks A and 1): one sheet with your routines and your
// variations. Routines first, the main way to build: open one and tick its exercises. Then your
// variations under their muscle group, the ones in the most workouts first.

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

/// A variation in the builder's list and how many finished workouts had it.
struct VariationUse: Identifiable, Hashable {
    var id: String { version.id }
    var version: Version
    var baseName: String
    var workouts: Int
    /// Day of its latest workout, "2026-10-15"; empty when never done.
    var last: String
    /// "3 Workouts", or "Not done yet".
    var note: String { workouts == 0 ? "Not done yet" : workoutsText(workouts) }
}

/// A muscle group and your variations in it.
struct MuscleVariations: Identifiable, Hashable {
    var id: String { muscle.rawValue }
    var muscle: MuscleGroup
    var list: [VariationUse]
}

/// Every variation you have under its exercise's main muscle group, groups in chip order. In a
/// group: most workouts first, then the most recent, then by name; never done at the bottom.
/// Groups with no variations are left out.
func variationsByMuscle(versions: [Version], exercises: [Exercise], workouts: [Workout]) -> [MuscleVariations] {
    let history = Dictionary(variationHistories(versions: versions, workouts: workouts).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let bases = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    var byMuscle: [MuscleGroup: [VariationUse]] = [:]
    for v in versions {
        guard let e = bases[v.exerciseId] else { continue }
        let h = history[v.id]
        byMuscle[e.muscleGroup, default: []].append(VariationUse(version: v, baseName: e.name, workouts: h?.sessions ?? 0, last: h?.last ?? ""))
    }
    return MuscleGroup.chipOrder.compactMap { m in
        guard let list = byMuscle[m], !list.isEmpty else { return nil }
        let sorted = list.sorted { a, b in
            if a.workouts != b.workouts { return a.workouts > b.workouts }
            if a.last != b.last { return a.last > b.last }
            return a.baseName != b.baseName ? a.baseName < b.baseName : a.version.name < b.version.name
        }
        return MuscleVariations(muscle: m, list: sorted)
    }
}

/// The style a variation was last logged with in a finished workout, for a variation ticked from
/// the list (a routine stores the exact style). Nil when never logged with one.
func lastStyleId(_ versionId: String, workouts: [Workout]) -> String? {
    for w in workouts.filter(\.isFinished).sorted(by: { $0.date > $1.date }) {
        if let item = w.items.first(where: { $0.versionId == versionId && $0.sets.contains { $0.hasData } }) { return item.styleId }
    }
    return nil
}
