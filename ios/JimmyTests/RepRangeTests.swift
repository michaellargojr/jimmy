import Foundation
import Testing
@testable import Jimmy

// Rep range templates (RepRanges.swift): groups, which pick wins, and what history keeps.

private func V(_ equipment: Equipment = .dumbbell, lo: Int = 5, hi: Int = 8, tag: String? = nil) -> Version {
    Version(exerciseId: "e", name: "", equipment: equipment, arms: .two, tag: tag, repMin: lo, repMax: hi)
}

private func S(_ reps: Int, _ weight: Double = 30) -> SetEntry { SetEntry(kind: .working, unit: .kg, weight: weight, reps: reps) }

@Suite struct RepGroupTests {
    @Test func barPressesAndSquatsAreHeavy() {
        #expect(exerciseRepGroup(base: "Chest Press", family: .bar, tag: nil) == .heavy)
        #expect(exerciseRepGroup(base: "Squat", family: .bar, tag: nil) == .heavy)
        #expect(exerciseRepGroup(base: "Squat", family: .machine, tag: "hack") == .heavy)
        #expect(exerciseRepGroup(base: "Squat", family: .machine, tag: "Pendulum") == .heavy)
    }
    @Test func dumbbellAndMachinePressesAreGeneral() {
        #expect(exerciseRepGroup(base: "Chest Press", family: .dumbbell, tag: nil) == .general)
        #expect(exerciseRepGroup(base: "Shoulder Press", family: .machine, tag: nil) == .general)
        #expect(exerciseRepGroup(base: "Squat", family: .dumbbell, tag: "goblet") == .general)
        #expect(exerciseRepGroup(base: "Curl", family: .bar, tag: nil) == .general)
    }
    @Test func hingesHoldsAndSmallMuscles() {
        #expect(exerciseRepGroup(base: "Romanian Deadlift", family: .dumbbell, tag: nil) == .hinge)
        #expect(exerciseRepGroup(base: "Plank", family: .body, tag: nil) == .hold)
        #expect(exerciseRepGroup(base: "Lateral Raise", family: .cable, tag: nil) == .small)
        #expect(exerciseRepGroup(base: "Leg Curl", family: .machine, tag: nil) == .small)
        #expect(exerciseRepGroup(base: "Leg Curl", family: .body, tag: "nordic") == .general)
        #expect(exerciseRepGroup(base: "Shrug", family: .bar, tag: nil) == .heavy)
        #expect(exerciseRepGroup(base: "Shrug", family: .dumbbell, tag: nil) == .small)
    }
    @Test func theTableFromTheResearch() {
        #expect(RepGroup.hinge.range(.high) == RepRange(10, 12))
        #expect(RepGroup.heavy.range(.high) == RepRange(12, 15))
        #expect(RepGroup.general.range(.mid) == RepRange(8, 12))
        #expect(RepGroup.general.range(.high) == RepRange(15, 20))
        #expect(RepGroup.small.range(.lower) == RepRange(10, 15))
        #expect(RepGroup.small.range(.high) == RepRange(20, 30))
        for g in RepGroup.allCases { #expect(g.range(.standard) == nil) }
        for t in RepTemplate.allCases { #expect(RepGroup.hold.range(t) == nil) }
    }
}

@Suite struct RepPrecedenceTests {
    let v = V(lo: 6, hi: 10)

    @Test func defaultIsTheVariationsOwn() {
        let item = WorkoutItem(versionId: v.id, sets: [])
        let w = Workout(name: "Push", items: [item])
        #expect(effectiveRepRange(item: item, workout: w, version: v, group: .general) == RepRange(6, 10))
        #expect(pickedRepTemplate(item: item, workout: w) == .standard)
    }
    @Test func workoutTemplateAppliesThenExerciseBeatsIt() {
        var item = WorkoutItem(versionId: v.id, sets: [])
        let w = Workout(name: "Push", items: [item], repTemplate: .high)
        #expect(effectiveRepRange(item: item, workout: w, version: v, group: .general) == RepRange(15, 20))
        item = settingRepTemplate(.lower, on: item)
        #expect(effectiveRepRange(item: item, workout: w, version: v, group: .general) == RepRange(5, 8))
        item = settingRepTemplate(.standard, on: item)
        #expect(effectiveRepRange(item: item, workout: w, version: v, group: .general) == RepRange(6, 10))
        item = settingRepRange(RepRange(12, 15), on: item)
        #expect(effectiveRepRange(item: item, workout: w, version: v, group: .general) == RepRange(12, 15))
        #expect(pickedRepTemplate(item: item, workout: w) == nil)
    }
    @Test func pickingForTheWorkoutStartsEveryExerciseOver() {
        let a = settingRepRange(RepRange(3, 5), on: WorkoutItem(versionId: v.id, sets: []))
        let b = settingRepTemplate(.lower, on: WorkoutItem(versionId: v.id, sets: []))
        let w = settingRepTemplate(.mid, on: Workout(name: "Push", items: [a, b]))
        #expect(w.repTemplate == .mid)
        for i in w.items {
            #expect(i.repTemplate == nil && i.repMin == nil && i.repMax == nil)
            #expect(effectiveRepRange(item: i, workout: w, version: v, group: .general) == RepRange(8, 12))
        }
        #expect(settingRepTemplate(.standard, on: w).repTemplate == nil)
    }
    @Test func holdsKeepTheirOwnRange() {
        let hold = V(.bodyweight, lo: 30, hi: 60)
        let item = WorkoutItem(versionId: hold.id, sets: [])
        let w = Workout(name: "Abs", items: [item], repTemplate: .high)
        #expect(effectiveRepRange(item: item, workout: w, version: hold, group: .hold) == RepRange(30, 60))
    }
}

@Suite struct RepHistoryTests {
    @Test func finishKeepsTheRangeItWasDoneAt() {
        let v = V(lo: 5, hi: 8)
        let item = WorkoutItem(versionId: v.id, sets: [S(18), S(17)])
        let w = freezingRepRanges(Workout(name: "Push", items: [item], repTemplate: .high), versions: [v]) { _ in .general }
        #expect(w.items[0].savedRepRange == RepRange(15, 20))
        // Changing the variation's own range later does not rewrite the past.
        var later = v; later.repMin = 3; later.repMax = 5
        #expect(w.items[0].doneRange(later) == RepRange(15, 20))
        #expect(verdict(w.items[0].sets, w.items[0].doneRange(later)) == .none)
    }
    @Test func oldWorkoutsFallBackToTheVariation() {
        let v = V(lo: 5, hi: 8)
        let item = WorkoutItem(versionId: v.id, sets: [S(10), S(8)])
        #expect(item.savedRepRange == nil)
        #expect(verdict(item.sets, item.doneRange(v)) == .up)
    }
    @Test func verdictFollowsTodaysRange() {
        let sets = [S(17), S(14)]
        #expect(verdict(sets, RepRange(5, 8)) == .up)
        #expect(verdict(sets, RepRange(15, 20)) == .none)
        #expect(verdict([S(12)], RepRange(15, 20)) == .down)
    }
    @Test func rangeReadsLowToHigh() {
        #expect(RepRange(12, 8) == RepRange(8, 12))
        #expect(RepRange(8, 12).text == "8-12")
    }
}

@Suite struct RepDecodeTests {
    @Test func olderDataDecodesWithNoTemplates() throws {
        let s = try JSONDecoder().decode(Settings.self, from: Data(#"{"id":"settings"}"#.utf8))
        #expect(s.repTemplate == .standard)
        let w = try JSONDecoder().decode(Workout.self, from: Data(#"{"id":"w","name":"Push","date":"2026-10-30","items":[{"id":"i","versionId":"v","sets":[]}],"groups":[]}"#.utf8))
        #expect(w.repTemplate == nil)
        #expect(w.items[0].repTemplate == nil && w.items[0].savedRepRange == nil)
    }
    @Test func roundTrips() throws {
        var item = settingRepTemplate(.high, on: WorkoutItem(versionId: "v", sets: []))
        item.repMin = nil
        let w = Workout(name: "Push", items: [item], repTemplate: .lower)
        let back = try JSONDecoder().decode(Workout.self, from: JSONEncoder().encode(w))
        #expect(back.repTemplate == .lower)
        #expect(back.items[0].repTemplate == .high)
        var s = Settings(); s.repTemplate = .mid
        #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s)).repTemplate == .mid)
        #expect(try JSONDecoder().decode(RepTemplate.self, from: Data(#""default""#.utf8)) == .standard)
    }
}
