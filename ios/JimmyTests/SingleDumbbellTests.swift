import Foundation
import Testing
@testable import Jimmy

// One dumbbell held in both hands is its own variation, apart from a pair: it needs other weights.

@Suite struct SingleDumbbellTests {
    private func store(_ e: [Exercise], _ v: [Version] = []) -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("single-\(uid()).json"))
        s.exercises = e
        s.versions = v
        return s
    }

    @Test func pairOneArmAndSingleReadApart() {
        let ext = Exercise(name: "Tricep Extension", muscleGroup: .Triceps)
        let pair = Version(exerciseId: ext.id, name: "x", equipment: .dumbbell, arms: .two, position: .seated)
        let one = Version(exerciseId: ext.id, name: "x", equipment: .dumbbell, arms: .one)
        let single = Version(exerciseId: ext.id, name: "x", equipment: .dumbbell, arms: .two, position: .seated, singleDumbbell: true)
        let s = store([ext], [pair, one, single])

        #expect(s.variationChips(pair) == ["Dumbbells", "Two arms", "Seated"])
        #expect(s.variationChips(one) == ["Dumbbell", "One arm"])
        #expect(s.variationChips(single) == ["Single dumbbell", "Two arms", "Seated"])
        // The Workout title keeps one word; the chips say it's a single dumbbell.
        #expect(s.workoutName(single) == "Dumbbell Tricep Extension")
        #expect(s.variationTags(single) == ["Single dumbbell", "Two arms", "Seated"])
        #expect(s.variationTags(pair) == ["Two arms", "Seated"])
        #expect(pair.key != single.key)
    }

    @Test func legsSayDumbbellsOnOneLeg() {
        let squat = Exercise(name: "Split Squat", muscleGroup: .Legs)
        let oneLeg = Version(exerciseId: squat.id, name: "x", equipment: .dumbbell, arms: .one)
        let s = store([squat], [oneLeg])
        #expect(s.variationChips(oneLeg).first == "Dumbbells")
    }

    @Test func addingASingleMakesItsOwnVariation() {
        let ext = Exercise(name: "Tricep Extension", muscleGroup: .Triceps)
        let s = store([ext])
        let pair = s.makeVariation(base: ext, spec: VariationSpec(family: .dumbbell, position: .seated))
        let single = s.makeVariation(base: ext, spec: VariationSpec(family: .dumbbell, position: .seated, single: true))
        #expect(pair.id != single.id)
        #expect(single.isSingleDumbbell)
        #expect(!pair.isSingleDumbbell)
        #expect(s.findVariation(baseId: ext.id, key: VariationSpec(single).key)?.id == single.id)
        // Off dumbbells the flag means nothing.
        #expect(VariationSpec(family: .cable, single: true).key == VariationSpec(family: .cable).key)
    }

    @Test func savesAndLoads() throws {
        let v = Version(exerciseId: "e", name: "x", equipment: .dumbbell, arms: .two, singleDumbbell: true)
        let back = try JSONDecoder().decode(Version.self, from: JSONEncoder().encode(v))
        #expect(back.isSingleDumbbell)
        let pair = Version(exerciseId: "e", name: "x", equipment: .dumbbell, arms: .two)
        let json = String(decoding: try JSONEncoder().encode(pair), as: UTF8.self)
        #expect(!json.contains("singleDumbbell"))
    }

    @Test func textGrammarReadsSingle() {
        let s = VariationSpec("dumbbell single seated overhead")
        #expect(s?.single == true)
        #expect(s?.position == .seated)
        #expect(s?.armPosition == .overhead)
    }
}
