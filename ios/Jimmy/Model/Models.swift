import Foundation

// Mirrors src/model.ts in the web app. JSON keys and enum raw values are kept
// identical so a web export imports into the native app unchanged.

enum Equipment: String, Codable, CaseIterable, Hashable {
    case cable, machine, dumbbell, barbell, ezbar, smith, bodyweight
    var label: String { self == .ezbar ? "EZ bar" : rawValue }
}
enum Arms: String, Codable, CaseIterable, Hashable {
    case two, one
    /// "two arms" / "one arm", or legs for leg bases.
    func label(legs: Bool = false) -> String {
        switch (self, legs) {
        case (.two, false): return "two arms"
        case (.one, false): return "one arm"
        case (.two, true): return "two legs"
        case (.one, true): return "one leg"
        }
    }
}

/// The five equipment families a variation is grouped by. Barbell, EZ bar and Smith are
/// one family; which bar is a style.
enum EquipmentFamily: String, Codable, CaseIterable, Hashable {
    case dumbbell, cable, machine, bar, body
    var label: String {
        switch self {
        case .dumbbell: return "Dumbbell"
        case .cable: return "Cable"
        case .machine: return "Machine"
        case .bar: return "Bar"
        case .body: return "Body"
        }
    }
    /// The equipment value stored on a variation of this family (keeps the web JSON shape).
    var equipment: Equipment {
        switch self {
        case .dumbbell: return .dumbbell
        case .cable: return .cable
        case .machine: return .machine
        case .bar: return .barbell
        case .body: return .bodyweight
        }
    }
}

extension Equipment {
    var family: EquipmentFamily {
        switch self {
        case .dumbbell: return .dumbbell
        case .cable: return .cable
        case .machine: return .machine
        case .barbell, .ezbar, .smith: return .bar
        case .bodyweight: return .body
        }
    }
}

/// Body position of a variation. Optional: wrist curls carry none.
enum Position: String, Codable, CaseIterable, Hashable {
    case standing, seated, kneeling, lying
    case chestSupported = "chest-supported"
    case armsBehind = "arms-behind"
    case armOnPad = "arm-on-pad"
    var label: String {
        switch self {
        case .standing: return "standing"
        case .seated: return "seated"
        case .kneeling: return "kneeling"
        case .lying: return "lying"
        case .chestSupported: return "chest supported"
        case .armsBehind: return "arms behind"
        case .armOnPad: return "arm on pad"
        }
    }
    /// Seated and lying positions can sit on a bench, so bench angle applies.
    var usesBench: Bool { self == .seated || self == .lying || self == .armsBehind || self == .chestSupported }
}

/// Which bar: a style, never a variation.
enum BarType: String, Codable, CaseIterable, Hashable {
    case barbell, ez, smith
    var label: String {
        switch self {
        case .barbell: return "Barbell"
        case .ez: return "EZ bar"
        case .smith: return "Smith"
        }
    }
    var equipment: Equipment { self == .ez ? .ezbar : (self == .smith ? .smith : .barbell) }
}
enum WeightUnit: String, Codable, CaseIterable, Hashable {
    case kg, lbs
    var label: String { self == .lbs ? "lb" : "kg" }
}
enum Side: String, Codable, Hashable { case L, R }
enum Bar: String, Codable, Hashable { case ez, straight }
enum GroupType: String, Codable, CaseIterable, Hashable {
    case superset, triset, circuit
    var label: String { rawValue.capitalized }
    /// Named by how many exercises it holds: two make a superset, three a triset, more a circuit.
    static func forCount(_ n: Int) -> GroupType { n <= 2 ? .superset : n == 3 ? .triset : .circuit }
}
enum MuscleGroup: String, Codable, CaseIterable, Hashable {
    case Back, Abs, Chest, Shoulders, Triceps, Biceps, Forearms, Calves, Legs, Glutes
}
enum SetKind: String, Codable, Hashable {
    case warmup, working, drop
    /// "W " or "D " in front of a set in one-line summaries.
    var prefix: String { self == .warmup ? "W " : self == .drop ? "D " : "" }
}

struct Gym: Codable, Identifiable, Hashable {
    var id: String
    var name: String
}

