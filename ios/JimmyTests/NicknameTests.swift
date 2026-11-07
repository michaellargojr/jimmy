import Foundation
import Testing
@testable import Jimmy

// Nicknames: a few famous names ("Bayesian Curl") suggested only when every block matches,
// filled once into variations you already have, and yours to type or clear after that.

@Suite struct NicknameTests {
    private func store() -> AppStore {
        AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("nicknames-\(uid()).json"))
    }

    @Test func suggestionsNeedEveryBlockToMatch() {
        // The names on the list.
        #expect(suggestNickname(base: "Curl", family: .cable, position: nil, armPosition: .behind, tag: nil) == "Bayesian Curl")
        #expect(suggestNickname(base: "Curl", family: .cable, position: .standing, armPosition: .behind, tag: nil) == "Bayesian Curl")
        #expect(suggestNickname(base: "Curl", family: .cable, position: .seated, armPosition: .behind, tag: nil) == "Bayesian Curl")
        #expect(suggestNickname(base: "Curl", family: .dumbbell, position: nil, armPosition: .onPad, tag: nil) == "Preacher Curl")
        #expect(suggestNickname(base: "Curl", family: .bar, position: .seated, armPosition: .onPad, tag: nil) == "Preacher Curl")
        #expect(suggestNickname(base: "Curl", family: .dumbbell, position: .standing, armPosition: .onPad, tag: nil) == "Standing Preacher Curl")
        #expect(suggestNickname(base: "Curl", family: .dumbbell, position: .chestSupported, tag: nil) == "Spider Curl")
        #expect(suggestNickname(base: "Tricep Extension", family: .bar, position: .lying, tag: nil) == "Skull Crusher")
        #expect(suggestNickname(base: "Tricep Extension", family: .dumbbell, position: .lying, tag: nil) == "Skull Crusher")
        #expect(suggestNickname(base: "Chest Fly", family: .machine, position: nil, tag: "pec deck") == "Pec Deck")
        #expect(suggestNickname(base: "Chest Fly", family: .machine, position: nil, tag: nil, styleMachines: [" Pec deck "]) == "Pec Deck")

        // Twists the names don't cover get nothing.
        #expect(suggestNickname(base: "Curl", family: .dumbbell, position: nil, armPosition: .behind, tag: nil) == nil)   // an incline curl
        #expect(suggestNickname(base: "Curl", family: .cable, position: .lying, armPosition: .behind, tag: nil) == nil)
        #expect(suggestNickname(base: "Curl", family: .dumbbell, position: .kneeling, armPosition: .onPad, tag: nil) == nil)
        #expect(suggestNickname(base: "Curl", family: .dumbbell, position: .chestSupported, armPosition: .onPad, tag: nil) == nil)
        #expect(suggestNickname(base: "Curl", family: .cable, position: .standing, tag: nil) == nil)
        #expect(suggestNickname(base: "Curl", family: .cable, position: nil, tag: nil) == nil)
        #expect(suggestNickname(base: "Curl", family: .cable, position: nil, armPosition: .behind, tag: "hammer") == nil)
        #expect(suggestNickname(base: "Tricep Extension", family: .cable, position: .lying, tag: nil) == nil)
        #expect(suggestNickname(base: "Tricep Extension", family: .bar, position: .lying, armPosition: .overhead, tag: nil) == nil)
        #expect(suggestNickname(base: "Chest Fly", family: .machine, position: nil, tag: nil) == nil)
        #expect(suggestNickname(base: "Chest Fly", family: .cable, position: nil, tag: "pec deck") == nil)
        #expect(suggestNickname(base: "Hammer Curl", family: .cable, position: nil, armPosition: .behind, tag: nil) == nil)
    }

    @Test func theFieldSavesTrimmedOrNothing() {
        #expect(cleanNickname("  Bayesian Curl ") == "Bayesian Curl")
        #expect(cleanNickname("   ") == nil)
        #expect(cleanNickname(nil) == nil)
    }

    @Test func theStarterDataGetsItsNicknames() {
        let s = store()
        s.resetToSeed()
        #expect(s.settings.nicknamesFilled)
        let named = Dictionary(s.versions.compactMap { v in s.nickname(v).map { (v.name, $0) } }, uniquingKeysWith: { a, _ in a })
        let curl = s.versions.filter { s.baseName($0) == "Curl" }
        #expect(curl.contains { $0.family == .cable && $0.armPosition == .behind && s.nickname($0) == "Bayesian Curl" })
        #expect(curl.contains { $0.family == .dumbbell && $0.position == .chestSupported && s.nickname($0) == "Spider Curl" })
        // Incline dumbbell curl keeps its plain name.
        #expect(curl.filter { $0.family == .dumbbell && $0.armPosition == .behind }.allSatisfy { s.nickname($0) == nil })
        // The pec deck is a style on the chest fly machine, and still names it.
        #expect(s.versions.contains { s.baseName($0) == "Chest Fly" && s.nickname($0) == "Pec Deck" })
        #expect(Set(named.values).isSubset(of: ["Bayesian Curl", "Preacher Curl", "Standing Preacher Curl", "Spider Curl", "Skull Crusher", "Pec Deck"]))
    }

    @Test func fillingRunsOnceAndRespectsWhatYouCleared() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nicknames-\(uid()).json")
        let s = AppStore(fileURL: url)
        let curl = Exercise(name: "Curl", muscleGroup: .Biceps)
        s.exercises = [curl]
        let bayes = s.makeVariation(base: curl, spec: VariationSpec(family: .cable, arms: .one, armPosition: .behind))
        let mine = s.makeVariation(base: curl, spec: VariationSpec(family: .dumbbell, position: .chestSupported))
        s.setNickname(mine.id, "My Spider")
        s.fillNicknames()
        #expect(s.nickname(s.version(bayes.id)!) == "Bayesian Curl")
        #expect(s.nickname(s.version(mine.id)!) == "My Spider")            // a typed one stays

        // Cleared stays cleared, after a save and load too.
        s.setNickname(bayes.id, "  ")
        #expect(s.version(bayes.id)?.nickname == nil)
        s.saveNow()
        let again = AppStore(fileURL: url)
        again.load()
        #expect(again.settings.nicknamesFilled)
        #expect(again.version(bayes.id)?.nickname == nil)
        #expect(again.version(mine.id)?.nickname == "My Spider")
    }

    @Test func olderDataDecodesAndGetsFilledOnLoad() throws {
        let s = store()
        let curl = Exercise(name: "Curl", muscleGroup: .Biceps)
        s.exercises = [curl]
        let v = s.makeVariation(base: curl, spec: VariationSpec(family: .cable, arms: .one, armPosition: .behind))
        // Data from before nicknames: no nickname on the variation, no flag in Settings.
        var json = try JSONSerialization.jsonObject(with: s.snapshot().encoded()) as! [String: Any]
        var versions = json["versions"] as! [[String: Any]]
        versions[0].removeValue(forKey: "nickname")
        json["versions"] = versions
        var settings = json["settings"] as! [String: Any]
        settings.removeValue(forKey: "nicknamesFilled")
        json["settings"] = settings
        let old = try JSONSerialization.data(withJSONObject: json)

        let decoded = try Snapshot.decode(old)
        #expect(decoded.versions.first?.nickname == nil)
        #expect(decoded.settings?.nicknamesFilled == false)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nicknames-old-\(uid()).json")
        try old.write(to: url)
        let loaded = AppStore(fileURL: url)
        loaded.load()
        #expect(loaded.version(v.id)?.nickname == "Bayesian Curl")
        #expect(loaded.settings.nicknamesFilled)
    }

    @Test func backupsCarryNicknames() throws {
        let s = store()
        s.resetToSeed()
        let pec = try #require(s.versions.first { s.nickname($0) == "Pec Deck" })
        s.setNickname(pec.id, "Fly Machine")
        let other = store()
        other.importSnapshot(try Snapshot.decode(s.snapshot().encoded()))
        #expect(other.version(pec.id)?.nickname == "Fly Machine")
    }
}
