import Foundation

// Derived facts about history, ported from src/derive.ts.

struct LastSession {
    var workout: Workout
    var item: WorkoutItem
    var daysAgo: Int
    var verdict: Verdict
    var version: Version
    /// False when a style was asked for and the last session used a different one.
    var sameStyle: Bool = true
}

private func hasData(_ item: WorkoutItem) -> Bool { item.sets.contains { $0.hasData } }

func sortedNewestFirst(_ ws: [Workout]) -> [Workout] {
    ws.sorted { a, b in
        if a.date != b.date { return a.date > b.date }
        return (a.startedAt ?? 0) > (b.startedAt ?? 0)
    }
}

/// Most recent session of this variation (excluding the given workout). With a style, the
/// last time in that same style wins; otherwise the last time in any style, flagged.
func lastSession(versionId: String, styleId: String? = nil, workouts: [Workout], versions: [Version], excludeWorkoutId: String? = nil, before: String? = nil) -> LastSession? {
    guard let v = versions.first(where: { $0.id == versionId }) else { return nil }
    let ordered = sortedNewestFirst(workouts).filter { w in w.id != excludeWorkoutId && (before == nil || w.date <= before!) }
    func find(_ match: (WorkoutItem) -> Bool) -> LastSession? {
        for w in ordered {
            if let item = w.items.first(where: { $0.versionId == versionId && hasData($0) && match($0) }) {
                return LastSession(workout: w, item: item, daysAgo: daysBetween(w.date, today()), verdict: verdict(item.sets, item.doneRange(v)), version: v)
            }
        }
        return nil
    }
    if let styleId {
        if let same = find({ $0.styleId == styleId }) { return same }
        if var any = find({ _ in true }) { any.sameStyle = false; return any }
        return nil
    }
    return find { _ in true }
}

/// The latest sessions of this variation, newest first, in any style (styles share history).
func recentSessions(versionId: String, workouts: [Workout], versions: [Version], excludeWorkoutId: String? = nil, limit: Int = 3) -> [LastSession] {
    guard let v = versions.first(where: { $0.id == versionId }) else { return [] }
    var out: [LastSession] = []
    for w in sortedNewestFirst(workouts) where w.id != excludeWorkoutId {
        guard let item = w.items.first(where: { $0.versionId == versionId && hasData($0) }) else { continue }
        out.append(LastSession(workout: w, item: item, daysAgo: daysBetween(w.date, today()), verdict: verdict(item.sets, item.doneRange(v)), version: v))
        if out.count == limit { break }
    }
    return out
}

/// The last session of each other variation of the same exercise, most recent first.
func otherVersionsLast(version: Version, workouts: [Workout], versions: [Version], excludeWorkoutId: String? = nil) -> [LastSession] {
    versions.filter { $0.exerciseId == version.exerciseId && $0.id != version.id }
        .compactMap { lastSession(versionId: $0.id, workouts: workouts, versions: versions, excludeWorkoutId: excludeWorkoutId) }
        .sorted { $0.workout.date > $1.workout.date }
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
