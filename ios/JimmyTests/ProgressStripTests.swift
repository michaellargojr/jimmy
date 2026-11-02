import Foundation
import Testing
@testable import Jimmy

// The strip under the Workout top bar: a block fills only when its exercise is done.

private func S(_ weight: Double?, _ reps: Int?, _ kind: SetKind = .working) -> SetEntry {
    SetEntry(kind: kind, unit: .kg, weight: weight, reps: reps)
}

@Suite struct ProgressStripTests {
    let db = Version(exerciseId: "e", name: "", equipment: .dumbbell, arms: .two)
    let body = Version(exerciseId: "e", name: "", equipment: .bodyweight, arms: .two)

    @Test func fillsOnlyWhenEverySetIsChecked() {
        var item = WorkoutItem(versionId: db.id, sets: [S(10, 12, .warmup), S(20, 8), S(20, nil)])
        #expect(!paneFinished([item], versions: [db]))
        item.sets[2].reps = 7
        #expect(paneFinished([item], versions: [db]))
    }
    @Test func addingASetOpensItAgain() {
        var item = WorkoutItem(versionId: db.id, sets: [S(20, 8), S(20, 7)])
        #expect(paneFinished([item], versions: [db]))
        item.sets.append(S(20, nil))
        #expect(!paneFinished([item], versions: [db]))
    }
    @Test func bodyweightNeedsNoWeight() {
        let pull = WorkoutItem(versionId: body.id, sets: [S(nil, 10), S(nil, 8)])
        #expect(paneFinished([pull], versions: [body]))
        #expect(!paneFinished([WorkoutItem(versionId: db.id, sets: [])], versions: [db]))
    }
    @Test func skippingLeavesAGap() {
        let skipped = WorkoutItem(versionId: db.id, sets: [S(20, 8)], skipped: true)
        #expect(!paneFinished([skipped], versions: [db]))
        // In a superset, the exercise you did still fills it.
        let done = WorkoutItem(versionId: db.id, sets: [S(20, 8)])
        #expect(paneFinished([done, skipped], versions: [db]))
    }
    @Test func aSupersetFillsWhenBothAreDone() {
        let a = WorkoutItem(versionId: db.id, sets: [S(20, 8)])
        var b = WorkoutItem(versionId: db.id, sets: [S(15, nil)])
        #expect(!paneFinished([a, b], versions: [db]))
        b.sets[0].reps = 10
        #expect(paneFinished([a, b], versions: [db]))
    }
}

// The big Done at the end of the Workout page shows only once the last set of the last exercise is checked.
@Suite struct EndDoneTests {
    let db = Version(exerciseId: "e", name: "", equipment: .dumbbell, arms: .two)
    let body = Version(exerciseId: "e", name: "", equipment: .bodyweight, arms: .two)

    @Test func showsOnlyOnceTheLastSetIsChecked() {
        var w = Workout(name: "Arms", items: [WorkoutItem(versionId: db.id, sets: [S(20, 8)]),
                                              WorkoutItem(versionId: db.id, sets: [S(20, 8), S(20, nil)])])
        #expect(!lastSetChecked(w, versions: [db]))
        w.items[1].sets[1].reps = 6
        #expect(lastSetChecked(w, versions: [db]))
    }
    @Test func repsWithoutAWeightIsNotChecked() {
        let w = Workout(name: "Arms", items: [WorkoutItem(versionId: db.id, sets: [S(nil, 8)])])
        #expect(!lastSetChecked(w, versions: [db]))
        let pull = Workout(name: "Back", items: [WorkoutItem(versionId: body.id, sets: [S(nil, 8)])])
        #expect(lastSetChecked(pull, versions: [body]))
    }
    @Test func aClosingSupersetEndsOnItsLastRound() {
        // Round by round: A1, B1, A2, B2. B2 is the last set, not A2.
        var w = Workout(name: "Arms", items: [WorkoutItem(versionId: db.id, groupId: "g", sets: [S(20, 8), S(20, 8)]),
                                              WorkoutItem(versionId: db.id, groupId: "g", sets: [S(20, 8), S(20, nil)])])
        #expect(!lastSetChecked(w, versions: [db]))
        w.items[1].sets[1].reps = 8
        #expect(lastSetChecked(w, versions: [db]))
    }
    @Test func aSkippedLastExerciseDoesNotCount() {
        let w = Workout(name: "Arms", items: [WorkoutItem(versionId: db.id, sets: [S(20, 8)]),
                                              WorkoutItem(versionId: db.id, sets: [S(20, nil)], skipped: true)])
        #expect(lastSetChecked(w, versions: [db]))
        #expect(!lastSetChecked(Workout(name: "Empty", items: []), versions: [db]))
    }
}
