import Foundation
import Testing
@testable import Jimmy

// Variations show as one chip: the words that make the variation, with a line between them.

@Suite struct VariationChipTests {
    private func store(_ e: [Exercise], _ v: [Version]) -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("chips-\(uid()).json"))
        s.exercises = e
        s.versions = v
        return s
    }

    @Test func eachWordIsAChip() {
        let press = Exercise(name: "Shoulder Press", muscleGroup: .Shoulders)
        let calf = Exercise(name: "Calf Raise", muscleGroup: .Calves)
        let ext = Exercise(name: "Tricep Extension", muscleGroup: .Triceps)
        let face = Exercise(name: "Face Pull", muscleGroup: .Shoulders)
        let db = Version(exerciseId: press.id, name: "x", equipment: .dumbbell, arms: .two, position: .seated)
        let cable = Version(exerciseId: ext.id, name: "x", equipment: .cable, arms: .one, tag: "overhead")
        let dStars = Version(exerciseId: calf.id, name: "x", equipment: .machine, arms: .two, tag: "D Stars")
        let pull = Version(exerciseId: face.id, name: "x", equipment: .cable, arms: .two)
        let s = store([press, calf, ext, face], [db, cable, dStars, pull])

        // Plan, History and lists: the whole variation.
        #expect(s.variationChips(pull) == ["Cable", "Two arms"])
        #expect(s.variationChips(db) == ["Dumbbell", "Two arms", "Seated"])
        #expect(s.variationChips(cable) == ["Cable", "Overhead", "One arm"])
        #expect(s.variationChips(dStars) == ["Machine", "D Stars"])

        // The Workout card's title already names the equipment, so its chips skip it.
        #expect(s.variationTags(db) == ["Two arms", "Seated"])
        #expect(s.variationTags(cable) == ["One arm"])
        #expect(s.variationTags(dStars) == ["Two legs"])
    }

    @Test func theOneLineLabelIsUnchanged() {
        #expect(variationLabel(family: .cable, arms: .one, position: nil, tag: "overhead", legs: false) == "Cable · overhead · one arm")
        #expect(variationLabel(family: .body, arms: .two, position: nil, tag: nil, legs: false) == "Body")
    }
}
