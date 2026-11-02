import Foundation
import Testing
@testable import Jimmy

// A change to a workout asks whether its routine takes it too: Update, Save as new routine, Just today.

@Suite struct WorkoutRoutineChangesTests {
    private func ri(_ v: String, style: String? = nil, group: String? = nil) -> RoutineItem {
        RoutineItem(versionId: v, styleId: style, groupId: group)
    }
    private func lineup(_ items: [RoutineItem], groups: [ExerciseGroup] = []) -> WorkoutLineup {
        WorkoutLineup(workoutId: "w", items: items, groups: groups)
    }
    private func ids(_ r: Routine) -> [String] { r.items.map(\.versionId) }
    private func summary(_ f: RoutineFollow) -> String { routineFollowSummary(f) { $0.versionId.uppercased() } }

    @Test func swapTakesTheSameSpot() {
        let r = Routine(name: "Shoulders", items: [ri("a"), ri("b"), ri("c")])
        let f = routineFollowing(r, from: lineup([ri("a"), ri("b"), ri("c")]), to: lineup([ri("a"), ri("x"), ri("c")]))
        #expect(f.changed)
        #expect(ids(f.routine) == ["a", "x", "c"])
        #expect(f.routine.id == r.id && f.routine.name == "Shoulders")
        #expect(summary(f) == "Swapped B for X")
    }

    @Test func stylesNeverAsk() {
        let r = Routine(name: "Arms", items: [ri("a", style: "rope"), ri("b")])
        let f = routineFollowing(r, from: lineup([ri("a", style: "rope"), ri("b")]), to: lineup([ri("a", style: "bar"), ri("b")]))
        #expect(!f.changed)
        #expect(f.routine == r)
    }

    @Test func justTodayStaysOutOfALaterUpdate() {
        // B was swapped for X just today; adding D afterwards only adds D to the routine.
        let r = Routine(name: "Shoulders", items: [ri("a"), ri("b"), ri("c")])
        let f = routineFollowing(r, from: lineup([ri("a"), ri("x"), ri("c")]), to: lineup([ri("a"), ri("x"), ri("c"), ri("d")]))
        #expect(ids(f.routine) == ["a", "b", "c", "d"])
        #expect(summary(f) == "Added D")
    }

    @Test func removingSomethingTheRoutineNeverHadAsksNothing() {
        let r = Routine(name: "Shoulders", items: [ri("a"), ri("b")])
        let f = routineFollowing(r, from: lineup([ri("a"), ri("x"), ri("b")]), to: lineup([ri("a"), ri("b")]))
        #expect(!f.changed)
    }

    @Test func addsGoAfterTheExerciseTheyFollow() {
        let r = Routine(name: "Push", items: [ri("a"), ri("b")])
        let first = routineFollowing(r, from: lineup([ri("a"), ri("b")]), to: lineup([ri("x"), ri("a"), ri("b")]))
        #expect(ids(first.routine) == ["x", "a", "b"])
        let middle = routineFollowing(r, from: lineup([ri("a"), ri("b")]), to: lineup([ri("a"), ri("x"), ri("b")]))
        #expect(ids(middle.routine) == ["a", "x", "b"])
    }

    @Test func removeAsks() {
        let r = Routine(name: "Push", items: [ri("a"), ri("b"), ri("c")])
        let f = routineFollowing(r, from: lineup([ri("a"), ri("b"), ri("c")]), to: lineup([ri("a"), ri("c")]))
        #expect(ids(f.routine) == ["a", "c"])
        #expect(summary(f) == "Removed B")
    }

    @Test func newOrderLeavesWhatOnlyTheRoutineHasInPlace() {
        // D was dropped just today; moving B to the top still leaves D last in the routine.
        let r = Routine(name: "Legs", items: [ri("a"), ri("b"), ri("c"), ri("d")])
        let f = routineFollowing(r, from: lineup([ri("a"), ri("b"), ri("c")]), to: lineup([ri("b"), ri("a"), ri("c")]))
        #expect(ids(f.routine) == ["b", "a", "c", "d"])
        #expect(summary(f) == "New order")
    }

    @Test func keptExercisesKeepTheRoutinesStyleAndNewOnesBringTheirs() {
        let r = Routine(name: "Arms", items: [ri("a", style: "rope")])
        let f = routineFollowing(r, from: lineup([ri("a", style: "bar")]), to: lineup([ri("a", style: "bar"), ri("x", style: "cuff")]))
        #expect(f.routine.items == [ri("a", style: "rope"), ri("x", style: "cuff")])
    }

