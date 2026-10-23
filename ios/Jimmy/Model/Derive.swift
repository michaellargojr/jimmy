import Foundation

// Derived facts about history, ported from src/derive.ts.

struct LastSession {
    var workout: Workout
    var item: WorkoutItem
    var daysAgo: Int
    var verdict: Verdict
    var version: Version
}

private func hasData(_ item: WorkoutItem) -> Bool { item.sets.contains { $0.hasData } }

func sortedNewestFirst(_ ws: [Workout]) -> [Workout] {
    ws.sorted { a, b in
        if a.date != b.date { return a.date > b.date }
        return (a.startedAt ?? 0) > (b.startedAt ?? 0)
    }
}

/// Most recent session of this version (excluding the given workout).
func lastSession(versionId: String, workouts: [Workout], versions: [Version], excludeWorkoutId: String? = nil, before: String? = nil) -> LastSession? {
    guard let v = versions.first(where: { $0.id == versionId }) else { return nil }
    for w in sortedNewestFirst(workouts) {
        if w.id == excludeWorkoutId { continue }
        if let before, w.date > before { continue }
        if let item = w.items.first(where: { $0.versionId == versionId && hasData($0) }) {
            return LastSession(workout: w, item: item, daysAgo: daysBetween(w.date, today()), verdict: verdict(item.sets, v), version: v)
        }
    }
    return nil
}

/// Most recent session of any other version of the same base exercise.
func otherVersionLast(version: Version, workouts: [Workout], versions: [Version], excludeWorkoutId: String? = nil) -> LastSession? {
    let siblings = versions.filter { $0.exerciseId == version.exerciseId && $0.id != version.id }
    var best: LastSession?
    for s in siblings {
        if let ls = lastSession(versionId: s.id, workouts: workouts, versions: versions, excludeWorkoutId: excludeWorkoutId) {
            if best == nil || ls.workout.date > best!.workout.date { best = ls }
        }
    }
    return best
}

func lastBar(versionId: String, workouts: [Workout]) -> Bar? {
    for w in sortedNewestFirst(workouts) {
        if let item = w.items.first(where: { $0.versionId == versionId }), let s = item.sets.reversed().first(where: { $0.bar != nil }) {
            return s.bar
        }
    }
    return nil
}

func routineLast(_ routine: Routine, workouts: [Workout]) -> Workout? {
    sortedNewestFirst(workouts).first { $0.routineId == routine.id && $0.endedAt != nil }
}

func elapsedString(ms: Double) -> String {
    let s = Int(ms / 1000)
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

/// Heaviest working set of an item, by weight then reps.
func topSet(_ item: WorkoutItem) -> SetEntry? {
    item.sets.filter { $0.kind == .working && $0.weight != nil && $0.reps != nil }
        .max { a, b in
            if a.weight! != b.weight! { return a.weight! < b.weight! }
            return a.reps! < b.reps!
        }
}

/// Count of sets that went up vs last time in a finished workout.
func setsUp(in workout: Workout, workouts: [Workout], versions: [Version]) -> Int {
    var n = 0
    for item in workout.items {
        guard let last = lastSession(versionId: item.versionId, workouts: workouts, versions: versions, excludeWorkoutId: workout.id, before: workout.date) else { continue }
        for s in item.sets where s.kind == .working {
            if improved(now: s, last: matchLast(now: s, nowAll: item.sets, lastAll: last.item.sets)) { n += 1 }
        }
    }
    return n
}
