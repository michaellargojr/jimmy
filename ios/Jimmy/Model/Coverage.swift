import Foundation

// Goals on a split and the split-level muscle coverage check.
//
// Coverage is always judged on the whole split, never one routine: a muscle missing on
// Push may be trained on Pull. Layer 1 (this file) runs on the phone from the base
// list's primary and secondary muscles and writes plain sentences. Layer 2
// (CoverageAssistant) hands the same numbers plus the goals to Claude for better
// sentences and a suggestion per finding; its answer is cached on the split.

/// What the person wants to look like, in their own words plus tapped suggestions.
struct SplitGoals: Codable, Hashable {
    var text: String = ""
    /// Ids from SUGGESTED_GOALS.
    var picks: [String] = []

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && picks.isEmpty }
}

/// A goal a beginner can tap, and the regions it points at.
struct SuggestedGoal: Identifiable, Hashable {
    let id: String
    let label: String
    let regions: [String]
    /// Words in free text that mean this goal.
    let words: [String]
}

let SUGGESTED_GOALS: [SuggestedGoal] = [
    .init(id: "v", label: "The V look", regions: ["lats", "side delt", "upper back"], words: ["v look", "v-look", "v taper", "v-taper", "v shape", "v-shape", "narrow waist"]),
    .init(id: "wide", label: "Wider frame", regions: ["side delt", "lats", "upper back"], words: ["wider", "width", "wide frame", "broad"]),
    .init(id: "shoulders", label: "Bigger shoulders", regions: ["front delt", "side delt", "rear delt"], words: ["shoulder", "delt", "boulder"]),
    .init(id: "traps", label: "Bigger traps", regions: ["upper traps"], words: ["trap"]),
    .init(id: "chest", label: "Bigger chest", regions: ["upper chest", "middle and lower chest"], words: ["chest", "pec"]),
    .init(id: "abs", label: "Defined abs", regions: ["abs", "obliques"], words: ["abs", "six pack", "six-pack", "core", "midsection", "stomach"]),
    .init(id: "arms", label: "Bigger arms", regions: ["biceps", "triceps", "forearms"], words: ["arm", "bicep", "tricep"]),
    .init(id: "back", label: "Thicker back", regions: ["upper back", "lats", "lower back"], words: ["thick back", "thicker back", "back thickness", "big back", "bigger back"]),
    .init(id: "legs", label: "Bigger legs", regions: ["quads", "hamstrings", "glutes", "calves"], words: ["leg", "quad", "hamstring", "thigh"]),
    .init(id: "glutes", label: "Bigger glutes", regions: ["glutes", "side glute"], words: ["glute", "butt"]),
    .init(id: "calves", label: "Bigger calves", regions: ["calves"], words: ["calf", "calves"]),
    .init(id: "grip", label: "Strong grip", regions: ["forearms"], words: ["grip", "forearm"]),
    .init(id: "posture", label: "Better posture", regions: ["rear delt", "upper back", "lower back", "abs"], words: ["posture", "slouch", "rounded shoulders"]),
    .init(id: "strong", label: "Stronger overall", regions: [], words: ["strong", "strength", "lift more"]),
]

func suggestedGoal(_ id: String) -> SuggestedGoal? { SUGGESTED_GOALS.first { $0.id == id } }

/// Region to the goal label that points at it. Tapped goals first, then words in the text,
/// then region names written out ("teres" counts as upper back).
func goalRegions(_ goals: SplitGoals) -> [String: String] {
    var out: [String: String] = [:]
    for id in goals.picks { if let g = suggestedGoal(id) { for r in g.regions where out[r] == nil { out[r] = g.label } } }
    let text = goals.text.lowercased()
    guard !text.isEmpty else { return out }
    for g in SUGGESTED_GOALS where g.words.contains(where: { text.contains($0) }) {
        for r in g.regions where out[r] == nil { out[r] = g.label }
    }
    for r in MUSCLE_REGIONS where out[r] == nil {
        let words = [r, r.replacingOccurrences(of: " and lower", with: "")] + regionWords[r, default: []]
        if words.contains(where: { text.contains($0) }) { out[r] = "your goals" }
    }
    return out
}