    @Test func supersetsFollow() {
        let g = ExerciseGroup(id: "g", type: .superset)
        let r = Routine(name: "Arms", items: [ri("a"), ri("b"), ri("c")])
        let made = routineFollowing(r, from: lineup([ri("a"), ri("b"), ri("c")]),
                                    to: lineup([ri("a", group: "g"), ri("b", group: "g"), ri("c")], groups: [g]))
        #expect(made.routine.items.map(\.groupId) == ["g", "g", nil])
        #expect(made.routine.groups == [g])
        #expect(summary(made) == "Superset changed")

        // Taking one out of a superset of two leaves the other on its own.
        let grouped = made.routine
        let out = routineFollowing(grouped, from: lineup([ri("a", group: "g"), ri("b", group: "g"), ri("c")], groups: [g]),
                                   to: lineup([ri("b", group: "g"), ri("c")], groups: [g]))
        #expect(ids(out.routine) == ["b", "c"])
        #expect(out.routine.items.map(\.groupId) == [nil, nil])
        #expect(out.routine.groups.isEmpty)
    }

    @Test func aSwapInsideASupersetStaysInIt() {
        let g = ExerciseGroup(id: "g", type: .superset)
        let r = Routine(name: "Arms", items: [ri("a", group: "g"), ri("b", group: "g")], groups: [g])
        let f = routineFollowing(r, from: lineup([ri("a", group: "g"), ri("b", group: "g")], groups: [g]),
                                 to: lineup([ri("x", group: "g"), ri("b", group: "g")], groups: [g]))
        #expect(f.routine.items == [ri("x", group: "g"), ri("b", group: "g")])
        #expect(f.routine.groups == [g])
    }

    // MARK: The store

    private func setUp() -> (AppStore, Routine, Workout) {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("ask-\(uid()).json"))
        let r = Routine(name: "Shoulders", items: [ri("a"), ri("b")])
        s.routines = [r]
        s.splits = [Split(name: "PPL", routineIds: ["push", r.id])]
        let w = Workout(name: "Shoulders", routineId: r.id, pickedAt: nowMs(),
                        items: [WorkoutItem(versionId: "a", sets: []), WorkoutItem(versionId: "b", sets: [])])
        s.put(w)
        return (s, r, w)
    }

    private func swapB(_ s: AppStore, _ w: Workout) -> Workout {
        var n = w
        n.items[1] = WorkoutItem(versionId: "x", sets: [])
        s.put(n)
        s.noteWorkoutChange(from: WorkoutLineup(w), to: WorkoutLineup(n))
        return n
    }

    @Test func updateChangesTheRoutine() {
        let (s, r, w) = setUp()
        _ = swapB(s, w)
        #expect(s.routineAsk != nil)
        s.acceptRoutineAsk()
        #expect(s.routineAsk == nil)
        #expect(s.routine(r.id).map(ids) == ["a", "x"])
    }

    @Test func justTodayLeavesTheRoutine() {
        let (s, r, w) = setUp()
        _ = swapB(s, w)
        s.dismissRoutineAsk()
        #expect(s.routine(r.id) == r)
    }

    @Test func saveAsNewTakesTheSpotAndTheWorkout() {
        let (s, r, w) = setUp()
        _ = swapB(s, w)
        let made = s.saveRoutineAskAsNew(named: "Shoulders B")
        #expect(made != nil)
        #expect(s.routine(r.id) == r)                                   // the old one is untouched
        #expect(s.routines.count == 2)
        #expect(made.map(ids) == ["a", "x"])
        #expect(s.splits[0].routineIds == ["push", made!.id])           // it takes the old spot
        #expect(s.workout(w.id)?.routineId == made!.id)                 // and this workout counts for it
        #expect(s.workout(w.id)?.name == "Shoulders B")
        #expect(s.routineAsk == nil)
    }

    @Test func aWorkoutWithoutARoutineNeverAsks() {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("ask-\(uid()).json"))
        let w = Workout(name: "Quick workout", pickedAt: nowMs(), items: [WorkoutItem(versionId: "a", sets: [])])
        s.put(w)
        var n = w
        n.items.append(WorkoutItem(versionId: "b", sets: []))
        s.noteWorkoutChange(from: WorkoutLineup(w), to: WorkoutLineup(n))
        #expect(s.routineAsk == nil)
    }

    @Test func aFinishedWorkoutNeverAsks() {
        let (s, _, w) = setUp()
        var n = w
        n.endedAt = nowMs()
        n.items.removeLast()
        s.put(n)
        s.noteWorkoutChange(from: WorkoutLineup(w), to: WorkoutLineup(n))
        #expect(s.routineAsk == nil)
    }
}
