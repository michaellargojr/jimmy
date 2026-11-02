import Foundation

// A change to a workout asks whether its routine takes it too (rules in Model/WorkoutRoutineChanges.swift).

extension AppStore {
    /// Called with the workout before and after each change to its exercises. Asks when the
    /// routine would differ; a change made while the question is still up joins it.
    func noteWorkoutChange(from old: WorkoutLineup, to new: WorkoutLineup) {
        guard old.workoutId == new.workoutId, let w = workout(new.workoutId), w.isActive,
              let rid = w.routineId, let r = routine(rid) else { return }
        let pending = routineAsk.flatMap { $0.workoutId == w.id && $0.routineId == rid ? $0 : nil }
        let f = routineFollowing(r, from: pending?.base ?? old, to: new)
        guard f.changed else { if pending != nil { routineAsk = nil }; return }
        let summary = routineFollowSummary(f) { item in
            version(item.versionId).map { workoutName($0) } ?? "Missing exercise"
        }
        if var a = pending {
            a.proposed = f.routine
            a.summary = summary
            routineAsk = a
        } else {
            routineAsk = RoutineAsk(workoutId: w.id, routineId: rid, base: old, proposed: f.routine, summary: summary)
        }
    }

    /// "Update <routine>": the routine takes the change everywhere it is used. Past workouts never change.
    func acceptRoutineAsk() {
        guard let a = routineAsk else { return }
        if routine(a.routineId) != nil { put(a.proposed) }
        routineAsk = nil
    }

    /// "Save as new routine": a new routine with the change takes the old one's spot in its split,
    /// and this workout counts for it. The old routine stays as it was.
    @discardableResult
    func saveRoutineAskAsNew(named name: String) -> Routine? {
        guard let a = routineAsk, let old = routine(a.routineId) else { routineAsk = nil; return nil }
        var r = a.proposed
        r.id = uid()
        r.name = name
        routines.append(r)
        if var s = split(containing: old.id), let i = s.routineIds.firstIndex(of: old.id) {
            s.replace(at: i, with: r.id)
            put(s)
        }
        if var w = workout(a.workoutId) {
            w.routineId = r.id
            w.name = r.name
            put(w)
        }
        markDirty()
        routineAsk = nil
        return r
    }

    /// "Just today", or the question closed: the routine stays as it is.
    func dismissRoutineAsk() { routineAsk = nil }
}