/// Other names people write for a region.
private let regionWords: [String: [String]] = [
    "lats": ["lat ", "lats", "latissimus"], "upper back": ["teres", "rhomboid", "mid back", "middle back"], "upper traps": ["traps"],
    "side delt": ["side delts", "lateral delt", "medial delt"], "rear delt": ["rear delts", "posterior delt"], "front delt": ["front delts", "anterior delt"],
    "middle and lower chest": ["lower chest", "mid chest", "middle chest"], "quads": ["quad"], "hamstrings": ["hamstring", "hammies"],
    "glutes": ["glute"], "side glute": ["glute med", "gluteus medius", "hip abductor"], "calves": ["calf"], "shins": ["shin", "tibialis"],
    "adductors": ["adductor", "inner thigh"], "obliques": ["oblique", "love handle"], "abs": ["abdominal"], "forearms": ["forearm"],
    "lower back": ["erector", "spinal"], "biceps": ["bicep"], "triceps": ["tricep"],
]

// MARK: - Volume

/// Sets a week one region gets. A secondary set counts half.
struct MuscleVolume: Hashable, Identifiable {
    let region: String
    var primary: Double
    var secondary: Double
    /// Bases giving primary sets, with their sets.
    var sources: [String: Double] = [:]
    var id: String { region }
    var total: Double { primary + secondary }
    var rounded: Int { Int(total.rounded()) }
}

enum CoverageLevel { case none, low, fine, heavy }

let COVERAGE_LOW = 6.0
let COVERAGE_GOOD = 10.0
let COVERAGE_HEAVY = 20.0

/// The exercises of a split with the base's muscles resolved, once per routine occurrence.
struct SplitExercise: Hashable {
    let routineId: String
    let routineName: String
    let base: String
    let variation: String
    let sets: Int
    let primary: [String]
    let secondary: [String]
}

func splitExercises(_ split: Split, store: AppStore) -> [SplitExercise] {
    var out: [SplitExercise] = []
    for rid in split.routineIds {
        guard let r = store.routine(rid) else { continue }
        for item in r.items {
            guard let v = store.version(item.versionId), let e = store.base(of: v) else { continue }
            let o = regionOverrides(base: e.name, variation: v)
            out.append(SplitExercise(routineId: r.id, routineName: r.name, base: e.name, variation: store.subtitle(v, styleId: nil),
                                     sets: max(v.defaultSets, 1), primary: o?.primary ?? e.primary, secondary: o?.secondary ?? e.secondary))
        }
    }
    return out
}

/// How many routines get done in a week: from the last four weeks of history when there is
/// enough of it, else one a day up to six.
func workoutsPerWeek(_ split: Split, store: AppStore) -> Double {
    let cut = Calendar.current.date(byAdding: .day, value: -28, to: Date()).map(dayString) ?? "0"
    let recent = store.workouts.filter { $0.isFinished && $0.date >= cut }
    if recent.count >= 8 { return Double(recent.count) / 4 }
    return Double(min(max(split.routineIds.count, 1), 6))
}

/// Sets a week per region, in MUSCLE_REGIONS order.
func splitVolume(_ split: Split, store: AppStore) -> [MuscleVolume] {
    splitVolume(splitExercises(split, store: store), cycle: split.routineIds.count, perWeek: workoutsPerWeek(split, store: store))
}

func splitVolume(_ exercises: [SplitExercise], cycle: Int, perWeek: Double) -> [MuscleVolume] {
    let scale = cycle > 0 ? perWeek / Double(cycle) : 0
    var byRegion: [String: MuscleVolume] = [:]
    for r in MUSCLE_REGIONS { byRegion[r] = MuscleVolume(region: r, primary: 0, secondary: 0) }
    for e in exercises {
        let sets = Double(e.sets) * scale
        for r in e.primary { byRegion[r]?.primary += sets; byRegion[r]?.sources[e.base, default: 0] += sets }
        for r in e.secondary where !e.primary.contains(r) { byRegion[r]?.secondary += sets / 2 }
    }
    return MUSCLE_REGIONS.compactMap { byRegion[$0] }
}

func coverageLevel(_ v: MuscleVolume, median: Double) -> CoverageLevel {
    if v.total <= 0 { return .none }
    if v.total > COVERAGE_HEAVY || (median > 0 && v.total > 3 * median) { return .heavy }
    if v.total < COVERAGE_LOW { return .low }
    return .fine
}

func trainedMedian(_ volume: [MuscleVolume]) -> Double {
    let t = volume.map(\.total).filter { $0 > 0 }.sorted()
    guard !t.isEmpty else { return 0 }
    return t.count % 2 == 1 ? t[t.count / 2] : (t[t.count / 2 - 1] + t[t.count / 2]) / 2
}

// MARK: - Findings

enum FindingMark: String, Codable, Hashable {
    /// Touches one of the goals.
    case goal
    /// Low volume.
    case low
    /// Not trained at all.
    case none
    /// Something the split does right.
    case good
}

