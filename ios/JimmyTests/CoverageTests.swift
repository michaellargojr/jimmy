import Foundation
import Testing
@testable import Jimmy

// Goals on a split and the split-level coverage check (Coverage.swift, CoverageAssistant.swift).

private func ex(_ day: String, _ base: String, _ sets: Int) -> SplitExercise {
    let lb = libraryBase(named: base)!
    return SplitExercise(routineId: day.lowercased(), routineName: day, base: lb.name, variation: "", sets: sets, primary: lb.primary, secondary: lb.secondary)
}

/// Push Pull Legs, each day twice a week.
private let PPL: [SplitExercise] = {
    let push = [("Chest Press", 3), ("Incline Press", 3), ("Shoulder Press", 3), ("Lateral Raise", 3), ("Tricep Pushdown", 3), ("Tricep Extension", 2)]
    let pull = [("Pulldown", 3), ("Row", 3), ("Pull-Up", 2), ("Straight-Arm Pulldown", 2), ("Curl", 3), ("Hammer Curl", 2)]
    let legs = [("Squat", 3), ("Romanian Deadlift", 3), ("Leg Extension", 3), ("Leg Curl", 3), ("Calf Raise", 3), ("Crunch", 3)]
    var out: [SplitExercise] = []
    for _ in 0..<2 {
        out += push.map { ex("Push", $0.0, $0.1) } + pull.map { ex("Pull", $0.0, $0.1) } + legs.map { ex("Legs", $0.0, $0.1) }
    }
    return out
}()

private let PPL_ROUTINES = [Routine(id: "push", name: "Push"), Routine(id: "pull", name: "Pull"), Routine(id: "legs", name: "Legs")]

@Suite struct CoverageVolumeTests {
    @Test func secondaryCountsHalfAndScalesToTheWeek() {
        let v = Dictionary(uniqueKeysWithValues: splitVolume(PPL, cycle: 6, perWeek: 6).map { ($0.region, $0) })
        #expect(v["lats"]?.primary == 20)
        #expect(v["lats"]?.secondary == 0)
        #expect(v["rear delt"]?.primary == 0)
        #expect(v["rear delt"]?.total == 8)
        #expect(v["triceps"]?.rounded == 21)
        #expect(v["side glute"]?.total == 0)
        #expect(v["upper traps"]?.total == 3)
        #expect(v["upper traps"]?.sources.isEmpty == true)
        #expect(v["lats"]?.sources["Pulldown"] == 6)
        #expect(v.count == MUSCLE_REGIONS.count)
    }

    @Test func halfTheDaysMeansHalfTheSets() {
        let full = splitVolume(PPL, cycle: 6, perWeek: 6).first { $0.region == "lats" }!
        let half = splitVolume(PPL, cycle: 6, perWeek: 3).first { $0.region == "lats" }!
        #expect(half.total == full.total / 2)
        #expect(splitVolume([], cycle: 0, perWeek: 6).allSatisfy { $0.total == 0 })
    }

    @Test func levels() {
        let median = trainedMedian(splitVolume(PPL, cycle: 6, perWeek: 6))
        #expect(coverageLevel(MuscleVolume(region: "x", primary: 0, secondary: 0), median: median) == .none)
        #expect(coverageLevel(MuscleVolume(region: "x", primary: 3, secondary: 0), median: median) == .low)
        #expect(coverageLevel(MuscleVolume(region: "x", primary: 12, secondary: 0), median: median) == .fine)
        #expect(coverageLevel(MuscleVolume(region: "x", primary: 21, secondary: 0), median: median) == .heavy)
        #expect(coverageLevel(MuscleVolume(region: "x", primary: 9, secondary: 1), median: 2) == .heavy)
    }
}

@Suite struct GoalTests {
    @Test func tappedGoalsPointAtRegions() {
        let g = goalRegions(SplitGoals(text: "", picks: ["v", "shoulders"]))
        #expect(g["lats"] == "The V look")
        #expect(g["side delt"] == "The V look")
        #expect(g["rear delt"] == "Bigger shoulders")
        #expect(g["quads"] == nil)
    }

