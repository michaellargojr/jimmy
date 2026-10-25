import Foundation
import Testing
@testable import Jimmy

// The Workout card: set labels and the label tap cycle, when the verdict shows, full names,
// and the per-set rating (Activation or Intensity).

private func S(_ kind: SetKind = .working, side: Side? = nil, weight: Double? = 20, reps: Int? = nil) -> SetEntry {
    SetEntry(kind: kind, unit: .kg, weight: weight, reps: reps, side: side)
}

@Suite struct SetLabelTests {
    @Test func twoArmsCountWorkingSetsOnly() {
        #expect(setLabels([S(.warmup), S(), S(), S(.drop)]) == ["W", "1", "2", "D"])
    }

    @Test func oneArmCountsEachSide() {
        #expect(setLabels([S(.warmup, side: .L), S(.warmup, side: .R), S(side: .L), S(side: .R), S(side: .L), S(side: .R), S(.drop, side: .L)])
                == ["WL", "WR", "1L", "1R", "2L", "2R", "DL"])
        // Started with the right arm.
        #expect(setLabels([S(side: .R), S(side: .L)]) == ["1R", "1L"])
    }

    @Test func oneArmWarmupsComeInPairs() {
        let v = Version(exerciseId: "e", name: "Lateral Raise · Cable · one arm", equipment: .cable, arms: .one, defaultWarmup: true, defaultSets: 2)
        let sets = defaultSets(for: v, unit: .kg, workouts: [])
        #expect(setLabels(sets) == ["WL", "WR", "1L", "1R", "2L", "2R"])
    }
}

@Suite struct CycleSetKindTests {
    @Test func twoArmsGoNumberWarmupDropAndBack() {
        var sets = [S(), S()]
        sets = cycleSetKind(sets, at: 1)
        #expect(setLabels(sets) == ["1", "W"])
        sets = cycleSetKind(sets, at: 1)
        #expect(setLabels(sets) == ["1", "D"])
        sets = cycleSetKind(sets, at: 1)
        #expect(setLabels(sets) == ["1", "2"])
    }

    @Test func oneArmPairSwapsSidesThenWarmupThenDrop() {
        var sets = [S(side: .L), S(side: .R), S(side: .L), S(side: .R)]
        let ids = sets.map(\.id)
        sets = cycleSetKind(sets, at: 0)
        #expect(setLabels(sets) == ["1R", "1L", "2L", "2R"])
        sets = cycleSetKind(sets, at: 1)            // either row of the pair moves both
        #expect(setLabels(sets) == ["WR", "WL", "1L", "1R"])
        sets = cycleSetKind(sets, at: 0)
        #expect(setLabels(sets) == ["DR", "DL", "1L", "1R"])
        sets = cycleSetKind(sets, at: 0)
        #expect(setLabels(sets) == ["1L", "1R", "2L", "2R"])
        #expect(sets.map(\.id) == ids)               // same rows, nothing added or lost
    }

    @Test func loneOneArmRowGetsItsPartnerAsAWarmup() {
        var sets = [S(side: .L), S(side: .R), S(side: .R)]
        sets = cycleSetKind(sets, at: 2)
        #expect(setLabels(sets) == ["1L", "1R", "WR", "WL"])
        #expect(sets.count == 4)
    }

    @Test func outOfRangeChangesNothing() {
        let sets = [S()]
        #expect(cycleSetKind(sets, at: 5) == sets)
    }
}

@Suite struct CompletionTests {
    @Test func blankAddedSetHidesTheVerdict() {
        let done = [S(.warmup, reps: 15), S(reps: 10), S(reps: 8)]
        #expect(setsComplete(done, bodyweight: false))
        #expect(!setsComplete(done + [S(weight: nil)], bodyweight: false))
        #expect(!setsComplete(done + [S(reps: nil)], bodyweight: false))
        #expect(!setsComplete([], bodyweight: false))
    }

    @Test func bodyweightNeedsOnlyReps() {
        let sets = [S(weight: nil, reps: 12), S(weight: nil, reps: 10)]
        #expect(setsComplete(sets, bodyweight: true))
        #expect(!setsComplete(sets, bodyweight: false))
    }

