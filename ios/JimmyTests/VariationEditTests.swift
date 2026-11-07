import Foundation
import Testing
@testable import Jimmy

// Editing a variation you have, and two with the same blocks told apart by nickname.

@Suite struct VariationEditTests {
    private func store(_ e: [Exercise], _ v: [Version] = []) -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("edit-\(uid()).json"))
        s.exercises = e
        s.versions = v
        return s
    }

    @Test func editKeepsHistoryAndChangesBlocks() {
        let curl = Exercise(name: "Curl", muscleGroup: .Biceps)
        let s = store([curl])
        let v = s.makeVariation(base: curl, spec: VariationSpec(family: .cable, arms: .one))
        s.workouts = [Workout(id: "w", name: "Arms", date: "2026-11-01", items: [WorkoutItem(versionId: v.id, sets: [SetEntry(kind: .working, unit: .kg, weight: 20, reps: 8)])])]

        #expect(s.editVariation(v.id, spec: VariationSpec(family: .cable, arms: .two, position: .standing, armPosition: .behind), nickname: "Bayesian Curl"))
        let after = s.version(v.id)
        #expect(after?.arms == .two && after?.position == .standing && after?.armPosition == .behind)
        #expect(after?.nickname == "Bayesian Curl")
        #expect(s.versions.count == 1)
        #expect(s.workouts[0].items[0].versionId == v.id)
    }

    @Test func editThatCopiesAnotherIsRefused() {
        let curl = Exercise(name: "Curl", muscleGroup: .Biceps)
        let s = store([curl])
        let one = s.makeVariation(base: curl, spec: VariationSpec(family: .dumbbell, arms: .one))
        let two = s.makeVariation(base: curl, spec: VariationSpec(family: .dumbbell, arms: .two))
        #expect(s.variationClash(two.id, spec: VariationSpec(one), nickname: nil)?.id == one.id)
        #expect(!s.editVariation(two.id, spec: VariationSpec(one), nickname: nil))
        #expect(s.version(two.id)?.arms == .two)
        // A nickname of its own sets it apart.
        #expect(s.editVariation(two.id, spec: VariationSpec(one), nickname: "Mine"))
        #expect(s.version(two.id)?.arms == .one)
    }

    @Test func leavingMachinesDropsTheirParts() {
        let pull = Exercise(name: "Pulldown", muscleGroup: .Back)
        let m = Version(exerciseId: pull.id, name: "x", equipment: .machine, arms: .two, tag: "iso-lateral", machine: "D Stars", loading: .plates)
        let s = store([pull], [m])
        #expect(s.editVariation(m.id, spec: VariationSpec(m).with { $0.family = .cable }, nickname: nil))
        let after = s.version(m.id)
        #expect(after?.equipment == .cable && after?.tag == nil && after?.machine == nil && after?.loading == nil)
    }

    @Test func sameBlocksWithAnotherNicknameIsANewVariation() {
        let curl = Exercise(name: "Curl", muscleGroup: .Biceps)
        let s = store([curl])
        let spec = VariationSpec(family: .cable, arms: .one, armPosition: .behind)
        let first = s.makeVariation(base: curl, spec: spec)
        s.setNickname(first.id, "Bayesian Curl")

        // Untyped, the pick is the one you have.
        #expect(s.addVerdict(base: curl, variation: spec, style: StyleSpec()) == .existing(s.version(first.id)!, nil))
        // Its own nickname, any case, still is.
        #expect(s.addVerdict(base: curl, variation: spec, style: StyleSpec(), nickname: .named("bayesian curl")).isExisting)
        // Another nickname makes a new one.
        #expect(s.addVerdict(base: curl, variation: spec, style: StyleSpec(), nickname: .named("Low Cable Curl")) == .newVariation)
        let (second, _) = s.resolve(base: curl, variation: spec, style: StyleSpec(), nickname: .named("Low Cable Curl"))
        #expect(second.id != first.id)
        #expect(second.nickname == "Low Cable Curl")
        #expect(s.version(first.id)?.nickname == "Bayesian Curl")
        // Each is found again by its nickname.
        #expect(s.findVariation(baseId: curl.id, key: spec.key, nickname: .named("Low Cable Curl"))?.id == second.id)
        // And they can't end up sharing one.
        #expect(!s.canUseNickname(second.id, "Bayesian Curl"))
        #expect(s.canUseNickname(second.id, "Cross Curl"))
    }
}

private extension VariationSpec {
    func with(_ change: (inout VariationSpec) -> Void) -> VariationSpec {
        var out = self
        change(&out)
        return out
    }
}