/// A base exercise (Lateral Raise). Variations hang off it and carry the history.
struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var muscleGroup: MuscleGroup
    var aliases: [String] = []
    /// Other groups this base also shows under (Dip: Chest and Triceps).
    var alsoGroups: [MuscleGroup] = []
    /// Muscle regions, from the encyclopedia (see MuscleRegion).
    var primary: [String] = []
    var secondary: [String] = []
    /// Set on a base Michael added himself, one the library does not know.
    var custom: Bool?

    init(id: String = uid(), name: String, muscleGroup: MuscleGroup, aliases: [String] = [], alsoGroups: [MuscleGroup] = [],
         primary: [String] = [], secondary: [String] = [], custom: Bool? = nil) {
        self.id = id; self.name = name; self.muscleGroup = muscleGroup; self.aliases = aliases; self.alsoGroups = alsoGroups
        self.primary = primary; self.secondary = secondary; self.custom = custom
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        muscleGroup = (try? c.decode(MuscleGroup.self, forKey: .muscleGroup)) ?? .Back
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        alsoGroups = (try? c.decodeIfPresent([MuscleGroup].self, forKey: .alsoGroups)) ?? []
        primary = try c.decodeIfPresent([String].self, forKey: .primary) ?? []
        secondary = try c.decodeIfPresent([String].self, forKey: .secondary) ?? []
        custom = try c.decodeIfPresent(Bool.self, forKey: .custom)
    }

    /// Leg bases say "one leg" instead of "one arm".
    var isLegs: Bool { muscleGroup == .Legs || muscleGroup == .Glutes || muscleGroup == .Calves }
    var groups: [MuscleGroup] { [muscleGroup] + alsoGroups.filter { $0 != muscleGroup } }
}

/// A loose JSON value, used for the version change log the web app writes.
enum JSONValue: Codable, Hashable {
    case string(String), number(Double), bool(Bool), null
    case array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
    var text: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "yes" : "no"
        case .null: return "–"
        case .array, .object: return "…"
        }
    }
}

struct VersionChange: Codable, Hashable {
    var date: String
    var field: String
    var from: JSONValue?
    var to: JSONValue?
}

/// A link saved on a variation (TikTok, YouTube, anything). Kept apart from clips, which
/// are files stored inside the app.
struct Media: Codable, Hashable {
    var type: String // "tiktok" | "video"
    var url: String
}

enum ClipKind: String, Codable, Hashable { case video, photo }

/// A form cue clip: a video or photo stored once inside the app and shared by any number of
/// variations. The id is a fingerprint of the file you picked, so the same video added twice
/// (to the same or another variation) reuses the stored copy.
struct Clip: Codable, Identifiable, Hashable {
    var id: String
    var kind: ClipKind
    /// File extension of the stored copy ("mp4", "jpg", "heic").
    var ext: String
    var bytes: Int
    /// Seconds, for videos.
    var duration: Double?
    var width: Int?
    var height: Int?
    var addedAt: Double
    var fileName: String { "\(id).\(ext)" }
}

/// A Version is a variation of a base: equipment family, arms, position. It carries the
/// weight and rep history and the rep range. Styles (attachment, bar, bench notch) share it.
struct Version: Codable, Identifiable, Hashable {
    var id: String
    var exerciseId: String
    var name: String
    var equipment: Equipment
    var arms: Arms
    var position: Position?
    /// Short qualifier when equipment, arms and position do not say enough: "overhead",
    /// "goblet", "high row", or a machine Michael flipped to its own history ("D Stars").
    var tag: String?
    var attachment: String?
    var machine: String?
    var cableHeight: Double?
    var benchAngle: Double?
    var repMin: Int
    var repMax: Int
    var defaultWarmup: Bool
    var defaultSets: Int
    var notes: String?
    var gymNotes: [String: String] = [:]
    /// Links (Form cues).
    var media: [Media] = []
    /// Clips from the shared library (Form cues), in display order.
    var clipIds: [String] = []
    var changes: [VersionChange] = []