    @Test func freeTextFindsGoalsAndMuscles() {
        let g = goalRegions(SplitGoals(text: "I want the V look, wider from the front, and my teres major is lagging", picks: []))
        #expect(g["lats"] == "The V look")
        #expect(g["side delt"] == "The V look")
        #expect(g["upper back"] != nil)
        #expect(goalRegions(SplitGoals()).isEmpty)
    }

    @Test func goalsSurviveTheJSONFile() throws {
        var s = Split(name: "PPL", routineIds: ["a"])
        s.goals = SplitGoals(text: "bigger chest", picks: ["chest"])
        s.coverage = CoverageReport(right: [Finding(text: "ok", mark: .good)], suggestions: [], source: "rules", fingerprint: "f", madeAt: 1)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Split.self, from: data)
        #expect(back.goals?.picks == ["chest"])
        #expect(back.coverage?.right.first?.mark == .good)
        // A web export has neither key.
        let web = try JSONDecoder().decode(Split.self, from: Data(#"{"id":"x","name":"Old","routineIds":[]}"#.utf8))
        #expect(web.goals == nil && web.coverage == nil)
    }
}

@Suite struct RulesReportTests {
    private func report(goals: [String: String]) -> CoverageReport {
        rulesReport(volume: splitVolume(PPL, cycle: 6, perWeek: 6), goals: goals, exercises: PPL, routines: PPL_ROUTINES, fingerprint: "fp")
    }

    @Test func rightThenSuggestions() {
        let r = report(goals: goalRegions(SplitGoals(picks: ["v", "shoulders"])))
        #expect(r.right.first?.text == "Lats get 20 sets a week. Good for the V look.")
        #expect(r.right.count == 2)
        #expect(r.suggestions.count == 4)
        let sideDelt = r.suggestions.first { $0.region == "side delt" }
        #expect(sideDelt?.text == "Side delts get 9 sets to the triceps' 21. Low for the V look.")
        #expect(sideDelt?.mark == .goal)
        #expect(sideDelt?.addBase == "Upright Row")
        #expect(sideDelt?.routineId == "push")
        let rear = r.suggestions.first { $0.region == "rear delt" }
        #expect(rear?.text == "Rear delts only get help from other exercises. Bigger shoulders needs their own exercise.")
        #expect(rear?.addBase == "Rear Delt Row")
        #expect(rear?.routineId == "pull")
        #expect(r.suggestions.allSatisfy { $0.mark != .good })
        #expect(r.suggestions.map(\.region) == ["rear delt", "side delt", nil, "triceps"])
    }

    @Test func noGoalsStillReports() {
        let r = report(goals: [:])
        #expect(r.right.first?.text.hasSuffix("all get ten or more.") == true)
        #expect(r.suggestions.contains { $0.text == "Obliques only get help from other exercises." && $0.addBase == "Side Plank" })
        #expect(r.suggestions.contains { $0.text == "Triceps get 21 sets, the most in the split." })
        #expect(r.suggestions.contains { $0.text == "Side glutes and shins are not trained." && $0.mark == .none })
    }

    @Test func emptySplit() {
        let r = rulesReport(volume: splitVolume([], cycle: 0, perWeek: 0), goals: [:], exercises: [], routines: [], fingerprint: "")
        #expect(r.right.first?.text == "No exercises in this split yet.")
        #expect(r.suggestions.count == 1)
        #expect(r.suggestions.first?.mark == .none)
    }

    @Test func namesReadPlainly() {
        #expect(regionName("side delt").name == "Side delts")
        #expect(regionName("upper back").plural == false)
        #expect(regionName("lats") == ("Lats", true))
    }
}

@Suite struct AssistantParseTests {
    @Test @MainActor func parsesFencedJSON() throws {
        let text = "```json\n{\"right\":[{\"text\":\"Lats are solid.\",\"region\":\"lats\"}],\"suggestions\":[{\"text\":\"Add side delts.\",\"region\":\"side delt\",\"add\":\"Lateral Raise\",\"routine\":\"Pull\"}]}\n```"
        let r = try CoverageAssistant.parse(text)
        #expect(r.right.first?.region == "lats")
        #expect(r.suggestions.first?.add == "Lateral Raise")
        #expect(throws: CoverageAssistant.AssistantError.self) { try CoverageAssistant.parse("no json here") }
    }
}
