import Foundation
import Testing
@testable import Jimmy

// Body position and arm position as two blocks: old data moves over, the two combine into
// their own variations, chips read both, machines and the bench follow.

@Suite struct PositionSplitTests {
    private func store(_ e: [Exercise], _ v: [Version] = []) -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("split-\(uid()).json"))
        s.exercises = e
        s.versions = v
        return s
    }

    private func decode(_ fields: [String: Any]) throws -> Version {
        var json: [String: Any] = ["id": "v", "exerciseId": "e", "name": "x", "equipment": "cable", "arms": "one"]
        for (k, v) in fields { json[k] = v }
        return try JSONDecoder().decode(Version.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test func oldDataMovesToTheArmBlock() throws {
        let bayes = try decode(["position": "arms-behind"])
        #expect(bayes.position == nil && bayes.armPosition == .behind)
        let preacher = try decode(["equipment": "dumbbell", "position": "arm-on-pad"])
        #expect(preacher.position == nil && preacher.armPosition == .onPad)
        let seated = try decode(["position": "seated"])
        #expect(seated.position == .seated && seated.armPosition == nil)
        // "overhead" was a tag; off a machine it is the arm position now.
        let over = try decode(["tag": "overhead"])
        #expect(over.armPosition == .overhead && over.tag == nil)
        let concentration = try decode(["equipment": "dumbbell", "tag": "concentration"])
        #expect(concentration.armPosition == .onThigh && concentration.tag == nil)
        let machine = try decode(["equipment": "machine", "tag": "overhead"])
        #expect(machine.armPosition == nil && machine.tag == "overhead")
        // New data keeps both.
        var both = try decode(["position": "standing"])
        both.armPosition = .onPad
        let again = try JSONDecoder().decode(Version.self, from: JSONEncoder().encode(both))
        #expect(again.position == .standing && again.armPosition == .onPad)
    }

    @Test func bodyAndArmCombineIntoTheirOwnVariations() {
        let curl = Exercise(name: "Curl", muscleGroup: .Biceps)
        let s = store([curl])
        let preacher = s.makeVariation(base: curl, spec: VariationSpec(family: .dumbbell, arms: .one, armPosition: .onPad))
        let standing = s.makeVariation(base: curl, spec: VariationSpec(family: .dumbbell, arms: .one, position: .standing, armPosition: .onPad))
        let plain = s.makeVariation(base: curl, spec: VariationSpec(family: .dumbbell, arms: .one, position: .standing))
        #expect(Set([preacher.id, standing.id, plain.id]).count == 3)
        #expect(s.variationChips(standing) == ["Dumbbell", "One arm", "Standing", "Arm on pad"])
        #expect(s.variationTags(standing) == ["One arm", "Standing", "Arm on pad"])
        #expect(s.armsText(standing) == "One arm - standing - arm on pad")
        #expect(s.variationChips(preacher) == ["Dumbbell", "One arm", "Arm on pad"])
        #expect(curl.hasArmPosition)
        #expect(!Exercise(name: "Squat", muscleGroup: .Legs).hasArmPosition)
    }

    @Test func kindsShowUnderTheirPosition() {
        #expect(Position.allCases.filter { $0.parent == nil } == [.standing, .seated, .kneeling, .lying, .chestSupported, .bentOver])
        #expect(Position.halfKneeling.parent == .kneeling)
        #expect(Position.sideLying.main == .lying && Position.faceDown.main == .lying)
        #expect(Position.faceDown.usesBench && !Position.halfKneeling.usesBench && !Position.bentOver.usesBench)
        // A machine used kneeling or lying takes its kinds too.
        let assisted = machineTypes(forBase: "Pull-Up").first
        #expect(assisted?.allows(.halfKneeling) == true)
        #expect(assisted?.allows(.bentOver) == false)
        #expect(machineTypes(forBase: "Leg Curl").filter { $0.allows(.faceDown) }.map(\.name) == ["Lying leg curl"])
        #expect(VariationSpec("dumbbell arm-on-thigh (concentration)")?.armPosition == .onThigh)
    }

    @Test func overheadStaysInTheTitle() {
        let ext = Exercise(name: "Tricep Extension", muscleGroup: .Triceps)
        let v = Version(exerciseId: ext.id, name: "x", equipment: .cable, arms: .one, armPosition: .overhead)
        let s = store([ext], [v])
        #expect(s.workoutName(v) == "Cable Overhead Tricep Extension")
        #expect(s.variationTags(v) == ["One arm"])
        #expect(s.armsText(v) == "One arm")
        #expect(s.variationChips(v) == ["Cable", "One arm", "Overhead"])
    }

    @Test func machinesAndTheBenchFollowTheArmBlock() {
        let types = machineTypes(forBase: "Curl")
        let preacher = types.first { $0.name == "Preacher curl machine" }
        #expect(preacher?.arm == .onPad)
        #expect(preacher?.allows(.seated) == true)
        #expect(preacher?.allows(.standing) == false)
        #expect(preacher?.allows(nil, arm: .behind) == false)
        #expect(preacher?.allows(nil, arm: .onPad) == true)
        let v = Version(exerciseId: "e", name: "x", equipment: .machine, arms: .two, armPosition: .onPad)
        #expect(preacher?.fits(v) == true)
        let iso = types.first { $0.name == "Iso-lateral curl" }
        #expect(iso?.positions == [.seated] && iso?.arms == [.onPad])
        #expect(usesBench(nil, .behind))
        #expect(!usesBench(nil, .onPad))
        #expect(usesBench(.seated, nil))
    }
}
