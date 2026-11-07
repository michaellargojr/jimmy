import Foundation

// Base > variation > style. Labels and matching shared by the seed, the store and the screens.

/// The 22 muscle regions the encyclopedia and the body map use.
let MUSCLE_REGIONS: [String] = [
    "upper chest", "middle and lower chest", "front delt", "side delt", "rear delt", "biceps", "triceps", "forearms",
    "upper traps", "upper back", "lats", "lower back", "abs", "obliques", "glutes", "side glute", "quads", "hamstrings",
    "adductors", "calves", "shins",
]

extension MuscleGroup {
    /// Order of the muscle chips on the Exercises tab.
    static let chipOrder: [MuscleGroup] = [.Chest, .Back, .Shoulders, .Biceps, .Triceps, .Forearms, .Legs, .Glutes, .Calves, .Abs]
    var label: String { self == .Abs ? "Core" : rawValue }
}

/// What makes a variation: family, arms, optional position, optional tag.
struct VariationSpec: Hashable {
    var family: EquipmentFamily
    var arms: Arms = .two
    var position: Position? = nil
    /// Where the upper arm sits, apart from the body position.
    var armPosition: ArmPosition? = nil
    var tag: String? = nil
    /// A nickname people search by ("preacher", "Bayesian", "skull crusher").
    var nick: String? = nil
    /// One machine's own name when you have two of a type ("D Stars").
    var machine: String? = nil
    /// Plates or stack, for machines.
    var loading: Loading? = nil
    /// One dumbbell in both hands, on dumbbells only.
    var single: Bool = false
    /// Close or wide grip.
    var grip: GripWidth? = nil

    var key: VariationKey {
        VariationKey(family: family, arms: arms, position: position, tag: tag?.lowercased(), machine: machine?.lowercased(),
                     loading: family == .machine ? loading : nil, armPosition: armPosition, single: family == .dumbbell && single, grip: grip)
    }

    /// Grammar: "<family> [one|two] [single] [position] [arm position] [tag words] [(nick)]", e.g.
    /// "cable one arms-behind (Bayesian)", "dumbbell one standing arm-on-pad", "dumbbell single seated overhead". Off a machine,
    /// "overhead" is the arm position; on one it names the kind ("machine overhead").
    init?(_ text: String) {
        var words = text.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        if let open = text.firstIndex(of: "("), let close = text.firstIndex(of: ")"), open < close {
            nick = String(text[text.index(after: open)..<close])
            words = text[..<open].trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        }
        guard let first = words.first else { return nil }
        switch first {
        case "dumbbell": family = .dumbbell
        case "cable": family = .cable
        case "machine": family = .machine
        case "bar", "barbell": family = .bar
        case "body", "bodyweight": family = .body
        default: return nil
        }
        words.removeFirst()
        if words.first == "one" { arms = .one; words.removeFirst() } else if words.first == "two" { words.removeFirst() }
        var rest: [String] = []
        for w in words {
            if w == "one" { arms = .one }
            else if w == "two" { arms = .two }
            else if w == "single", family == .dumbbell { single = true }
            else if grip == nil, w.hasSuffix("-grip"), let g = GripWidth(rawValue: String(w.dropLast(5))) { grip = g }
            else if position == nil, let p = Position(rawValue: w) { position = p }
            else if armPosition == nil, let a = ArmPosition(rawValue: w), a != .overhead || family != .machine { armPosition = a }
            else { rest.append(w) }
        }
        if !rest.isEmpty { tag = rest.joined(separator: " ") }
    }

    init(family: EquipmentFamily, arms: Arms = .two, position: Position? = nil, armPosition: ArmPosition? = nil, tag: String? = nil,
         nick: String? = nil, machine: String? = nil, loading: Loading? = nil, single: Bool = false, grip: GripWidth? = nil) {
        self.family = family; self.arms = arms; self.position = position; self.armPosition = armPosition; self.tag = tag; self.nick = nick
        self.machine = machine; self.loading = loading; self.single = single; self.grip = grip
    }

    /// The fields of a variation you have, so the add flow can start from it.
    init(_ v: Version) {
        self.init(family: v.family, arms: v.arms, position: v.position, armPosition: v.armPosition, tag: v.tag, machine: v.machine,
                  loading: v.loading, single: v.isSingleDumbbell, grip: v.grip)
    }
}

/// The style fields, used when seeding and in the add flow before a Style exists.
struct StyleSpec: Hashable {
    var attachment: String? = nil
    var cableHeight: CableHeight? = nil
    var benchAngle: Int? = nil
    var barType: BarType? = nil
    var grip: String? = nil
    var machine: String? = nil

    var isEmpty: Bool { self == StyleSpec() }
    var key: StyleKey {
        StyleKey(attachment: attachment?.lowercased(), cableHeight: cableHeight?.rawValue, benchAngle: benchAngle, barType: barType,
                 grip: grip?.lowercased(), machine: machine?.lowercased())
    }
    func style(for versionId: String) -> Style {
        Style(versionId: versionId, attachment: attachment, cableHeight: cableHeight?.rawValue, benchAngle: benchAngle,
              barType: barType, grip: grip, machine: machine)
    }
    var label: String { style(for: "").label }
}