    init(id: String = uid(), exerciseId: String, name: String, equipment: Equipment, arms: Arms,
         position: Position? = nil, tag: String? = nil, machine: String? = nil, repMin: Int = 5, repMax: Int = 8,
         defaultWarmup: Bool = true, defaultSets: Int = 2, notes: String? = nil) {
        self.id = id; self.exerciseId = exerciseId; self.name = name; self.equipment = equipment
        self.arms = arms; self.position = position; self.tag = tag; self.machine = machine; self.repMin = repMin; self.repMax = repMax
        self.defaultWarmup = defaultWarmup; self.defaultSets = defaultSets; self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        exerciseId = try c.decode(String.self, forKey: .exerciseId)
        name = try c.decode(String.self, forKey: .name)
        equipment = (try? c.decode(Equipment.self, forKey: .equipment)) ?? .machine
        arms = (try? c.decode(Arms.self, forKey: .arms)) ?? .two
        position = try? c.decodeIfPresent(Position.self, forKey: .position)
        tag = try c.decodeIfPresent(String.self, forKey: .tag)
        attachment = try c.decodeIfPresent(String.self, forKey: .attachment)
        machine = try c.decodeIfPresent(String.self, forKey: .machine)
        cableHeight = try c.decodeIfPresent(Double.self, forKey: .cableHeight)
        benchAngle = try c.decodeIfPresent(Double.self, forKey: .benchAngle)
        repMin = try c.decodeIfPresent(Int.self, forKey: .repMin) ?? 5
        repMax = try c.decodeIfPresent(Int.self, forKey: .repMax) ?? 8
        defaultWarmup = try c.decodeIfPresent(Bool.self, forKey: .defaultWarmup) ?? true
        defaultSets = try c.decodeIfPresent(Int.self, forKey: .defaultSets) ?? 2
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        gymNotes = try c.decodeIfPresent([String: String].self, forKey: .gymNotes) ?? [:]
        media = try c.decodeIfPresent([Media].self, forKey: .media) ?? []
        clipIds = try c.decodeIfPresent([String].self, forKey: .clipIds) ?? []
        changes = try c.decodeIfPresent([VersionChange].self, forKey: .changes) ?? []
    }

    var family: EquipmentFamily { equipment.family }
    var isBarbell: Bool { family == .bar }
    var repRange: String { "\(repMin) to \(repMax)" }
    /// The fields that make two variations the same one.
    var key: VariationKey { VariationKey(family: family, arms: arms, position: position, tag: tag?.lowercased()) }
}

struct VariationKey: Hashable {
    var family: EquipmentFamily
    var arms: Arms
    var position: Position?
    var tag: String?
}

/// A Style is a way of doing a variation that shares its history: attachment, cable height,
/// bench notch, which bar, grip, or a named machine. Recorded on each set of a workout item.
struct Style: Codable, Identifiable, Hashable {
    var id: String
    var versionId: String
    var name: String?
    var attachment: String?
    var cableHeight: String?
    var benchAngle: Int?
    var barType: BarType?
    var grip: String?
    var machine: String?
    var notes: String?

    init(id: String = uid(), versionId: String, name: String? = nil, attachment: String? = nil, cableHeight: String? = nil,
         benchAngle: Int? = nil, barType: BarType? = nil, grip: String? = nil, machine: String? = nil, notes: String? = nil) {
        self.id = id; self.versionId = versionId; self.name = name; self.attachment = attachment; self.cableHeight = cableHeight
        self.benchAngle = benchAngle; self.barType = barType; self.grip = grip; self.machine = machine; self.notes = notes
    }

    var key: StyleKey {
        StyleKey(attachment: attachment?.lowercased(), cableHeight: cableHeight, benchAngle: benchAngle, barType: barType,
                 grip: grip?.lowercased(), machine: machine?.lowercased())
    }
    var isEmpty: Bool { key == StyleKey() && (name ?? "").isEmpty }

    /// "Rope · Chest height", "EZ bar", "45°", "D Stars".
    var label: String {
        if let name, !name.isEmpty { return name }
        var parts: [String] = []
        if let machine, !machine.isEmpty { parts.append(machine) }
        if let barType { parts.append(barType.label) }
        if let attachment, !attachment.isEmpty { parts.append(capitalized(attachment)) }
        if let grip, !grip.isEmpty { parts.append(capitalized(grip)) }
        if let cableHeight, let h = CableHeight(rawValue: cableHeight) { parts.append(h.label) }
        if let benchAngle { parts.append(benchAngleLabel(benchAngle)) }
        return parts.joined(separator: " · ")
    }
}

struct StyleKey: Hashable {
    var attachment: String? = nil
    var cableHeight: String? = nil
    var benchAngle: Int? = nil
    var barType: BarType? = nil
    var grip: String? = nil
    var machine: String? = nil
}