struct Finding: Codable, Hashable, Identifiable {
    var text: String
    var mark: FindingMark
    var region: String? = nil
    /// A base from the library that would fix it.
    var addBase: String? = nil
    /// The routine to add it to.
    var routineId: String? = nil
    var id: String { text }
}

struct CoverageReport: Codable, Hashable {
    var right: [Finding]
    var suggestions: [Finding]
    /// "rules" or "claude".
    var source: String
    /// What the report was made from; a different fingerprint means it is stale.
    var fingerprint: String
    var madeAt: Double
}

/// Bump when the rules or the assistant prompt change, so cached reports are redone.
let COVERAGE_RULES_VERSION = 2

/// Changes whenever the goals, any exercise or set count in the split, or the rules version changes.
func coverageFingerprint(_ split: Split, store: AppStore) -> String {
    let ex = splitExercises(split, store: store).map { "\($0.routineId):\($0.base):\($0.variation):\($0.sets)" }.joined(separator: "|")
    let g = split.goals ?? SplitGoals()
    return "r\(COVERAGE_RULES_VERSION)/\(g.picks.sorted().joined(separator: ","))/\(g.text.trimmingCharacters(in: .whitespacesAndNewlines))/\(ex)".hashValueStable
}

private extension String {
    /// A stable hash across launches (hashValue is seeded per process).
    var hashValueStable: String {
        var h: UInt64 = 1469598103934665603
        for b in utf8 { h ^= UInt64(b); h = h &* 1099511628211 }
        return String(h, radix: 36)
    }
}

/// Name as it reads in a sentence, and whether it takes a plural verb.
func regionName(_ r: String) -> (name: String, plural: Bool) {
    switch r {
    case "side delt": return ("Side delts", true)
    case "rear delt": return ("Rear delts", true)
    case "front delt": return ("Front delts", true)
    case "side glute": return ("Side glutes", true)
    case "upper chest", "middle and lower chest", "upper back", "lower back": return (capitalized(r), false)
    default: return (capitalized(r), true)
    }
}

private func verb(_ r: String, _ plural: String, _ singular: String) -> String { regionName(r).plural ? plural : singular }

/// A goal label inside a sentence: "the V look", "bigger shoulders".
private func mid(_ goal: String) -> String { goal.prefix(1).lowercased() + goal.dropFirst() }

private func join(_ names: [String]) -> String {
    switch names.count {
    case 0: return ""
    case 1: return names[0]
    case 2: return "\(names[0]) and \(names[1])"
    default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }
}

/// The on-phone report: what the split does right, then suggestions, from the rules alone.
func rulesReport(split: Split, store: AppStore) -> CoverageReport {
    let exercises = splitExercises(split, store: store)
    let volume = splitVolume(exercises, cycle: split.routineIds.count, perWeek: workoutsPerWeek(split, store: store))
    let goals = goalRegions(split.goals ?? SplitGoals())
    let routines = split.routineIds.compactMap { store.routine($0) }
    return rulesReport(volume: volume, goals: goals, exercises: exercises, routines: routines,
                       fingerprint: coverageFingerprint(split, store: store))
}

