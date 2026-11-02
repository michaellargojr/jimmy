import Foundation
import Testing
@testable import Jimmy

// Picking a workout opens it with the clock waiting; Start runs the clock and Done takes its place.

@Suite struct WorkoutStartTests {
    private func store() -> (AppStore, Routine, Routine) {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("start-\(uid()).json"))
        let press = Exercise(name: "Shoulder Press", muscleGroup: .Shoulders)
        let db = Version(exerciseId: press.id, name: "x", equipment: .dumbbell, arms: .two, position: .seated)
        s.exercises = [press]
        s.versions = [db]
        s.workouts = []
        return (s, Routine(name: "Shoulders", items: [RoutineItem(versionId: db.id)]), Routine(name: "Back", items: [RoutineItem(versionId: db.id)]))
    }

    @Test func pickingAWorkoutLeavesTheClockWaiting() {
        let (s, shoulders, _) = store()
        let w = s.startWorkout(from: shoulders)
        #expect(w.startedAt == nil)
        #expect(w.pickedAt != nil)
        #expect(w.isActive && w.isWaiting)
        #expect(s.activeWorkout?.id == w.id)
        #expect(s.startQuickWorkout().startedAt == nil)
    }

    @Test func startRunsTheClockOnce() throws {
        let (s, shoulders, _) = store()
        let w = s.startWorkout(from: shoulders)
        s.startClock(w.id)
        let started = try #require(s.workout(w.id)?.startedAt)
        #expect(s.workout(w.id)?.isWaiting == false)
        #expect(s.workout(w.id)?.isActive == true)
        s.startClock(w.id)   // a second tap changes nothing
        #expect(s.workout(w.id)?.startedAt == started)
    }

    @Test func aWaitingWorkoutGivesWayToTheNextPick() {
        let (s, shoulders, back) = store()
        let first = s.startWorkout(from: shoulders)
        #expect(s.canPickWorkout)
        let second = s.startWorkout(from: back)
        #expect(s.workout(first.id) == nil)
        #expect(s.workouts.filter(\.isActive).map(\.id) == [second.id])
    }

    @Test func oneWithSetsLoggedOrStartedStays() {
        let (s, shoulders, _) = store()
        var w = s.startWorkout(from: shoulders)
        w.items[0].sets[0].weight = 20
        s.put(w)
        #expect(!s.canPickWorkout)

        let (t, back, _) = store()
        let started = t.startWorkout(from: back)
        t.startClock(started.id)
        #expect(!t.canPickWorkout)
    }

    @Test func savedWorkoutsKeepTheirState() throws {
        // Old saves have startedAt and no pickedAt: still running, not waiting.
        let old = try JSONDecoder().decode(Workout.self, from: Data(#"{"id":"w","name":"Back","date":"2026-10-30","startedAt":5,"items":[],"groups":[]}"#.utf8))
        #expect(old.isActive && !old.isWaiting)
        let waiting = Workout(name: "Back", pickedAt: 7)
        let back = try JSONDecoder().decode(Workout.self, from: JSONEncoder().encode(waiting))
        #expect(back.pickedAt == 7 && back.isWaiting)
        #expect(!Workout(name: "Back", startedAt: 1, endedAt: 2, pickedAt: 1).isActive)
    }
}