/// Where the cable pulley sits, picked on the silhouette.
enum CableHeight: String, Codable, CaseIterable, Hashable {
    case overhead, head, shoulder, chest, waist, hip, thigh, knee, shin, ankle
    var label: String {
        switch self {
        case .overhead: return "Overhead"
        case .head: return "Head height"
        case .shoulder: return "Shoulder height"
        case .chest: return "Chest height"
        case .waist: return "Waist height"
        case .hip: return "Hip height"
        case .thigh: return "Thigh height"
        case .knee: return "Knee height"
        case .shin: return "Shin height"
        case .ankle: return "Ankle height"
        }
    }
}

let BENCH_ANGLES: [Int] = [-15, 0, 15, 30, 45, 60, 75, 90]

func benchAngleLabel(_ a: Int) -> String {
    switch a {
    case ..<0: return "Decline"
    case 0: return "Flat"
    case 90...: return "Upright"
    default: return "\(a)°"
    }
}

struct SetEntry: Codable, Identifiable, Hashable {
    var id: String
    var kind: SetKind
    var weight: Double?
    var unit: WeightUnit
    var reps: Int?
    var plus: Bool
    var partials: Int?
    /// The 1 to 3 rating, per set. Only the one picked in Settings is logged (see SetRating).
    var activation: Int?
    var intensity: Int?
    var side: Side?
    var bar: Bar?
    var note: String?

    init(id: String = uid(), kind: SetKind, unit: WeightUnit, weight: Double? = nil, reps: Int? = nil,
         plus: Bool = false, partials: Int? = nil, activation: Int? = nil, intensity: Int? = nil, side: Side? = nil, bar: Bar? = nil, note: String? = nil) {
        self.id = id; self.kind = kind; self.unit = unit; self.weight = weight; self.reps = reps
        self.plus = plus; self.partials = partials; self.activation = activation; self.intensity = intensity
        self.side = side; self.bar = bar; self.note = note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = (try? c.decode(SetKind.self, forKey: .kind)) ?? .working
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        unit = (try? c.decode(WeightUnit.self, forKey: .unit)) ?? .kg
        reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        plus = try c.decodeIfPresent(Bool.self, forKey: .plus) ?? false
        partials = try c.decodeIfPresent(Int.self, forKey: .partials)
        activation = try c.decodeIfPresent(Int.self, forKey: .activation)
        intensity = try c.decodeIfPresent(Int.self, forKey: .intensity)
        side = try c.decodeIfPresent(Side.self, forKey: .side)
        bar = try c.decodeIfPresent(Bar.self, forKey: .bar)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    var hasData: Bool { reps != nil || weight != nil }

    func rating(_ r: SetRating) -> Int? { r == .activation ? activation : intensity }
    mutating func setRating(_ r: SetRating, _ value: Int?) {
        if r == .activation { activation = value } else { intensity = value }
    }
    /// A logged working or drop set. Warm-ups never count as done work.
    var isDone: Bool { kind != .warmup && reps != nil }

    /// "L EZ 30×12+ (2p)"
    var formatted: String {
        let w = weight.map { fmtWeight($0) + (unit == .lbs ? "lb" : "") } ?? "–"
        let r = reps.map { "\($0)\(plus ? "+" : "")" } ?? "–"
        let p = (partials ?? 0) > 0 ? " (\(partials!)p)" : ""
        let s = side.map { "\($0.rawValue) " } ?? ""
        let b = bar == .ez ? "EZ " : ""
        return "\(s)\(b)\(w)×\(r)\(p)"
    }

    /// "30×12+ (2p)" with no side or bar, for places that show the side as its own tag.
    /// Bodyweight sets with no weight read as just the reps.
    var valueText: String {
        let r = reps.map { "\($0)\(plus ? "+" : "")" } ?? "–"
        let p = (partials ?? 0) > 0 ? " (\(partials!)p)" : ""
        guard let weight else { return r + p }
        return fmtWeight(weight) + (unit == .lbs ? "lb" : "") + "×" + r + p
    }
}

struct WorkoutItem: Codable, Identifiable, Hashable {
    var id: String
    var versionId: String
    var styleId: String?
    var groupId: String?
    var sets: [SetEntry]
    var skipped: Bool?
    var note: String?

    init(id: String = uid(), versionId: String, styleId: String? = nil, groupId: String? = nil, sets: [SetEntry], skipped: Bool? = nil, note: String? = nil) {
        self.id = id; self.versionId = versionId; self.styleId = styleId; self.groupId = groupId; self.sets = sets; self.skipped = skipped; self.note = note
    }