func rulesReport(volume: [MuscleVolume], goals: [String: String], exercises: [SplitExercise], routines: [Routine], fingerprint: String) -> CoverageReport {
    let median = trainedMedian(volume)
    let byRegion = Dictionary(uniqueKeysWithValues: volume.map { ($0.region, $0) })
    let heaviest = volume.max { $0.total < $1.total }
    let inSplit = Set(exercises.map(\.base))
    var right: [Finding] = []
    var out: [Finding] = []

    // Doing right: the best goal muscle first, then everything else at ten or more.
    let goodGoal = volume.filter { goals[$0.region] != nil && $0.total >= COVERAGE_GOOD }.sorted { $0.total > $1.total }
    if let g = goodGoal.first {
        let n = regionName(g.region)
        right.append(Finding(text: "\(n.name) \(verb(g.region, "get", "gets")) \(g.rounded) sets a week. Good for \(mid(goals[g.region]!)).", mark: .good, region: g.region))
    }
    let good = volume.filter { $0.total >= COVERAGE_GOOD && $0.region != goodGoal.first?.region }.sorted { $0.total > $1.total }
    if good.count >= 2 {
        right.append(Finding(text: "\(join(good.prefix(4).map { regionName($0.region).name })) all get ten or more.", mark: .good))
    } else if let g = good.first {
        right.append(Finding(text: "\(regionName(g.region).name) \(verb(g.region, "get", "gets")) \(g.rounded) sets a week.", mark: .good, region: g.region))
    } else if right.isEmpty {
        right.append(Finding(text: volume.contains { $0.total > 0 } ? "Nothing is at ten sets a week yet." : "No exercises in this split yet.", mark: .good))
    }

    func fix(_ region: String) -> (String?, String?) {
        let base = LIBRARY.first { $0.primary.contains(region) && !inSplit.contains($0.name) }?.name
            ?? LIBRARY.first { $0.primary.contains(region) }?.name
        // The day that already touches the muscle as a helper, else the day with the fewest exercises.
        let helper = exercises.first { $0.secondary.contains(region) }?.routineId
        let fewest = routines.min { $0.items.count < $1.items.count }?.id
        return (base, helper ?? fewest)
    }

    // Goal muscles that fall short.
    for v in volume where goals[v.region] != nil && v.total < COVERAGE_GOOD {
        let n = regionName(v.region), goal = goals[v.region]!, (base, rid) = fix(v.region)
        let text: String
        if v.total <= 0 {
            text = "\(n.name) \(verb(v.region, "are", "is")) not trained. \(capitalized(goal)) needs \(n.plural ? "them" : "it")."
        } else if v.primary <= 0 {
            text = "\(n.name) only \(verb(v.region, "get", "gets")) help from other exercises. \(capitalized(goal)) needs \(n.plural ? "their" : "its") own exercise."
        } else if let h = heaviest, h.region != v.region, h.total >= 1.5 * v.total {
            let hn = regionName(h.region)
            text = "\(n.name) \(verb(v.region, "get", "gets")) \(v.rounded) sets to the \(hn.name.lowercased())\(hn.plural ? "'" : "'s") \(h.rounded). Low for \(mid(goal))."
        } else {
            text = "\(n.name) \(verb(v.region, "get", "gets")) \(v.rounded) sets a week. Low for \(mid(goal))."
        }
        out.append(Finding(text: text, mark: .goal, region: v.region, addBase: base, routineId: rid))
    }
    out.sort { ($0.region.flatMap { byRegion[$0]?.total } ?? 0) < ($1.region.flatMap { byRegion[$0]?.total } ?? 0) }

    // Untrained, in one line.
    let untrained = volume.filter { goals[$0.region] == nil && $0.total <= 0 }
    if !untrained.isEmpty {
        let names = untrained.map { regionName($0.region).name }
        let one = untrained.count == 1 ? untrained[0] : nil
        let (base, rid) = one.map { fix($0.region) } ?? (nil, nil)
        let text = one.map { "\(names[0]) \(verb($0.region, "are", "is")) not trained." } ?? "\(capitalized(join(names.map { $0.lowercased() }))) are not trained."
        out.append(Finding(text: text, mark: .none, region: one?.region, addBase: base, routineId: rid))
    }

    // The heaviest muscle, when it stands out and is not a goal.
    if let h = heaviest, goals[h.region] == nil, coverageLevel(h, median: median) == .heavy {
        out.append(Finding(text: "\(regionName(h.region).name) \(verb(h.region, "get", "gets")) \(h.rounded) sets, the most in the split.", mark: .low, region: h.region))
    }

    // Help only, then low, for everything else under the low line.
    for v in volume where goals[v.region] == nil && v.total > 0 && v.primary <= 0 && v.total < COVERAGE_LOW {
        let n = regionName(v.region), (base, rid) = fix(v.region)
        out.append(Finding(text: "\(n.name) only \(verb(v.region, "get", "gets")) help from other exercises.", mark: .low, region: v.region, addBase: base, routineId: rid))
    }
    for v in volume where goals[v.region] == nil && v.primary > 0 && v.total < COVERAGE_LOW {
        let n = regionName(v.region), (base, rid) = fix(v.region)
        let from = v.sources.count == 1 ? ", all from \(v.sources.keys.first!)" : ""
        out.append(Finding(text: "\(n.name) \(verb(v.region, "get", "gets")) \(v.rounded) sets a week\(from).", mark: .low, region: v.region, addBase: base, routineId: rid))
    }

    // One button per exercise: a base already offered keeps its sentence but loses the button.
    var offered: Set<String> = []
    for i in out.indices {
        guard let b = out[i].addBase else { continue }
        if offered.contains(b) { out[i].addBase = nil; out[i].routineId = nil } else { offered.insert(b) }
    }

    return CoverageReport(right: Array(right.prefix(2)), suggestions: Array(out.prefix(4)), source: "rules", fingerprint: fingerprint, madeAt: nowMs())
}
