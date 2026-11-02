import Foundation
import Testing
@testable import Jimmy

// Your set: where the Workout page lands when it comes back to you.

private func set(_ id: String, reps: Int? = nil, at: Double? = nil, side: Side? = nil) -> SetEntry {
    SetEntry(id: id, kind: .working, unit: .kg, weight: 20, reps: reps, side: side, loggedAt: at)
}

private func item(_ id: String, _ sets: [SetEntry], group: String? = nil, skipped: Bool? = nil) -> WorkoutItem {
    WorkoutItem(id: id, versionId: "v", groupId: group, sets: sets, skipped: skipped)
}

private func workout(_ items: [WorkoutItem]) -> Workout { Workout(name: "Arms", items: items) }

@Suite struct FocusPointTests {
    @Test func beforeAnythingIsLoggedItsTheFirstOpenSet() {
        let w = workout([item("a", [set("a1"), set("a2")]), item("b", [set("b1")])])
        #expect(Focus.point(w) == Focus.Point(itemId: "a", setId: "a1"))
    }

    @Test func theSetAfterTheOneLoggedLast() {
        let w = workout([item("a", [set("a1", reps: 10, at: 1), set("a2", reps: 10, at: 2), set("a3")]), item("b", [set("b1")])])
        #expect(Focus.point(w) == Focus.Point(itemId: "a", setId: "a3"))
    }

    @Test func movesOnToTheNextExerciseAfterTheLastSet() {
        let w = workout([item("a", [set("a1", reps: 10, at: 1), set("a2", reps: 10, at: 2)]), item("b", [set("b1")])])
        #expect(Focus.point(w) == Focus.Point(itemId: "b", setId: "b1"))
    }

    @Test func followsYouWhenYouWorkOutOfOrder() {
        // Machine busy: exercise c was done first. Your set is c's second, not a's first.
        let w = workout([item("a", [set("a1"), set("a2")]), item("b", [set("b1")]), item("c", [set("c1", reps: 8, at: 5), set("c2")])])
        #expect(Focus.point(w) == Focus.Point(itemId: "c", setId: "c2"))
    }

    @Test func wrapsBackToTheFirstOpenSet() {
        // The last exercise is done; what's left is earlier in the workout.
        let w = workout([item("a", [set("a1"), set("a2")]), item("b", [set("b1", reps: 8, at: 5)])])
        #expect(Focus.point(w) == Focus.Point(itemId: "a", setId: "a1"))
    }

    @Test func allLoggedLandsOnTheLastExercise() {
        let w = workout([item("a", [set("a1", reps: 8, at: 1)]), item("b", [set("b1", reps: 8, at: 2)])])
        #expect(Focus.point(w) == Focus.Point(itemId: "b", setId: nil))
    }

    @Test func skippedExercisesDontCount() {
        let w = workout([item("a", [set("a1")], skipped: true), item("b", [set("b1")])])
        #expect(Focus.point(w) == Focus.Point(itemId: "b", setId: "b1"))
    }

    @Test func aSupersetGoesRoundByRound() {
        // A1 logged: next is B1, not A2.
        let w = workout([item("a", [set("a1", reps: 10, at: 1), set("a2")], group: "g"), item("b", [set("b1"), set("b2")], group: "g")])
        #expect(Focus.point(w) == Focus.Point(itemId: "b", setId: "b1"))
        // B1 logged too: back to A2.
        var w2 = w
        w2.items[1].sets[0].reps = 10; w2.items[1].sets[0].loggedAt = 2
        #expect(Focus.point(w2) == Focus.Point(itemId: "a", setId: "a2"))
    }

    @Test func oneArmPairsStayTogetherInASuperset() {
        let a = item("a", [set("a1L", reps: 10, at: 1, side: .L), set("a1R", side: .R), set("a2L", side: .L), set("a2R", side: .R)], group: "g")
        let b = item("b", [set("b1"), set("b2")], group: "g")
        // Left done: the right arm comes before the other exercise.
        #expect(Focus.point(workout([a, b])) == Focus.Point(itemId: "a", setId: "a1R"))
    }

