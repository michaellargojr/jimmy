import Foundation
import Testing
@testable import Jimmy

// The lock screen card: what it says for your set, worked out in the app.

private func S(_ id: String, _ kind: SetKind = .working, side: Side? = nil, weight: Double? = 20, reps: Int? = nil, at: Double? = nil) -> SetEntry {
    SetEntry(id: id, kind: kind, unit: .kg, weight: weight, reps: reps, side: side, loggedAt: at)
}

@Suite struct ActivityStateTests {
    let press = Exercise(name: "Shoulder Press", muscleGroup: .Shoulders)
    let curl = Exercise(name: "Curl", muscleGroup: .Biceps)
    let hammer = Exercise(name: "Hammer Curl", muscleGroup: .Biceps)

    private func store(_ versions: [Version], workouts: [Workout] = []) -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("activity-\(uid()).json"))
        s.exercises = [press, curl, hammer]
        s.versions = versions
        s.workouts = workouts
        return s
    }

    private func dbPress() -> Version {
        Version(id: "press", exerciseId: press.id, name: "x", equipment: .dumbbell, arms: .two, position: .seated)
    }

    /// Last time: a warm-up, then 15×15 and 17.5×8.
    private func lastShoulders() -> Workout {
        Workout(name: "Shoulders", date: "2026-10-31", startedAt: 1, endedAt: 2,
                items: [WorkoutItem(versionId: "press", sets: [S("l0", .warmup, weight: 7.5, reps: 12), S("l1", weight: 15, reps: 15), S("l2", weight: 17.5, reps: 8)])])
    }

    private func today(_ sets: [SetEntry], started: Double? = 1_793_500_000_000) -> Workout {
        Workout(name: "Shoulders", startedAt: started, items: [WorkoutItem(id: "i", versionId: "press", sets: sets)])
    }

    @Test func theFirstSet() throws {
        let w = today([S("w", .warmup), S("a"), S("b")])
        let st = try #require(ActivityState.make(w, store: store([dbPress()], workouts: [lastShoulders(), w])))
        #expect(st.workoutName == "Shoulders")
        #expect(st.exercise == "Dumbbell Shoulder Press")
        #expect(st.tags == ["Two arms", "Seated"])
        #expect(st.setLine == "Warm-up")
        #expect(st.setMark == "W")
        #expect(st.setOf == nil)
        #expect(st.startedAt == Date(timeIntervalSince1970: 1_793_500_000))
        #expect(!st.allDone)
    }

    @Test func afterTwoLoggedItsTheNextSet() throws {
        let w = today([S("w", .warmup, reps: 12, at: 1), S("a", reps: 15, at: 2), S("b")])
        let st = try #require(ActivityState.make(w, store: store([dbPress()], workouts: [lastShoulders(), w])))
        #expect(st.setLine == "Set 2 of 2")
        #expect(st.setMark == "2")
        #expect(st.setOf == "of 2")
    }

    @Test func aGroupMemberSaysWhichItIs() throws {
        let cable = Version(id: "curl", exerciseId: curl.id, name: "x", equipment: .cable, arms: .one, armPosition: .behind)
        let ham = Version(id: "ham", exerciseId: hammer.id, name: "x", equipment: .cable, arms: .two)
        // The first round of the first exercise is logged: the second one's turn.
        let w = Workout(name: "Biceps", startedAt: 1, items: [
            WorkoutItem(id: "a", versionId: "ham", groupId: "g", sets: [S("a1", reps: 8, at: 1), S("a2")]),
            WorkoutItem(id: "b", versionId: "curl", groupId: "g", sets: [S("b1", side: .L), S("b2", side: .R), S("b3", side: .L), S("b4", side: .R)]),
        ])
        let st = try #require(ActivityState.make(w, store: store([cable, ham], workouts: [w])))
        #expect(st.exercise == "Cable Curl")
        #expect(st.groupLabel == "Superset 2")
        #expect(st.side == "Left")
        #expect(st.setLine == "Set 1 of 2 - Left")
        #expect(st.setOf == "of 2")
    }

    @Test func oneArmGoesLeftThenRight() throws {
        let cable = Version(id: "curl", exerciseId: curl.id, name: "x", equipment: .cable, arms: .one)
        let w = Workout(name: "Biceps", startedAt: 1, items: [
            WorkoutItem(id: "b", versionId: "curl", sets: [S("b1", side: .L, reps: 8, at: 1), S("b2", side: .R), S("b3", side: .L), S("b4", side: .R)]),
        ])
        let st = try #require(ActivityState.make(w, store: store([cable], workouts: [w])))
        #expect(st.setLine == "Set 1 of 2 - Right")
        #expect(st.groupLabel == nil)
    }

    @Test func everySetDone() throws {
        let w = today([S("a", reps: 15, at: 1), S("b", reps: 8, at: 2)])
        let st = try #require(ActivityState.make(w, store: store([dbPress()], workouts: [lastShoulders(), w])))
        #expect(st.allDone)
        #expect(st.setLine == "All sets done")
        #expect(st.setMark == nil)
        #expect(st.exercise == "Dumbbell Shoulder Press")
    }

    @Test func noCardBeforeStartOrAfterFinish() {
        var w = today([S("a"), S("b")], started: nil)
        w.pickedAt = 1
        let s = store([dbPress()], workouts: [w])
        #expect(ActivityState.make(w, store: s) == nil)
        w.startedAt = 1
        w.endedAt = 2
        #expect(ActivityState.make(w, store: s) == nil)
    }

    @Test func theAccentFollowsTheColorScheme() throws {
        let w = today([S("a")])
        let s = store([dbPress()], workouts: [w])
        s.settings.scheme = .ice
        #expect(try #require(ActivityState.make(w, store: s)).accent == 0x5EB5FF)
        s.settings.scheme = .crimson
        let st = try #require(ActivityState.make(w, store: s))
        #expect(st.accent == 0xB01425)
        #expect(st.onAccent == 0xFFFFFF)
    }
}
