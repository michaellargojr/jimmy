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

    @Test func oneArmPairSwapsSidesThenWarmupThenDropLeftFirst() {
        var sets = [S(side: .L), S(side: .R), S(side: .L), S(side: .R)]
        let ids = sets.map(\.id)
        sets = cycleSetKind(sets, at: 0)
        #expect(setLabels(sets) == ["1R", "1L", "2L", "2R"])
        sets = cycleSetKind(sets, at: 1)            // either row of the pair moves both
        #expect(setLabels(sets) == ["WL", "WR", "1L", "1R"])
        sets = cycleSetKind(sets, at: 0)
        #expect(setLabels(sets) == ["DL", "DR", "1L", "1R"])
        sets = cycleSetKind(sets, at: 0)
        #expect(setLabels(sets) == ["1L", "1R", "2L", "2R"])
        #expect(sets.map(\.id) == ids)               // same rows, nothing added or lost
    }

    @Test func loneOneArmRowGetsItsPartnerAsAWarmup() {
        var sets = [S(side: .L), S(side: .R), S(side: .R)]
        sets = cycleSetKind(sets, at: 2)
        #expect(setLabels(sets) == ["1L", "1R", "WL", "WR"])
        #expect(sets.count == 4)
    }

    @Test func oneArmRowsWithoutASideGetPaired() {
        let old = [S(.warmup, reps: 12), S(side: .L), S(side: .R)]
        let sets = pairSides(old)
        #expect(setLabels(sets) == ["WL", "WR", "1L", "1R"])
        #expect(sets[0].id == old[0].id && sets[0].reps == 12)   // the logged row keeps its numbers as L
        #expect(sets[1].reps == nil && sets[1].weight == nil)    // its new R partner starts empty
        #expect(setLabels(cycleSetKind(sets, at: 0)) == ["DL", "DR", "1L", "1R"])
        #expect(pairSides(sets) == sets)                           // already sided: unchanged
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

    @Test func finishDropsOnlyExercisesWithNothingLogged() {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("finish-\(uid()).json"))
        let warm = WorkoutItem(versionId: "a", sets: [S(.warmup, reps: 12), S()])
        let empty = WorkoutItem(versionId: "b", sets: [S(weight: nil), S(weight: nil)])
        let w = Workout(name: "Shoulders", startedAt: nowMs(), items: [warm, empty])
        s.put(w)
        #expect(s.unlogged(w).map(\.id) == [empty.id])   // what the Are you sure? counts
        s.finishWorkout(w.id)
        #expect(s.workout(w.id)?.items.map(\.id) == [warm.id])
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
        #expect(s.armsText(db) == "Two arms - seated")
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

@Suite struct HoldLastTimeTests {
    private let cable = Version(exerciseId: "fr", name: "Front Raise · Cable", equipment: .cable, arms: .two)
    private let db = Version(exerciseId: "fr", name: "Front Raise · Dumbbell · one arm", equipment: .dumbbell, arms: .one)
    private let bar = Version(exerciseId: "fr", name: "Front Raise · Barbell", equipment: .barbell, arms: .two)

    private func w(_ date: String, _ v: Version, logged: Bool = true) -> Workout {
        Workout(name: "Shoulders", date: date, items: [WorkoutItem(versionId: v.id, sets: [S(reps: logged ? 10 : nil)])])
    }

    @Test func lastThreeTimesNewestFirstSkippingToday() {
        let today = w("2026-10-31", cable)
        let ws = [w("2026-10-10", cable), w("2026-10-27", cable), w("2026-10-13", cable), w("2026-10-20", cable), today,
                  w("2026-10-29", cable, logged: false)]
        let r = recentSessions(versionId: cable.id, workouts: ws, versions: [cable], excludeWorkoutId: today.id)
        #expect(r.map(\.workout.date) == ["2026-10-27", "2026-10-20", "2026-10-13"])
    }

    @Test func eachOtherVariationOnceMostRecentFirst() {
        let ws = [w("2026-09-01", bar), w("2026-10-08", db), w("2026-09-20", db), w("2026-10-27", cable)]
        let o = otherVersionsLast(version: cable, workouts: ws, versions: [cable, db, bar])
        #expect(o.map(\.version.id) == [db.id, bar.id])
        #expect(o.first?.workout.date == "2026-10-08")
    }
}
