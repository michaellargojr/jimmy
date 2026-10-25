import Foundation
import Testing
@testable import Jimmy

// Base > variation > style: parsing, labels, the seed, and style-aware history.

@Suite struct TaxonomyTests {
    @Test func parsesVariationGrammar() {
        let s = VariationSpec("cable one arms-behind (Bayesian)")
        #expect(s?.family == .cable)
        #expect(s?.arms == .one)
        #expect(s?.position == .armsBehind)
        #expect(s?.tag == nil)
        #expect(s?.nick == "Bayesian")
        let t = VariationSpec("machine high row")
        #expect(t?.family == .machine && t?.arms == .two && t?.tag == "high row")
        #expect(VariationSpec("kettlebell swing") == nil)
    }

    @Test func labelsReadPlainly() {
        #expect(variationLabel(family: .cable, arms: .one, position: .standing, tag: nil, legs: false) == "Cable · one arm · standing")
        #expect(variationLabel(family: .body, arms: .two, position: nil, tag: nil, legs: false) == "Body")
        #expect(variationLabel(family: .machine, arms: .one, position: .standing, tag: nil, legs: true) == "Machine · one leg · standing")
        let st = Style(versionId: "v", attachment: "rope", cableHeight: CableHeight.chest.rawValue)
        #expect(st.label == "Rope · Chest height")
        #expect(Style(versionId: "v", barType: .ez).label == "EZ bar")
        #expect(Style(versionId: "v", benchAngle: 45).label == "45°")
        #expect(Style(versionId: "v", benchAngle: 0).label == "Flat")
    }

    @Test func libraryHasSixtyBases() {
        #expect(LIBRARY.count == 60)
        let curl = libraryBase(named: "Curl")
        #expect(curl?.variations.count == 12)
        #expect(curl?.primary == ["biceps"])
        #expect(libraryBase(named: "Dip")?.also == [.Triceps])
        #expect(libraryBase(named: "bench press") == nil)
        #expect(LIBRARY.allSatisfy { !$0.variations.isEmpty })
    }
}

@Suite struct SeedTests {
    @Test func seedMapsLoggedExercisesOntoBases() {
        let s = buildSeed()
        #expect(s.exercises.count == 60)                       // every logged exercise lands on a library base
        #expect(s.exercises.allSatisfy { $0.custom != true })
        let byId = Dictionary(uniqueKeysWithValues: s.exercises.map { ($0.id, $0) })
        let pulldown = s.exercises.first { $0.name == "Pulldown" }!
        let pulldownVars = s.versions.filter { $0.exerciseId == pulldown.id }
        // Two-arm cable, one-arm cable (Extended and One-Arm merged), machine high row.
        #expect(pulldownVars.count == 3)
        let curl = s.exercises.first { $0.name == "Curl" }!
        #expect(s.versions.filter { $0.exerciseId == curl.id }.count == 5)
        #expect(s.versions.allSatisfy { byId[$0.exerciseId] != nil })
        // Styles: barbell curl, Smith calf raise, EZ upright row, rope front raise, cuff extension, pec deck, low pulley fly, barbell incline press.
        #expect(s.styles.count == 8)
        let items = s.workouts.flatMap { $0.items }
        #expect(items.allSatisfy { it in s.versions.contains { $0.id == it.versionId } })
        #expect(items.contains { $0.styleId != nil })
        #expect(s.routines.flatMap { $0.items }.allSatisfy { it in s.versions.contains { $0.id == it.versionId } })
    }

    @Test func oneArmPulldownRowsMerge() {
        let s = buildSeed()
        let pulldown = s.exercises.first { $0.name == "Pulldown" }!
        let oneArm = s.versions.first { $0.exerciseId == pulldown.id && $0.family == .cable && $0.arms == .one }!
        let sessions = s.workouts.filter { w in w.items.contains { $0.versionId == oneArm.id } }
        #expect(sessions.map { $0.date }.sorted() == ["2026-08-20", "2026-09-21"])
    }

    @Test func dStarsKeepsOwnHistory() {
        let s = buildSeed()
        let calf = s.exercises.first { $0.name == "Calf Raise" }!
        let vars = s.versions.filter { $0.exerciseId == calf.id }
        #expect(vars.count == 3)
        #expect(vars.contains { $0.tag == "D Stars" })
    }
}

@Suite struct StyleHistoryTests {
    private func W(_ reps: Int, _ weight: Double) -> SetEntry { SetEntry(kind: .working, unit: .kg, weight: weight, reps: reps) }

