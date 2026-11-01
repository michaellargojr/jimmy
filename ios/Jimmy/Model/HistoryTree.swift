import Foundation

// History > Exercises: what has been logged, by variation, and the same grouped by muscle
// group > base exercise for the Muscle group sort.

/// How the History exercise list is sorted. Raw values are stored, keep them.
enum HistorySort: String, CaseIterable, Identifiable {
    case muscle, recent
    var id: String { rawValue }
    var label: String { self == .muscle ? "Muscle group" : "Most recent" }
}

/// One variation's finished, logged sessions.
struct VariationHistory: Identifiable, Hashable {
    var id: String { version.id }
    var version: Version
    /// The finished workouts it was logged in.
    var workoutIds: Set<String>
    /// Day of the latest session, "2026-10-15".
    var last: String
    var sessions: Int { workoutIds.count }
    /// "1 Workout", "3 Workouts".
    var workoutsLabel: String { workoutsText(sessions) }
    /// The line under a variation in History: "3 Workouts - Last Oct 23".
    var summary: String { historySummary(sessions, last: last) }
}

/// "1 Workout", "3 Workouts".
func workoutsText(_ n: Int) -> String { "\(n) \(n == 1 ? "Workout" : "Workouts")" }
/// The History line under a variation or a base: "3 Workouts - Last Oct 23".
func historySummary(_ n: Int, last: String) -> String { "\(workoutsText(n)) - Last \(monthDay(last))" }

/// A base exercise and its variations that have history, most recent first.
struct BaseHistory: Identifiable, Hashable {
    var id: String { exercise.id }
    var exercise: Exercise
    var variations: [VariationHistory]
    var last: String { variations.map(\.last).max() ?? "" }
    /// Workouts with any of its variations; a workout with two of them counts once.
    var workouts: Int { Set(variations.flatMap(\.workoutIds)).count }
    /// "5 Workouts - Last Oct 23".
    var summary: String { historySummary(workouts, last: last) }
}

/// A muscle group and the bases in it that have history.
struct MuscleHistory: Identifiable, Hashable {
    var id: String { muscle.rawValue }
    var muscle: MuscleGroup
    var bases: [BaseHistory]
}

/// Every variation with at least one finished session that has a logged set, most recent first.
/// A workout counts once per variation even if the variation is in it twice.
func variationHistories(versions: [Version], workouts: [Workout]) -> [VariationHistory] {
    var ids: [String: Set<String>] = [:]
    var last: [String: String] = [:]
    for w in workouts where w.isFinished {
        for item in w.items where item.sets.contains(where: { $0.hasData }) {
            ids[item.versionId, default: []].insert(w.id)
            if w.date > (last[item.versionId] ?? "") { last[item.versionId] = w.date }
        }
    }
    let order = Dictionary(versions.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
    return versions.compactMap { v in ids[v.id].map { VariationHistory(version: v, workoutIds: $0, last: last[v.id] ?? "") } }
        .sorted { a, b in a.last != b.last ? a.last > b.last : order[a.id, default: 0] < order[b.id, default: 0] }
}

/// Bases with history under their main muscle group, groups in chip order, bases by name.
/// Groups with nothing logged are left out. `matches` filters bases for search.
func historyByMuscle(_ list: [VariationHistory], exercises: [Exercise], matches: (Exercise, [VariationHistory]) -> Bool = { _, _ in true }) -> [MuscleHistory] {
    let byBase = Dictionary(grouping: list, by: { $0.version.exerciseId })
    let bases = exercises.compactMap { e -> BaseHistory? in
        guard let vs = byBase[e.id], matches(e, vs) else { return nil }
        return BaseHistory(exercise: e, variations: vs)
    }
    return MuscleGroup.chipOrder.compactMap { m in
        let here = bases.filter { $0.exercise.muscleGroup == m }.sorted { $0.exercise.name < $1.exercise.name }
        return here.isEmpty ? nil : MuscleHistory(muscle: m, bases: here)
    }
}