extension StyleSpec {
    /// The fields of a style you have.
    init(_ s: Style) {
        self.init(attachment: s.attachment, cableHeight: s.cableHeight.flatMap { CableHeight(rawValue: $0) },
                  benchAngle: s.benchAngle, barType: s.barType, grip: s.grip, machine: s.machine)
    }
}

/// "Cable · one arm · arms behind". Leg bases say "one leg"; body weight hides "two arms".
func variationLabel(family: EquipmentFamily, arms: Arms, position: Position?, armPosition: ArmPosition? = nil, tag: String?,
                    machine: String? = nil, loading: Loading? = nil, single: Bool = false, grip: GripWidth? = nil, legs: Bool) -> String {
    variationParts(family: family, arms: arms, position: position, armPosition: armPosition, tag: tag, machine: machine,
                   loading: loading, single: single, grip: grip, legs: legs)
        .joined(separator: " · ")
}

/// The equipment word on a variation's chip. Dumbbells come as a pair unless it's one arm
/// ("Dumbbell | One arm") or one dumbbell in both hands ("Single dumbbell | Two arms").
func familyWord(_ family: EquipmentFamily, arms: Arms, single: Bool, legs: Bool) -> String {
    guard family == .dumbbell else { return family.label }
    if single { return "Single dumbbell" }
    return arms == .one && !legs ? "Dumbbell" : "Dumbbells"
}

/// The words that make a variation, one per chip: "Cable", "one arm", "standing", "arms behind".
/// A machine says how it's loaded, then its type and name: "Machine", "plates", "iso-lateral", "D Stars", "one arm".
/// A close or wide grip comes last.
func variationParts(family: EquipmentFamily, arms: Arms, position: Position?, armPosition: ArmPosition? = nil, tag: String?,
                    machine: String? = nil, loading: Loading? = nil, single: Bool = false, grip: GripWidth? = nil, legs: Bool) -> [String] {
    var parts: [String] = [familyWord(family, arms: arms, single: single, legs: legs)]
    if let loading { parts.append(loading.label) }
    if let tag, !tag.isEmpty { parts.append(tag) }
    if let machine, !machine.isEmpty { parts.append(machine) }
    if arms == .one || (!legs && family != .body) { parts.append(arms.label(legs: legs)) }
    if let position { parts.append(position.label) }
    if let armPosition { parts.append(armPosition.label) }
    if let grip { parts.append(grip.label) }
    return parts
}

func variationLabel(_ v: Version, legs: Bool) -> String {
    variationLabel(family: v.family, arms: v.arms, position: v.position, armPosition: v.armPosition, tag: v.tag, machine: v.machine,
                   loading: v.loading, single: v.isSingleDumbbell, grip: v.grip, legs: legs)
}

/// A variation's words for its chip, each starting with a capital: "Machine", "Stack", "Two arms".
func variationChipWords(_ s: VariationSpec, legs: Bool) -> [String] {
    variationParts(family: s.family, arms: s.arms, position: s.position, armPosition: s.armPosition, tag: s.tag, machine: s.machine,
                   loading: s.loading, single: s.family == .dumbbell && s.single, grip: s.grip, legs: legs)
        .map { capitalized($0) }
}

func variationLabel(_ s: VariationSpec, legs: Bool) -> String {
    variationLabel(family: s.family, arms: s.arms, position: s.position, armPosition: s.armPosition, tag: s.tag, machine: s.machine,
                   loading: s.loading, single: s.family == .dumbbell && s.single, grip: s.grip, legs: legs)
}

/// Order variations on a base page: by family, then two arms before one, then position.
func variationSort(_ a: Version, _ b: Version) -> Bool {
    let fa = EquipmentFamily.allCases.firstIndex(of: a.family)!, fb = EquipmentFamily.allCases.firstIndex(of: b.family)!
    if fa != fb { return fa < fb }
    if a.arms != b.arms { return a.arms == .two }
    if a.isSingleDumbbell != b.isSingleDumbbell { return !a.isSingleDumbbell }
    let pa = a.position.map { Position.allCases.firstIndex(of: $0)! } ?? -1
    let pb = b.position.map { Position.allCases.firstIndex(of: $0)! } ?? -1
    if pa != pb { return pa < pb }
    let aa = a.armPosition.map { ArmPosition.allCases.firstIndex(of: $0)! } ?? -1
    let ab = b.armPosition.map { ArmPosition.allCases.firstIndex(of: $0)! } ?? -1
    if aa != ab { return aa < ab }
    let ga = a.grip.map { GripWidth.allCases.firstIndex(of: $0)! } ?? -1
    let gb = b.grip.map { GripWidth.allCases.firstIndex(of: $0)! } ?? -1
    if ga != gb { return ga < gb }
    if (a.tag ?? "") != (b.tag ?? "") { return (a.tag ?? "") < (b.tag ?? "") }
    if a.loading != b.loading { return (a.loading?.rawValue ?? "") < (b.loading?.rawValue ?? "") }
    return (a.machine ?? "") < (b.machine ?? "")
}
