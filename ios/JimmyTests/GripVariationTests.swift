import Foundation
import Testing
@testable import Jimmy

// Close and wide grip are part of the variation; old grip styles move over with their sets.

@Suite struct GripVariationTests {
    private func store(_ e: [Exercise], _ v: [Version] = []) -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("grip-\(uid()).json"))
        s.exercises = e
        s.versions = v
        return s
    }

    @Test func gripIsItsOwnVariation() {
        let pull = Exercise(name: "Pulldown", muscleGroup: .Back)
        let s = store([pull])
        let plain = s.makeVariation(base: pull, spec: VariationSpec(family: .cable))
        let wide = s.makeVariation(base: pull, spec: VariationSpec(family: .cable, grip: .wide))
        #expect(plain.id != wide.id)
        #expect(s.variationChips(wide) == ["Cable", "Two arms", "Wide grip"])
        #expect(s.variationTags(wide) == ["Two arms", "Wide grip"])
        #expect(VariationSpec("cable close-grip")?.grip == .close)
        #expect(GripWidth(styleGrip: " Wide") == .wide)
        #expect(GripWidth(styleGrip: "underhand") == nil)
    }

    @Test func savesAndLoads() throws {
        let v = Version(exerciseId: "e", name: "x", equipment: .barbell, arms: .two, grip: .close)
        let back = try JSONDecoder().decode(Version.self, from: JSONEncoder().encode(v))
        #expect(back.grip == .close)
        let plain = Version(exerciseId: "e", name: "x", equipment: .barbell, arms: .two)
        #expect(!String(decoding: try JSONEncoder().encode(plain), as: UTF8.self).contains("grip"))
    }

    @Test func gripStylesMoveWithTheirSets() {
        let pull = Exercise(name: "Pulldown", muscleGroup: .Back)
        let v = Version(exerciseId: pull.id, name: "x", equipment: .cable, arms: .two, repMin: 8, repMax: 12)
        let s = store([pull], [v])
        let wideBar = Style(versionId: v.id, attachment: "straight bar", grip: "wide")
        let close = Style(versionId: v.id, grip: "close")
        let under = Style(versionId: v.id, grip: "underhand")
        s.styles = [wideBar, close, under]
        let set = SetEntry(kind: .working, unit: .kg, weight: 50, reps: 10)
        s.workouts = [Workout(id: "w", name: "Back", date: "2026-11-01", items: [
            WorkoutItem(versionId: v.id, styleId: wideBar.id, sets: [set]),
            WorkoutItem(versionId: v.id, styleId: close.id, sets: [set]),
            WorkoutItem(versionId: v.id, styleId: under.id, sets: [set]),
        ])]
        s.routines = [Routine(name: "Back", items: [RoutineItem(versionId: v.id, styleId: wideBar.id)])]

        #expect(s.moveGripStyles())
        let items = s.workouts[0].items
        let wide = s.version(items[0].versionId)
        #expect(wide?.grip == .wide && wide?.id != v.id && wide?.repMin == 8)
        // The bar stays a style on the wide grip variation.
        #expect(s.style(items[0].styleId)?.attachment == "straight bar")
        #expect(s.style(items[0].styleId)?.grip == nil)
        // A grip alone leaves no style.
        #expect(s.version(items[1].versionId)?.grip == .close)
        #expect(items[1].styleId == nil)
        // A palm grip stays a style of the old variation.
        #expect(items[2].versionId == v.id && items[2].styleId == under.id)
        #expect(s.routines[0].items[0].versionId == wide?.id)
        #expect(s.style(wideBar.id) == nil && s.style(close.id) == nil)
        // Only once.
        #expect(!s.moveGripStyles())
    }

    @Test func gripStyleJoinsTheGripVariationYouHave() {
        let row = Exercise(name: "Row", muscleGroup: .Back)
        let s = store([row])
        let v = s.makeVariation(base: row, spec: VariationSpec(family: .cable))
        let close = s.makeVariation(base: row, spec: VariationSpec(family: .cable, grip: .close))
        let st = Style(versionId: v.id, grip: "close")
        s.styles = [st]
        s.workouts = [Workout(id: "w", name: "Back", date: "2026-11-01", items: [
            WorkoutItem(versionId: v.id, styleId: st.id, sets: [SetEntry(kind: .working, unit: .kg, weight: 40, reps: 10)]),
        ])]
        s.moveGripStyles()
        #expect(s.workouts[0].items[0].versionId == close.id)
        #expect(s.versions.count == 2)
    }
}
