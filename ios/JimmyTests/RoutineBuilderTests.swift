import Foundation
import Testing
@testable import Jimmy

// The routine builder: ticks become rows in the order ticked, and your variations by muscle group,
// most workouts first.

private func done() -> SetEntry { SetEntry(kind: .working, unit: .kg, weight: 40, reps: 8) }
private func finished(_ date: String, _ ids: [String]) -> Workout {
    Workout(name: "W", date: date, endedAt: 1, items: ids.map { WorkoutItem(versionId: $0, sets: [done()]) })
}

@Suite struct RoutineBuilderTests {
    private let push = Routine(id: "push", name: "Push",
                               items: [RoutineItem(versionId: "bench"), RoutineItem(versionId: "fly", groupId: "g1"),
                                       RoutineItem(versionId: "raise", groupId: "g1"), RoutineItem(versionId: "dip")],
                               groups: [ExerciseGroup(id: "g1", type: .superset)])
    private let pull = Routine(id: "pull", name: "Pull", items: [RoutineItem(versionId: "row", styleId: "wide"), RoutineItem(versionId: "curl")])
    private func r(_ id: String, _ i: Int) -> BuilderPick { .routine(RoutinePick(routineId: id, index: i)) }

    @Test func rowsComeInTheOrderTicked() {
        let built = builtExercises([r("pull", 1), .variation(versionId: "squat", styleId: "low"), r("push", 0), r("pull", 0)],
                                   routines: [push, pull])
        #expect(built.items == [RoutineItem(versionId: "curl"), RoutineItem(versionId: "squat", styleId: "low"),
                                RoutineItem(versionId: "bench"), RoutineItem(versionId: "row", styleId: "wide")])
        #expect(built.groups.isEmpty)
    }

    @Test func aWholeSupersetStaysTogetherWhereItWasFirstTicked() {
        let built = builtExercises([r("push", 2), r("pull", 1), r("push", 1)], routines: [push, pull])
        #expect(built.items.map(\.versionId) == ["fly", "raise", "curl"])
        #expect(built.groups.count == 1)
        #expect(built.groups.first?.type == .superset)
        #expect(built.groups.first?.id != "g1")
        #expect(built.items[0].groupId == built.groups.first?.id)
        #expect(built.items[1].groupId == built.groups.first?.id)
        #expect(built.items[2].groupId == nil)
    }

    @Test func partOfASupersetComesApart() {
        let built = builtExercises([r("push", 1)], routines: [push])
        #expect(built.items == [RoutineItem(versionId: "fly")])
        #expect(built.groups.isEmpty)
        #expect(builtExercises([], routines: [push]).isEmpty)
    }

    private struct Library {
        let fly = Exercise(id: "fly", name: "Chest Fly", muscleGroup: .Chest)
        let press = Exercise(id: "press", name: "Incline Press", muscleGroup: .Chest)
        let dip = Exercise(id: "dip", name: "Dip", muscleGroup: .Chest, alsoGroups: [.Triceps])
        let curl = Exercise(id: "curl", name: "Curl", muscleGroup: .Biceps)
        var exercises: [Exercise] { [curl, dip, press, fly] }
        let versions = [
            Version(id: "f1", exerciseId: "fly", name: "Chest Fly · Machine", equipment: .machine, arms: .two),
            Version(id: "f2", exerciseId: "fly", name: "Chest Fly · Cable", equipment: .cable, arms: .two),
            Version(id: "f3", exerciseId: "fly", name: "Chest Fly · Dumbbell", equipment: .dumbbell, arms: .two),
            Version(id: "p1", exerciseId: "press", name: "Incline Press · Bar", equipment: .barbell, arms: .two),
            Version(id: "c1", exerciseId: "curl", name: "Curl · Cable", equipment: .cable, arms: .one),
        ]
        // Chest Fly: f1 and f2 in one workout (counts once), f1 again later: 2 workouts.
        // Incline Press: 2 workouts, the latest one earlier than Chest Fly's.
        let workouts = [finished("2026-10-01", ["f1", "f2", "p1"]), finished("2026-10-10", ["p1", "c1"]), finished("2026-10-20", ["f1"])]
        var uses: [BaseUse] { baseUses(exercises: exercises, versions: versions, workouts: workouts) }
    }

    @Test func exercisesMostWorkoutsFirstWithTheirVariations() {
        let uses = Library().uses
        // Dip is in the library only: after everything done.
        #expect(uses.map(\.id) == ["fly", "press", "curl", "dip"])
        let fly = uses[0]
        #expect(fly.workouts == 2)
        #expect(fly.variations.map(\.id) == ["f1", "f2", "f3"])
        #expect(fly.variations.map(\.note) == ["2 Workouts", "1 Workout", "Not done yet"])
        #expect(!uses[3].mine)
    }

    @Test func groupedLikePlanExercises() {
        let uses = Library().uses
        let all = basesByMuscle(uses, mineOnly: false, muscle: nil)
        #expect(all.map(\.muscle) == [.Chest, .Biceps])
        #expect(all[0].bases.map(\.id) == ["fly", "press", "dip"])
        // Mine leaves out exercises with no variations of yours.
        #expect(basesByMuscle(uses, mineOnly: true, muscle: nil)[0].bases.map(\.id) == ["fly", "press"])
        // A muscle chip shows every exercise that works it, Dip under Triceps too.
        #expect(basesByMuscle(uses, mineOnly: false, muscle: .Triceps).map { $0.bases.map(\.id) } == [["dip"]])
    }

    @Test func searchBestMatchThenMostWorkouts() {
        let uses = Library().uses
        #expect(searchBases(uses, query: "incline", muscle: nil).map(\.id) == ["press"])
        // "chest" matches Chest Fly by name first, then the other chest exercises by muscle group.
        #expect(searchBases(uses, query: "chest", muscle: nil).map(\.id) == ["fly", "press", "dip"])
        #expect(searchBases(uses, query: "curl", muscle: .Chest).isEmpty)
    }
}