    @Test func dropSetsDoNotChangeTheVerdict() {
        let sets = [S(reps: 10), S(reps: 7)]
        #expect(verdict(sets, repMin: 5, repMax: 8) == .up)
        #expect(verdict(sets + [S(.drop, weight: 10, reps: 3)], repMin: 5, repMax: 8) == .up)
    }

    @Test func dropSetsCountAsDoneWorkButWarmupsDoNot() {
        #expect(S(.drop, reps: 6).isDone)
        #expect(!S(.warmup, reps: 15).isDone)
    }
}

@Suite struct WorkoutNameTests {
    private func store(_ e: [Exercise], _ v: [Version]) -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("names-\(uid()).json"))
        s.exercises = e
        s.versions = v
        return s
    }

    @Test func fullNamesReadLikeTheExercise() {
        let press = Exercise(name: "Shoulder Press", muscleGroup: .Shoulders)
        let calf = Exercise(name: "Calf Raise", muscleGroup: .Calves)
        let ext = Exercise(name: "Tricep Extension", muscleGroup: .Triceps)
        let db = Version(exerciseId: press.id, name: "x", equipment: .dumbbell, arms: .two, position: .seated)
        let bar = Version(exerciseId: press.id, name: "x", equipment: .smith, arms: .two)
        let cable = Version(exerciseId: ext.id, name: "x", equipment: .cable, arms: .one, tag: "overhead")
        let dStars = Version(exerciseId: calf.id, name: "x", equipment: .machine, arms: .two, tag: "D Stars")
        let s = store([press, calf, ext], [db, bar, cable, dStars])
        #expect(s.workoutName(db) == "Dumbbell Shoulder Press")
        #expect(s.workoutName(bar) == "Barbell Shoulder Press")
        #expect(s.workoutName(cable) == "Cable Overhead Tricep Extension")
        #expect(s.workoutName(dStars) == "Machine Calf Raise (D Stars)")
        #expect(s.armsText(db) == "Two arms · seated")
        #expect(s.armsText(cable) == "One arm")
        #expect(s.armsText(dStars) == "Two legs")
    }
}

@Suite struct RatingTests {
    @Test func decodesWhenPresentAndOldSetsStillLoad() throws {
        let new = #"{"id":"a","kind":"drop","unit":"kg","weight":20,"reps":8,"activation":2,"intensity":3}"#
        let old = #"{"id":"b","kind":"working","unit":"kg","weight":20,"reps":8}"#
        let a = try JSONDecoder().decode(SetEntry.self, from: Data(new.utf8))
        let b = try JSONDecoder().decode(SetEntry.self, from: Data(old.utf8))
        #expect(a.activation == 2 && a.intensity == 3 && a.kind == .drop)
        #expect(b.activation == nil && b.intensity == nil && b.kind == .working)
        let round = try JSONDecoder().decode(SetEntry.self, from: JSONEncoder().encode(a))
        #expect(round == a)
    }

    @Test func eachRatingKeepsItsOwnValue() {
        var s = SetEntry(kind: .working, unit: .kg)
        s.setRating(.activation, 3)
        s.setRating(.intensity, 1)
        #expect(s.rating(.activation) == 3 && s.rating(.intensity) == 1)
        s.setRating(.activation, nil)
        #expect(s.activation == nil && s.intensity == 1)
    }

    @Test func activationIsTheDefaultRating() throws {
        #expect(Settings().rating == .activation)
        let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"unit":"kg"}"#.utf8))
        #expect(old.rating == .activation)
        #expect(SetRating.activation.words == ["Barely felt", "Felt", "Really felt"])
        #expect(SetRating.intensity.words == ["Easy", "Effort", "Max"])
    }

    @Test func valueTextLeavesOutSideAndBar() {
        var s = SetEntry(kind: .working, unit: .kg, weight: 12.5, reps: 10, plus: true, partials: 3, side: .L, bar: .ez)
        #expect(s.valueText == "12.5×10+ (3p)")
        s.weight = nil
        #expect(s.valueText == "10+ (3p)")
    }
}