    @Test func emptyWorkoutHasNoPoint() {
        #expect(Focus.point(workout([])) == nil)
    }

    @Test func aFilledSetAfterTheLastOneIsSkippedOver() {
        // a1 was logged last in time, a2 before it: the next open set after a1 is a3.
        let w = workout([item("a", [set("a1", reps: 10, at: 3), set("a2", reps: 10, at: 2), set("a3")])])
        #expect(Focus.point(w) == Focus.Point(itemId: "a", setId: "a3"))
    }
}

@Suite struct FocusStampTests {
    @Test func aSetGettingItsRepsIsStamped() {
        let old = workout([item("a", [set("a1"), set("a2")])])
        var new = old
        new.items[0].sets[0].reps = 10
        Focus.stamp(&new, before: old, now: 500)
        #expect(new.items[0].sets[0].loggedAt == 500)
        #expect(new.items[0].sets[1].loggedAt == nil)
    }

    @Test func aSetKeepsItsStampWhenEditedAndLosesItWhenCleared() {
        let old = workout([item("a", [set("a1", reps: 10, at: 100)])])
        var edited = old
        edited.items[0].sets[0].reps = 12
        Focus.stamp(&edited, before: old, now: 500)
        #expect(edited.items[0].sets[0].loggedAt == 100)
        var cleared = old
        cleared.items[0].sets[0].reps = nil
        Focus.stamp(&cleared, before: old, now: 500)
        #expect(cleared.items[0].sets[0].loggedAt == nil)
    }

    @Test func aBrandNewWorkoutIsNotStamped() {
        // Copied history or a restored backup: nothing was logged just now.
        var w = workout([item("a", [set("a1", reps: 10)])])
        Focus.stamp(&w, before: nil, now: 500)
        #expect(w.items[0].sets[0].loggedAt == nil)
    }

    @Test func theStampSurvivesSaving() throws {
        let s = set("a1", reps: 10, at: 123)
        let back = try JSONDecoder().decode(SetEntry.self, from: try JSONEncoder().encode(s))
        #expect(back.loggedAt == 123)
        // Older files have no stamp.
        let old = try JSONDecoder().decode(SetEntry.self, from: Data(#"{"id":"x","kind":"working","unit":"kg","reps":8}"#.utf8))
        #expect(old.loggedAt == nil)
    }

    @Test func theStoreStampsOnPut() {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("focus-\(uid()).json"))
        s.resetToSeed()
        var w = workout([item("a", [set("a1"), set("a2")])])
        s.put(w)
        w.items[0].sets[0].reps = 10
        s.put(w)
        let saved = s.workout(w.id)!
        #expect(saved.items[0].sets[0].loggedAt != nil)
        #expect(saved.items[0].sets[1].loggedAt == nil)
        #expect(Focus.point(saved) == Focus.Point(itemId: "a", setId: "a2"))
    }
}

@Suite struct ReturnSettingTests {
    @Test func twentySecondsByDefaultAndNeverIsZero() throws {
        #expect(Settings().returnAfter == 20)
        let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"id":"settings"}"#.utf8))
        #expect(old.returnAfter == 20)
        let never = try JSONDecoder().decode(Settings.self, from: Data(#"{"id":"settings","returnAfter":0}"#.utf8))
        #expect(never.returnAfter == 0)
    }

    @Test func pocketModeIsOnUnlessTurnedOff() throws {
        #expect(Settings().pocketMode == true)
        let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"id":"settings"}"#.utf8))
        #expect(old.pocketMode == true)
        let off = try JSONDecoder().decode(Settings.self, from: Data(#"{"id":"settings","pocketMode":false}"#.utf8))
        #expect(off.pocketMode == false)
    }
}
