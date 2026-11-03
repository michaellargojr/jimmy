import Foundation
import Testing
@testable import Jimmy

// A routine built from exercises already in other routines, the split page's section order,
// copies placed in a split, and split notes.

@Suite struct SplitBuildingTests {
    private let push = Routine(id: "push", name: "Push",
                               items: [RoutineItem(versionId: "bench"), RoutineItem(versionId: "fly", groupId: "g1"),
                                       RoutineItem(versionId: "raise", groupId: "g1"), RoutineItem(versionId: "dip")],
                               groups: [ExerciseGroup(id: "g1", type: .superset)])
    private let pull = Routine(id: "pull", name: "Pull", items: [RoutineItem(versionId: "row", styleId: "wide"), RoutineItem(versionId: "curl")])

    @Test func picksKeepEachRoutinesOrder() {
        let picked = pickedExercises(from: [push, pull], picks: [RoutinePick(routineId: "pull", index: 1),
                                                                 RoutinePick(routineId: "push", index: 3),
                                                                 RoutinePick(routineId: "push", index: 0)])
        #expect(picked.items.map(\.versionId) == ["bench", "dip", "curl"])
        #expect(picked.groups.isEmpty)
    }

    @Test func wholeGroupStaysTogetherUnderAFreshId() {
        let picked = pickedExercises(from: [push], picks: [RoutinePick(routineId: "push", index: 1), RoutinePick(routineId: "push", index: 2)])
        #expect(picked.items.map(\.versionId) == ["fly", "raise"])
        #expect(picked.groups.count == 1)
        #expect(picked.groups.first?.type == .superset)
        #expect(picked.groups.first?.id != "g1")
        #expect(picked.items.allSatisfy { $0.groupId == picked.groups.first?.id })
    }

    @Test func partOfAGroupComesApart() {
        let picked = pickedExercises(from: [push], picks: [RoutinePick(routineId: "push", index: 1)])
        #expect(picked.items.map(\.groupId) == [nil])
        #expect(picked.groups.isEmpty)
    }

    @Test func stylesComeAlongAndNothingPickedIsEmpty() {
        let picked = pickedExercises(from: [push, pull], picks: [RoutinePick(routineId: "pull", index: 0)])
        #expect(picked.items == [RoutineItem(versionId: "row", styleId: "wide")])
        #expect(pickedExercises(from: [push, pull], picks: []).isEmpty)
    }

    @Test func pickedExercisesJoinARoutineAndADraft() {
        let picked = pickedExercises(from: [push], picks: [RoutinePick(routineId: "push", index: 1), RoutinePick(routineId: "push", index: 2)])
        var r = Routine(name: "New", items: [RoutineItem(versionId: "squat")])
        r.add(picked)
        #expect(r.items.map(\.versionId) == ["squat", "fly", "raise"])
        #expect(r.groups == picked.groups)
        var d = RoutineDraft(Routine(name: "New"))
        d.add(picked)
        #expect(d.items == picked.items)
        #expect(d.groups == picked.groups)
        #expect(d.rows.count == 2)
    }

    @Test func routinesThenGoalsAndCoverageThenNotesLast() {
        #expect(splitSections(active: true) == [.inSplit, .goals, .coverage, .notes])
        #expect(splitSections(active: false) == [.inSplit, .goals, .coverage, .use, .notes])
    }

    @Test func aCopyGoesRightAfterItsRoutine() {
        var s = Split(name: "PPL", routineIds: ["push", "pull", "legs"])
        s.add("push2", at: 1)
        #expect(s.routineIds == ["push", "push2", "pull", "legs"])
        s.add("legs2", at: 4)
        #expect(s.routineIds == ["push", "push2", "pull", "legs", "legs2"])
        s.add("extra")
        #expect(s.routineIds.last == "extra")
        s.add("odd", at: 99)
        #expect(s.routineIds.last == "odd")
    }

    @Test func addCopyAtASpotKeepsUndo() {
        let store = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("split-\(uid()).json"))
        store.resetToSeed()
        let a = Routine(name: "A"), b = Routine(name: "B"), copy = Routine(name: "A 2")
        for r in [a, b, copy] { store.put(r) }
        let s = Split(name: "AB", routineIds: [a.id, b.id])
        store.put(s)
        store.addCopy(copy, toSplit: s.id, at: 1)
        #expect(store.splits.first { $0.id == s.id }?.routineIds == [a.id, copy.id, b.id])
        store.undoRoutineChange()
        #expect(store.splits.first { $0.id == s.id }?.routineIds == [a.id, b.id])
    }

    @Test func deletingARoutineSaysWhatHappens() {
        #expect(routineDeleteMessage("Shoulders") == "Shoulders will be gone from your routines and from every split it's in. Workouts you've already done stay in History.")
    }

    @Test func notesRideAlongAndOldSplitsHaveNone() throws {
        var s = Split(name: "PPL")
        s.notes = "Deload every 6th week"
        let back = try JSONDecoder().decode(Split.self, from: JSONEncoder().encode(s))
        #expect(back.notes == "Deload every 6th week")
        let old = try JSONDecoder().decode(Split.self, from: Data(#"{"id":"s","name":"Old","routineIds":[]}"#.utf8))
        #expect(old.notes == nil)
    }
}
