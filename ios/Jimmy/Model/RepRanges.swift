import Foundation

// Rep range templates (Michael, Oct 31 2026). Default is each variation's own range; Lower,
// Mid and High come from the exercise's group. Studies show similar growth from about 5 to
// 30 reps near failure; the per-group numbers follow Renaissance Periodization's muscle guides.
// Research and sources: https://claude.ai/artifact/1DS27CeE7GdFdLZknQqg9Z

enum RepTemplate: String, Codable, CaseIterable, Identifiable {
    case standard = "default", lower, mid, high
    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: return "Default"
        case .lower: return "Lower"
        case .mid: return "Mid"
        case .high: return "High"
        }
    }
}

struct RepRange: Codable, Hashable {
    var lo: Int
    var hi: Int
    init(_ lo: Int, _ hi: Int) { self.lo = Swift.min(lo, hi); self.hi = Swift.max(lo, hi) }
    /// "5-8", the way the Workout screen writes it.
    var text: String { "\(lo)-\(hi)" }
}

/// The number presets under the templates.
let REP_PRESETS: [RepRange] = [RepRange(3, 5), RepRange(5, 8), RepRange(6, 10), RepRange(8, 12), RepRange(10, 15), RepRange(12, 15), RepRange(15, 20)]

/// How an exercise takes the templates. Holds have no reps, so the templates leave them alone.
enum RepGroup: String, CaseIterable {
    case hinge, heavy, general, small, hold

    /// Lower, Mid and High for this group; nil keeps the variation's own range.
    func range(_ t: RepTemplate) -> RepRange? {
        switch (self, t) {
        case (_, .standard), (.hold, _): return nil
        case (.hinge, .lower): return RepRange(5, 8)
        case (.hinge, .mid): return RepRange(8, 10)
        case (.hinge, .high): return RepRange(10, 12)
        case (.heavy, .lower), (.general, .lower): return RepRange(5, 8)
        case (.heavy, .mid), (.general, .mid): return RepRange(8, 12)
        case (.heavy, .high): return RepRange(12, 15)
        case (.general, .high): return RepRange(15, 20)
        case (.small, .lower): return RepRange(10, 15)
        case (.small, .mid): return RepRange(15, 20)
        case (.small, .high): return RepRange(20, 30)
        }
    }
}

private let HOLD_BASES: Set<String> = ["Plank", "Side Plank", "Dead Hang", "Farmer Carry", "Plate Pinch"]
private let HINGE_BASES: Set<String> = ["Deadlift", "Romanian Deadlift", "Good Morning"]
/// Heavy only with a bar (barbell, EZ or Smith); the dumbbell and machine kinds are "general".
private let BAR_HEAVY_BASES: Set<String> = ["Chest Press", "Incline Press", "Shoulder Press", "Row", "Close-Grip Press", "Upright Row", "Shrug"]
private let SMALL_BASES: Set<String> = [
    "Lateral Raise", "Front Raise", "Rear Delt Fly", "Face Pull", "Y Raise", "External Rotation",
    "Chest Fly", "Incline Fly", "Tricep Pushdown", "Tricep Kickback", "Leg Extension", "Leg Curl",
    "Calf Raise", "Tibialis Raise", "Wrist Curl", "Reverse Wrist Curl", "Wrist Roller", "Shrug",
    "Crunch", "Sit-Up", "Leg Raise", "Reverse Crunch", "Woodchop", "Side Bend",
    "Hip Abduction", "Hip Adduction", "Glute Kickback",
]

/// The group for a variation, from its base name, equipment and tag ("hack", "pendulum").
func exerciseRepGroup(base: String, family: EquipmentFamily, tag: String?) -> RepGroup {
    let t = tag?.lowercased() ?? ""
    if HOLD_BASES.contains(base) { return .hold }
    if HINGE_BASES.contains(base) { return .hinge }
    if base == "Squat" && (family == .bar || t.contains("hack") || t.contains("pendulum")) { return .heavy }
    if family == .bar && BAR_HEAVY_BASES.contains(base) { return .heavy }
    if base == "Leg Curl" && family == .body { return .general } // Nordic curls never reach 20-30
    if SMALL_BASES.contains(base) { return .small }
    return .general
}

/// A template's numbers for one variation.
func templateRange(_ t: RepTemplate, version v: Version, group: RepGroup) -> RepRange {
    group.range(t) ?? RepRange(v.repMin, v.repMax)
}

/// The range one exercise works to in a workout. Numbers picked on the card win, then the
/// exercise's template, then the workout's, then the variation's own range.
func effectiveRepRange(item: WorkoutItem, workout: Workout, version v: Version, group: RepGroup) -> RepRange {
    if let lo = item.repMin, let hi = item.repMax { return RepRange(lo, hi) }
    return templateRange(item.repTemplate ?? workout.repTemplate ?? .standard, version: v, group: group)
}

/// The template the card's menu ticks; nil when the exercise is on its own numbers.
func pickedRepTemplate(item: WorkoutItem, workout: Workout) -> RepTemplate? {
    if item.repMin != nil && item.repMax != nil { return nil }
    return item.repTemplate ?? workout.repTemplate ?? .standard
}

/// The whole workout on one template. Picks made on single exercises start over, so the list
/// under the four buttons always shows what each exercise will use.
func settingRepTemplate(_ t: RepTemplate, on w: Workout) -> Workout {
    var w = w
    w.repTemplate = t == .standard ? nil : t
    for i in w.items.indices {
        w.items[i].repTemplate = nil
        w.items[i].repMin = nil
        w.items[i].repMax = nil
    }
    return w
}

/// One exercise on a template, for this workout only. It beats the workout's template.
func settingRepTemplate(_ t: RepTemplate, on item: WorkoutItem) -> WorkoutItem {
    var x = item
    x.repTemplate = t
    x.repMin = nil
    x.repMax = nil
    return x
}

/// One exercise on its own numbers, for this workout only.
func settingRepRange(_ r: RepRange, on item: WorkoutItem) -> WorkoutItem {
    var x = item
    x.repTemplate = nil
    x.repMin = r.lo
    x.repMax = r.hi
    return x
}

/// On finish each exercise keeps the range it was done at, so history stays true when the
/// variation's own range or the templates change later.
func freezingRepRanges(_ w: Workout, versions: [Version], group: (Version) -> RepGroup) -> Workout {
    var w = w
    for i in w.items.indices {
        guard let v = versions.first(where: { $0.id == w.items[i].versionId }) else { continue }
        let r = effectiveRepRange(item: w.items[i], workout: w, version: v, group: group(v))
        w.items[i].repMin = r.lo
        w.items[i].repMax = r.hi
    }
    return w
}

extension WorkoutItem {
    /// The range saved with a finished workout; nil for workouts from before templates.
    var savedRepRange: RepRange? {
        guard let lo = repMin, let hi = repMax else { return nil }
        return RepRange(lo, hi)
    }
    /// The range a past session is judged by: the saved one, else the variation's own.
    func doneRange(_ v: Version) -> RepRange { savedRepRange ?? RepRange(v.repMin, v.repMax) }
}

func verdict(_ sets: [SetEntry], _ r: RepRange) -> Verdict { verdict(sets, repMin: r.lo, repMax: r.hi) }
