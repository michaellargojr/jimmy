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

    @Test func variationsByMuscleMostWorkoutsFirst() {
        let chest = Exercise(id: "chest", name: "Chest Fly", muscleGroup: .Chest)
        let press = Exercise(id: "press", name: "Incline Press", muscleGroup: .Chest)
        let curl = Exercise(id: "curl", name: "Curl", muscleGroup: .Biceps)
        let versions = [
            Version(id: "f1", exerciseId: "chest", name: "Chest Fly · Machine", equipment: .machine, arms: .two),
            Version(id: "f2", exerciseId: "chest", name: "Chest Fly · Cable", equipment: .cable, arms: .two),
            Version(id: "p1", exerciseId: "press", name: "Incline Press · Bar", equipment: .barbell, arms: .two),
            Version(id: "c1", exerciseId: "curl", name: "Curl · Cable", equipment: .cable, arms: .one),
        ]
        let workouts = [finished("2026-10-01", ["f1", "p1"]), finished("2026-10-10", ["p1", "c1"]), finished("2026-10-20", ["f1"])]
        let groups = variationsByMuscle(versions: versions, exercises: [curl, press, chest], workouts: workouts)
        // Chip order (Chest before Biceps); groups with nothing are left out.
        #expect(groups.map(\.muscle) == [.Chest, .Biceps])
        // f1 and p1 both have 2; f1 was done more recently. f2 was never done.
        #expect(groups[0].list.map(\.id) == ["f1", "p1", "f2"])
        #expect(groups[0].list.map(\.note) == ["2 Workouts", "2 Workouts", "Not done yet"])
        #expect(groups[1].list.map(\.note) == ["1 Workout"])
    }
}
