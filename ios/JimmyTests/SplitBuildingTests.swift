import Foundation
import Testing
@testable import Jimmy

// A routine built from exercises already in other routines, and the split page's section order.

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

    @Test func coverageWaitsWhileASplitIsPutTogether() {
        #expect(splitSections(creating: true) == [.goals, .inSplit, .newRoutine, .addRoutine, .coverage])
        #expect(splitSections(creating: false) == [.goals, .coverage, .newRoutine, .inSplit, .addRoutine])
    }
}
