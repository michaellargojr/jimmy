import Foundation
import Testing
@testable import Jimmy

// History > Exercises: which variations have history, and the Muscle group tree.

private func done(_ weight: Double = 40, _ reps: Int = 8) -> SetEntry { SetEntry(kind: .working, unit: .kg, weight: weight, reps: reps) }
private func empty() -> SetEntry { SetEntry(kind: .working, unit: .kg) }
private func finished(_ date: String, _ items: [WorkoutItem]) -> Workout { Workout(name: "W", date: date, endedAt: 1, items: items) }

private struct Fixture {
    let pulldown = Exercise(name: "Pulldown", muscleGroup: .Back)
    let row = Exercise(name: "Row", muscleGroup: .Back)
    let curl = Exercise(name: "Curl", muscleGroup: .Biceps)
    let squat = Exercise(name: "Squat", muscleGroup: .Legs)
    let dip = Exercise(name: "Dip", muscleGroup: .Chest, alsoGroups: [.Triceps])
    var exercises: [Exercise] { [squat, curl, row, pulldown, dip] }

    var cableOne: Version { Version(id: "p1", exerciseId: pulldown.id, name: "Pulldown · Cable · one arm", equipment: .cable, arms: .one) }
    var cableTwo: Version { Version(id: "p2", exerciseId: pulldown.id, name: "Pulldown · Cable · two arms", equipment: .cable, arms: .two) }
    var rowCable: Version { Version(id: "r1", exerciseId: row.id, name: "Row · Cable", equipment: .cable, arms: .two) }
    var curlDb: Version { Version(id: "c1", exerciseId: curl.id, name: "Curl · Dumbbell", equipment: .dumbbell, arms: .two) }
    var squatBar: Version { Version(id: "s1", exerciseId: squat.id, name: "Squat · Bar", equipment: .barbell, arms: .two) }
    var dipMachine: Version { Version(id: "d1", exerciseId: dip.id, name: "Dip · Machine", equipment: .machine, arms: .two) }
    var versions: [Version] { [cableOne, cableTwo, rowCable, curlDb, squatBar, dipMachine] }

    var workouts: [Workout] {
        [
            finished("2026-08-20", [WorkoutItem(versionId: "p1", sets: [done()]), WorkoutItem(versionId: "r1", sets: [done()])]),
            finished("2026-09-21", [WorkoutItem(versionId: "p1", sets: [done()]), WorkoutItem(versionId: "p2", sets: [done()]),
                                    WorkoutItem(versionId: "p1", sets: [done()])]),   // twice in one workout counts once
            finished("2026-10-15", [WorkoutItem(versionId: "c1", sets: [done()]), WorkoutItem(versionId: "s1", sets: [empty()])]),
            finished("2026-10-01", [WorkoutItem(versionId: "d1", sets: [done()])]),
            Workout(name: "In progress", date: "2026-10-31", items: [WorkoutItem(versionId: "s1", sets: [done()])]),
        ]
    }
}

@Suite struct VariationHistoryTests {
    @Test func countsFinishedLoggedSessionsNewestFirst() {
        let f = Fixture()
        let list = variationHistories(versions: f.versions, workouts: f.workouts)
        #expect(list.map(\.id) == ["c1", "d1", "p1", "p2", "r1"])
        #expect(list.first { $0.id == "p1" }?.sessions == 2)
        #expect(list.first { $0.id == "p1" }?.last == "2026-09-21")
        #expect(list.first { $0.id == "p1" }?.workoutsLabel == "2 Workouts")
        #expect(list.first { $0.id == "p2" }?.workoutsLabel == "1 Workout")
        #expect(list.first { $0.id == "p1" }?.summary == "2 Workouts - Last \(monthDay("2026-09-21"))")
    }

    @Test func leavesOutUnloggedAndUnfinished() {
        // Squat has only an empty set in a finished workout and a logged set in one still going.
        let f = Fixture()
        #expect(!variationHistories(versions: f.versions, workouts: f.workouts).contains { $0.id == "s1" })
    }
}

@Suite struct HistoryByMuscleTests {
    @Test func onlyGroupsWithHistoryInChipOrder() {
        let f = Fixture()
        let tree = historyByMuscle(variationHistories(versions: f.versions, workouts: f.workouts), exercises: f.exercises)
        // Legs has no history; Dip shows once, under its main group.
        #expect(tree.map(\.muscle) == [.Chest, .Back, .Biceps])
        #expect(tree.flatMap(\.bases).filter { $0.exercise.name == "Dip" }.count == 1)
    }

    @Test func basesByNameWithTheirVariations() {
        let f = Fixture()
        let tree = historyByMuscle(variationHistories(versions: f.versions, workouts: f.workouts), exercises: f.exercises)
        let back = tree.first { $0.muscle == .Back }!
        #expect(back.bases.map(\.exercise.name) == ["Pulldown", "Row"])
        let pulldown = back.bases[0]
        #expect(pulldown.variations.map(\.id) == ["p1", "p2"])
        #expect(pulldown.last == "2026-09-21")
    }

    @Test func searchKeepsTheGroups() {
        let f = Fixture()
        let tree = historyByMuscle(variationHistories(versions: f.versions, workouts: f.workouts), exercises: f.exercises) { e, _ in e.name == "Row" }
        #expect(tree.map(\.muscle) == [.Back])
        #expect(tree[0].bases.map(\.exercise.name) == ["Row"])
    }

    @Test func sortLabelsArePlainWords() {
        #expect(HistorySort.allCases.map(\.label) == ["Muscle group", "Most recent"])
    }
}