    var isDone: Bool { skipped == true || sets.contains { $0.isDone } }
}

struct ExerciseGroup: Codable, Identifiable, Hashable {
    var id: String
    var type: GroupType
}

struct Workout: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var date: String // YYYY-MM-DD
    var gymId: String?
    var routineId: String?
    var startedAt: Double? // ms since epoch, as the web app stores it
    var endedAt: Double?
    var notes: String?
    var items: [WorkoutItem]
    var groups: [ExerciseGroup]

    init(id: String = uid(), name: String, date: String = today(), gymId: String? = nil, routineId: String? = nil,
         startedAt: Double? = nil, endedAt: Double? = nil, notes: String? = nil, items: [WorkoutItem] = [], groups: [ExerciseGroup] = []) {
        self.id = id; self.name = name; self.date = date; self.gymId = gymId; self.routineId = routineId
        self.startedAt = startedAt; self.endedAt = endedAt; self.notes = notes; self.items = items; self.groups = groups
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        date = try c.decode(String.self, forKey: .date)
        gymId = try c.decodeIfPresent(String.self, forKey: .gymId)
        routineId = try c.decodeIfPresent(String.self, forKey: .routineId)
        startedAt = try c.decodeIfPresent(Double.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Double.self, forKey: .endedAt)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        items = try c.decodeIfPresent([WorkoutItem].self, forKey: .items) ?? []
        groups = try c.decodeIfPresent([ExerciseGroup].self, forKey: .groups) ?? []
    }

    var isActive: Bool { startedAt != nil && endedAt == nil }
    var isFinished: Bool { endedAt != nil }
    var durationMinutes: Int? {
        guard let s = startedAt, let e = endedAt else { return nil }
        return Int((e - s) / 60000)
    }
}

/// Routines hold the exact variation and style so a workout is prepped ahead.
struct RoutineItem: Codable, Hashable {
    var versionId: String
    var styleId: String?
    var groupId: String?

    init(versionId: String, styleId: String? = nil, groupId: String? = nil) {
        self.versionId = versionId; self.styleId = styleId; self.groupId = groupId
    }
}

struct Routine: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var items: [RoutineItem]
    var groups: [ExerciseGroup]

    init(id: String = uid(), name: String, items: [RoutineItem] = [], groups: [ExerciseGroup] = []) {
        self.id = id; self.name = name; self.items = items; self.groups = groups
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        items = try c.decodeIfPresent([RoutineItem].self, forKey: .items) ?? []
        groups = try c.decodeIfPresent([ExerciseGroup].self, forKey: .groups) ?? []
    }
}

/// A Split is an ordered cycle of routines. The active split decides "Up next" on Home.
struct Split: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var routineIds: [String]
    /// What the person wants to look like (see Coverage.swift). Absent on web exports.
    var goals: SplitGoals?
    /// The last coverage report, kept so the cards never wait for the network.
    var coverage: CoverageReport?

    init(id: String = uid(), name: String, routineIds: [String] = []) {
        self.id = id; self.name = name; self.routineIds = routineIds
    }
}

struct Idea: Codable, Identifiable, Hashable {
    var id: String
    var kind: String // "bug" | "feature"
    var text: String
    var createdAt: Double
    var page: String?
    var done: Bool?
}

// MARK: - Helpers shared with the web model

func uid() -> String {
    let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    return String((0..<12).map { _ in chars.randomElement()! })
}

private let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

func today() -> String { dayFormatter.string(from: Date()) }
func dayString(_ d: Date) -> String { dayFormatter.string(from: d) }
func dayDate(_ s: String) -> Date { dayFormatter.date(from: s) ?? Date() }

func daysBetween(_ a: String, _ b: String) -> Int {
    let da = Calendar.current.startOfDay(for: dayDate(a)), db = Calendar.current.startOfDay(for: dayDate(b))
    return Calendar.current.dateComponents([.day], from: da, to: db).day ?? 0
}

func fmtWeight(_ w: Double) -> String {
    w == w.rounded() ? String(Int(w)) : String(format: "%.2f", w).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
}

func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

/// First letter up, rest untouched ("rope" to "Rope", "D handle" stays).
func capitalized(_ s: String) -> String {
    guard let f = s.first else { return s }
    return f.uppercased() + s.dropFirst()
}

/// Dashes between items on the Workout screen ("Wrist cuff - hip height"). Stored names keep their dots.
func dashed(_ s: String) -> String { s.replacingOccurrences(of: " · ", with: " - ") }