    @Test func sameStyleWinsThenFallsBack() {
        let v = Version(exerciseId: "e", name: "Pulldown · Cable · two arms", equipment: .cable, arms: .two)
        let rope = Style(versionId: v.id, attachment: "rope")
        let bar = Style(versionId: v.id, attachment: "straight bar")
        let w1 = Workout(name: "A", date: "2026-10-01", startedAt: 1, endedAt: 2, items: [WorkoutItem(versionId: v.id, styleId: rope.id, sets: [W(10, 40)])])
        let w2 = Workout(name: "B", date: "2026-10-08", startedAt: 1, endedAt: 2, items: [WorkoutItem(versionId: v.id, styleId: bar.id, sets: [W(8, 50)])])
        let ws = [w1, w2]
        let asRope = lastSession(versionId: v.id, styleId: rope.id, workouts: ws, versions: [v])
        #expect(asRope?.workout.id == w1.id && asRope?.sameStyle == true)
        let asBar = lastSession(versionId: v.id, styleId: bar.id, workouts: ws, versions: [v])
        #expect(asBar?.workout.id == w2.id && asBar?.sameStyle == true)
        let other = Style(versionId: v.id, attachment: "V bar")
        let asOther = lastSession(versionId: v.id, styleId: other.id, workouts: ws, versions: [v])
        #expect(asOther?.workout.id == w2.id && asOther?.sameStyle == false)
        #expect(lastSession(versionId: v.id, workouts: ws, versions: [v])?.workout.id == w2.id)
    }
}

@Suite struct MigrationTests {
    @Test func oldExportLandsOnTheLibrary() throws {
        // A version 1 export in the old free-form shape.
        let json = """
        {"version":1,"exportedAt":"","exercises":[{"id":"e1","name":"Lat Pulldown","muscleGroup":"Back"},{"id":"e2","name":"Cable Hammer Curl","muscleGroup":"Biceps"}],
         "versions":[{"id":"v1","exerciseId":"e1","name":"Lat Pulldown (Two-Arm)","equipment":"cable","arms":"two","repMin":5,"repMax":8,"defaultWarmup":true,"defaultSets":2},
                     {"id":"v2","exerciseId":"e1","name":"One-Arm Lat Pulldown","equipment":"cable","arms":"one","repMin":5,"repMax":8,"defaultWarmup":true,"defaultSets":2},
                     {"id":"v3","exerciseId":"e1","name":"Cable Pulldown (Extended)","equipment":"cable","arms":"one","repMin":5,"repMax":8,"defaultWarmup":true,"defaultSets":2},
                     {"id":"v4","exerciseId":"e1","name":"Upright Row","equipment":"ezbar","arms":"two","repMin":5,"repMax":8,"defaultWarmup":true,"defaultSets":2}],
         "workouts":[{"id":"w1","name":"Back","date":"2026-09-21","endedAt":2,"startedAt":1,"items":[{"id":"i1","versionId":"v3","sets":[{"id":"s1","kind":"working","unit":"kg","weight":40,"reps":10,"plus":false}]}],"groups":[]}],
         "routines":[{"id":"r1","name":"Back","items":[{"versionId":"v3"},{"versionId":"v4"}],"groups":[]}],"gyms":[],"ideas":[],"splits":[]}
        """
        let snap = try Snapshot.decode(Data(json.utf8))
        let store = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("migration-test-\(uid()).json"))
        store.importSnapshot(snap)
        #expect(store.versions.count == 3)                                 // v3 merged into v2
        #expect(store.version("v3") == nil)
        #expect(store.workouts[0].items[0].versionId == "v2")
        #expect(store.routines[0].items[0].versionId == "v2")
        let pulldown = try #require(store.base(named: "Pulldown"))
        #expect(store.version("v2")?.exerciseId == pulldown.id)
        #expect(pulldown.primary == ["lats"])
        let upright = try #require(store.version("v4"))
        #expect(upright.family == .bar)
        let ez = try #require(store.style(store.routines[0].items[1].styleId))
        #expect(ez.barType == .ez)
        #expect(store.exercises.count == 60)                                // old flat library replaced
        #expect(store.base(named: "Cable Hammer Curl") == nil)
    }
}

@Suite struct SearchTests {
    private func base(_ name: String) -> Exercise { LIBRARY.first { $0.name == name }!.exercise }

    @Test func muscleGroupFindsTheWholeGroupWithNamesFirst() {
        #expect(searchRank(base("Chest Fly"), "chest") == 0)
        #expect(searchRank(base("Dip"), "chest") == 1)
        #expect(searchRank(base("Push-Up"), "chest") == 1)
        #expect(searchRank(base("Row"), "chest") == 2)          // only via "Chest-Supported Row"
        #expect(searchRank(base("Curl"), "chest") == nil)
        #expect(searchRank(base("Squat"), "quads") == 1)
        #expect(searchRank(base("Lateral Raise"), "delt") == 1)
        #expect(searchRank(base("Chest Press"), "bench press") == 2)
        #expect(searchRank(base("Crunch"), "core") == 1)
    }
}
