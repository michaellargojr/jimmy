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
