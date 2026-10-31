import Foundation
import Testing
@testable import Jimmy

// Machines as their own variations: the machine list, Plates or Stack, named machines, the style
// route, any style made its own variation, and the app offering the split.

@Suite struct MachineVariationTests {
    private func store(_ e: [Exercise], _ v: [Version]) -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("machines-\(uid()).json"))
        s.exercises = e
        s.versions = v
        return s
    }

    @Test func theListCoversLibraryBases() {
        for name in machineTypeBases { #expect(libraryBase(named: name) != nil, "\(name)") }
        let pull = machineTypes(forBase: "Pulldown")
        #expect(pull.map(\.name) == ["Lat pulldown", "Iso-lateral pulldown", "High row", "Wide pulldown"])
        #expect(pull[0].tag == nil)
        #expect(pull[1].tag == "iso-lateral")
        #expect(pull[2].tag == "high row")
        #expect(machineTypes(forBase: "calf raise").first?.position == .standing)
        #expect(machineTypes(forBase: "My Own Thing").isEmpty)
        // How each usually comes.
        #expect(pull.map(\.loading) == [.stack, .plates, .plates, .plates])
        #expect(machineTypes(forBase: "Leg Press").first?.loading == .plates)
    }

    @Test func platesAndStackAreSeparateVariations() {
        let pull = Exercise(name: "Pulldown", muscleGroup: .Back)
        let s = store([pull], [])
        var spec = VariationSpec(family: .machine, arms: .two, tag: "high row")
        let plates = s.makeVariation(base: pull, spec: spec)          // a high row usually takes plates
        #expect(plates.loading == .plates)
        spec.loading = .stack
        let stack = s.makeVariation(base: pull, spec: spec)
        #expect(stack.id != plates.id)
        #expect(s.variationChips(plates) == ["Machine", "Plates", "High row", "Two arms"])
        #expect(s.variationTags(stack) == ["Stack", "Two arms"])
        #expect(s.workoutName(plates) == "Machine High Row Pulldown")
        // You have both, so neither can switch onto the other.
        #expect(!s.canSetLoading(plates, .stack))
        s.versions.removeAll { $0.id == stack.id }
        #expect(s.canSetLoading(plates, .stack))
        s.setLoading(plates.id, .stack)
        #expect(s.version(plates.id)?.loading == .stack)
        // Library presets carry it, so they match what you have.
        #expect(libraryBase(named: "Pulldown")?.variations.contains { $0.tag == "high row" && $0.loading == .plates } == true)
        // Not a machine: loading never counts.
        var db = VariationSpec(family: .dumbbell)
        db.loading = .plates
        #expect(db.key == VariationSpec(family: .dumbbell).key)
    }

    @Test func machinesSavedBeforeTakeTheUsualLoading() {
        let row = Exercise(name: "Row", muscleGroup: .Back)
        let tbar = Version(exerciseId: row.id, name: "x", equipment: .machine, arms: .two, tag: "T-bar")
        let seated = Version(exerciseId: row.id, name: "x", equipment: .machine, arms: .two, position: .chestSupported)
        let mine = Version(exerciseId: row.id, name: "x", equipment: .machine, arms: .two, tag: "Gym B")
        let cable = Version(exerciseId: row.id, name: "x", equipment: .cable, arms: .two)
        let s = store([row], [tbar, seated, mine, cable])
        #expect(s.fillMachineLoading())
        #expect(s.versions.map(\.loading) == [.plates, .stack, nil, nil])
        #expect(!s.fillMachineLoading())                              // once
    }

    @Test func aNamedMachineIsItsOwnVariation() {
        let pull = Exercise(name: "Pulldown", muscleGroup: .Back)
        let iso = Version(exerciseId: pull.id, name: "x", equipment: .machine, arms: .one, tag: "iso-lateral", loading: .plates, repMin: 8, repMax: 12)
        let s = store([pull], [iso])
        var spec = VariationSpec(iso)
        spec.machine = machineName("  d Stars ")
        #expect(spec.machine == "D Stars")
        #expect(spec.key != iso.key)

        let v = s.makeVariation(base: pull, spec: spec, like: iso)
        #expect(v.id != iso.id)
        #expect(v.repMin == 8 && v.repMax == 12)
        #expect(v.loading == .plates)
        #expect(s.variationChips(v) == ["Machine", "Plates", "Iso-lateral", "D Stars", "One arm"])
        #expect(s.workoutName(v) == "Machine Iso-lateral Pulldown (D Stars)")
        // The same name again finds it.
        #expect(s.makeVariation(base: pull, spec: spec, like: iso).id == v.id)
        // Both sit under their kind, the plain one first.
        let t = machineTypes(forBase: "Pulldown")[1]
        #expect(s.machines(of: t, baseId: pull.id, arms: .one, position: nil, loading: .plates).map(\.id) == [iso.id, v.id])
        #expect(s.machines(of: t, baseId: pull.id, arms: .one, position: nil, loading: .stack).isEmpty)
        #expect(s.unlistedMachines(base: pull, arms: .one, loading: .plates).isEmpty)
    }

    @Test func machinesNamedBeforeTheListJoinTheirKind() {
        let calf = Exercise(name: "Calf Raise", muscleGroup: .Calves)
        let plain = Version(exerciseId: calf.id, name: "x", equipment: .machine, arms: .two, position: .standing)
        let dStars = Version(exerciseId: calf.id, name: "x", equipment: .machine, arms: .two, position: .standing, tag: "D Stars")
        let other = Version(exerciseId: calf.id, name: "x", equipment: .machine, arms: .one, position: .kneeling, tag: "Gym B")
        let s = store([calf], [plain, dStars, other])
        let before = s.workoutName(dStars)
        #expect(s.fillMachineLoading())
        // D Stars was named in its tag: now it's a second standing calf raise, same title.
        let d = s.version(dStars.id)
        #expect(d?.tag == nil && d?.machine == "D Stars" && d?.loading == .stack)
        if let d { #expect(s.workoutName(d) == before) }
        let standing = machineTypes(forBase: "Calf Raise")[0]
        #expect(s.machines(of: standing, baseId: calf.id, arms: .two, position: nil, loading: .stack).map(\.id) == [plain.id, dStars.id])
        // No kind fits a kneeling calf raise, so that one stays as it was and shows either way.
        #expect(s.version(other.id)?.tag == "Gym B" && s.version(other.id)?.loading == nil)
        #expect(s.unlistedMachines(base: calf, arms: .one, loading: .plates).map(\.id) == [other.id])
        #expect(!s.fillMachineLoading())                              // once
    }

    @Test func aMachineNameTypedOnAStyle() {
        let fly = Exercise(name: "Chest Fly", muscleGroup: .Chest)
        let machine = Version(exerciseId: fly.id, name: "x", equipment: .machine, arms: .two)
        let types = machineTypes(forBase: "Chest Fly")
        // Another kind from the list: its own variation unless you switch.
        #expect(styleNameIsOwnVariation("Pec deck", beside: machine, types: types))
        #expect(namedMachineSpec("pec deck", beside: machine, types: types)?.tag == "pec deck")
        // Any other name stays a style unless you switch; switched, it's this kind under that name.
        #expect(!styleNameIsOwnVariation("D-Stars machine", beside: machine, types: types))
        let own = namedMachineSpec("D-Stars machine", beside: machine, types: types)
        #expect(own?.tag == nil)
        #expect(own?.machine == "D-Stars machine")
        // The kind it already is stays a style.
        #expect(!styleNameIsOwnVariation("Fly machine", beside: machine, types: types))
        // Not a machine: the list never applies.
        let cable = Version(exerciseId: fly.id, name: "x", equipment: .cable, arms: .two)
        #expect(!styleNameIsOwnVariation("Pec deck", beside: cable, types: types))
        #expect(namedMachineSpec("Pec deck", beside: cable, types: types)?.family == .cable)
    }

    @Test func anyStyleCanBecomeItsOwnVariation() {
        let pull = Exercise(name: "Pulldown", muscleGroup: .Back)
        let high = Version(exerciseId: pull.id, name: "x", equipment: .machine, arms: .two, tag: "high row", loading: .plates, repMin: 8, repMax: 12)
        let under = Style(versionId: high.id, grip: "underhand")
        let both = Style(versionId: high.id, grip: "neutral", machine: "D Stars")
        let done = Workout(name: "Back", date: "2026-10-30", startedAt: 1, endedAt: 2, items: [
            WorkoutItem(versionId: high.id, styleId: under.id, sets: [SetEntry(kind: .working, unit: .kg, weight: 60, reps: 10)]),
            WorkoutItem(versionId: high.id, styleId: both.id, sets: [SetEntry(kind: .working, unit: .kg, weight: 40, reps: 10)]),
        ])
        let s = store([pull], [high])
        s.styles = [under, both]
        s.workouts = [done]

        // A grip: this variation under the grip's name.
        guard let nv = s.makeStyleOwnVariation(under.id) else { Issue.record("no variation made"); return }
        #expect(nv.machine == "Underhand" && nv.loading == .plates && nv.repMin == 8)
        #expect(s.variationChips(nv) == ["Machine", "Plates", "High row", "Underhand", "Two arms"])
        #expect(s.workoutName(nv) == "Machine High Row Pulldown (Underhand)")
        #expect(s.workouts[0].items[0].versionId == nv.id && s.workouts[0].items[0].styleId == nil)

        // A machine name with a grip: the machine is the variation, the grip stays its style.
        guard let dv = s.makeStyleOwnVariation(both.id) else { Issue.record("no variation made"); return }
        #expect(dv.machine == "D Stars")
        let rest = s.style(s.workouts[0].items[1].styleId)
        #expect(s.workouts[0].items[1].versionId == dv.id)
        #expect(rest?.versionId == dv.id && rest?.grip == "neutral" && rest?.machine == nil)

        // The New style sheet's choice: a grip starts as a style; it can be its own variation.
        let own = ownVariation(of: StyleSpec(grip: "overhand"), beside: high, types: machineTypes(forBase: "Pulldown"))
        #expect(own?.spec.machine == "Overhand" && own?.rest == StyleSpec())
        #expect(!styleNameIsOwnVariation(nil, beside: high, types: machineTypes(forBase: "Pulldown")))
        #expect(ownVariation(of: StyleSpec(), beside: high, types: []) == nil)
    }

    @Test func helpMeChooseNarrowsTheList() {
        // Every machine with a sibling has answers, and each answer is one its question offers.
        for base in machineTypeBases where machineTypes(forBase: base).count > 1 {
            for t in machineTypes(forBase: base) {
                let traits = machineTraits(base: base, machine: t.name)
                #expect(!traits.isEmpty, "\(base): \(t.name)")
                for (q, a) in traits {
                    #expect(CHOOSE_QUESTIONS.first { $0.id == q }?.answers.contains { $0.id == a } == true, "\(t.name) \(q)=\(a)")
                }
            }
        }
        // Your high row: one question, then how you add weight.
        let pull = machineTypes(forBase: "Pulldown")
        let first = nextChooseQuestion(pull, base: "Pulldown", asked: [])
        #expect(first?.id == "start")
        if let first { #expect(chooseAnswers(first, candidates: pull, base: "Pulldown").map(\.text) == ["Above your head", "High in front of you"]) }
        let high = chooseCandidates(pull, base: "Pulldown", answers: ["start": "high"])
        #expect(high.map(\.name) == ["High row"])
        #expect(nextChooseQuestion(high, base: "Pulldown", asked: ["start"]) == nil)
        // Above your head asks about the arms next; Not sure drops nothing.
        let over = chooseCandidates(pull, base: "Pulldown", answers: ["start": "overhead"])
        #expect(nextChooseQuestion(over, base: "Pulldown", asked: ["start"])?.id == "own")
        #expect(chooseCandidates(pull, base: "Pulldown", answers: ["start": NOT_SURE]).count == 4)

        // Answering as each machine would leaves just that machine, except the squat tie.
        for base in machineTypeBases where machineTypes(forBase: base).count > 1 {
            let all = machineTypes(forBase: base)
            for t in all {
                var answers: [String: String] = [:]
                var left = all
                while let q = nextChooseQuestion(left, base: base, asked: Set(answers.keys)) {
                    answers[q.id] = machineTraits(base: base, machine: t.name)[q.id] ?? NOT_SURE
                    left = chooseCandidates(all, base: base, answers: answers)
                }
                let tie = base == "squat" && (t.name == "Hack squat" || t.name == "V-squat")
                #expect(left.map(\.name) == (tie ? ["Hack squat", "V-squat"] : [t.name]), "\(base): \(t.name)")
            }
        }
    }

    @Test func theAppOffersToSplitAStyleThatRunsHeavier() {
        let pull = Exercise(name: "Pulldown", muscleGroup: .Back)
        let high = Version(exerciseId: pull.id, name: "x", equipment: .machine, arms: .two, tag: "high row", loading: .plates)
        let under = Style(versionId: high.id, grip: "underhand")
        func w(_ date: String, _ st: Style?, _ kg: Double, reps: Int = 10, ended: Bool = true) -> Workout {
            Workout(name: "Back", date: date, startedAt: 1, endedAt: ended ? 2 : nil,
                    items: [WorkoutItem(versionId: high.id, styleId: st?.id, sets: [SetEntry(kind: .working, unit: .kg, weight: kg, reps: reps)])])
        }
        let ws = [w("2026-10-01", nil, 50), w("2026-10-08", nil, 50), w("2026-10-15", under, 60), w("2026-10-22", under, 62)]
        let offers = findSplitOffers(workouts: ws, styles: [under], kept: [])
        #expect(offers.map(\.styleId) == [under.id])
        #expect(offers.first?.heavier == true)
        #expect(offers.first?.styleSet.weight == 62 && offers.first?.restSet.weight == 50)
        // One session in the style isn't enough, close weights aren't either, and a workout still going doesn't count.
        #expect(findSplitOffers(workouts: Array(ws.prefix(3)), styles: [under], kept: []).isEmpty)
        let close = [w("2026-10-01", nil, 50), w("2026-10-08", nil, 50), w("2026-10-15", under, 52), w("2026-10-22", under, 62)]
        #expect(findSplitOffers(workouts: close, styles: [under], kept: []).isEmpty)
        let live = Array(ws.prefix(3)) + [w("2026-10-31", under, 62, ended: false)]
        #expect(findSplitOffers(workouts: live, styles: [under], kept: []).isEmpty)
        // Reps count: 50×15 is about as strong as 60×8, so no offer.
        let reps = [w("2026-10-01", nil, 50, reps: 15), w("2026-10-08", nil, 50, reps: 15), w("2026-10-15", under, 60, reps: 8), w("2026-10-22", under, 60, reps: 8)]
        #expect(findSplitOffers(workouts: reps, styles: [under], kept: []).isEmpty)

        // On the store: Keep as style stops the offer for good.
        let s = store([pull], [high])
        s.styles = [under]
        s.workouts = ws
        #expect(s.splitOffers.map(\.styleId) == [under.id])
        s.keepStyle(under.id)
        #expect(s.splitOffers.isEmpty)
        #expect(s.settings.keptStyles == [under.id])
    }

    @Test func aStyleBecomesItsOwnVariation() {
        let fly = Exercise(name: "Chest Fly", muscleGroup: .Chest)
        let machine = Version(exerciseId: fly.id, name: "x", equipment: .machine, arms: .two, repMin: 10, repMax: 12)
        let pec = Style(versionId: machine.id, machine: "Pec deck")
        let grip = Style(versionId: machine.id, grip: "neutral")
        let done = Workout(name: "Chest", date: "2026-10-01", startedAt: 1, endedAt: 2, items: [
            WorkoutItem(versionId: machine.id, styleId: pec.id, sets: [SetEntry(kind: .working, unit: .kg, weight: 50, reps: 12)]),
            WorkoutItem(versionId: machine.id, styleId: grip.id, sets: [SetEntry(kind: .working, unit: .kg, weight: 40, reps: 10)]),
        ])
        let now = Workout(name: "Chest", startedAt: 3, items: [WorkoutItem(versionId: machine.id, styleId: pec.id, sets: [])])
        let s = store([fly], [machine])
        s.styles = [pec, grip]
        s.workouts = [done, now]
        s.routines = [Routine(name: "Chest", items: [RoutineItem(versionId: machine.id, styleId: pec.id)])]
        #expect(s.styleSessions(pec.id) == 1)

        guard let nv = s.makeStyleOwnVariation(pec.id) else { Issue.record("no variation made"); return }
        #expect(nv.tag == "pec deck")
        #expect(nv.repMin == 10)
        #expect(s.style(pec.id) == nil)
        // Its sessions moved, in progress too; the other style stayed.
        #expect(s.workouts[0].items.map(\.versionId) == [nv.id, machine.id])
        #expect(s.workouts[0].items[0].styleId == nil)
        #expect(s.workouts[0].items[1].styleId == grip.id)
        #expect(s.workouts[1].items[0].versionId == nv.id)
        #expect(s.routines[0].items[0].versionId == nv.id)
    }
}
