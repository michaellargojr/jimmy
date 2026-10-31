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
    var tag: String? = nil
    /// A nickname people search by ("preacher", "Bayesian", "skull crusher").
    var nick: String? = nil

    var key: VariationKey { VariationKey(family: family, arms: arms, position: position, tag: tag?.lowercased()) }

    /// Grammar: "<family> [one|two] [position] [tag words] [(nick)]", e.g. "cable one arms-behind (Bayesian)".
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
        if let w = words.first, let p = Position(rawValue: w) { position = p; words.removeFirst() }
        if !words.isEmpty { tag = words.joined(separator: " ") }
    }

    init(family: EquipmentFamily, arms: Arms = .two, position: Position? = nil, tag: String? = nil, nick: String? = nil) {
        self.family = family; self.arms = arms; self.position = position; self.tag = tag; self.nick = nick
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

/// "Cable · one arm · arms behind". Leg bases say "one leg"; body weight hides "two arms".
func variationLabel(family: EquipmentFamily, arms: Arms, position: Position?, tag: String?, legs: Bool) -> String {
    var parts: [String] = [family.label]
    if let tag, !tag.isEmpty { parts.append(tag) }
    if arms == .one || (!legs && family != .body) { parts.append(arms.label(legs: legs)) }
    if let position { parts.append(position.label) }
    return parts.joined(separator: " · ")
}

func variationLabel(_ v: Version, legs: Bool) -> String {
    variationLabel(family: v.family, arms: v.arms, position: v.position, tag: v.tag, legs: legs)
}

func variationLabel(_ s: VariationSpec, legs: Bool) -> String {
    variationLabel(family: s.family, arms: s.arms, position: s.position, tag: s.tag, legs: legs)
}

/// Order variations on a base page: by family, then two arms before one, then position.
func variationSort(_ a: Version, _ b: Version) -> Bool {
    let fa = EquipmentFamily.allCases.firstIndex(of: a.family)!, fb = EquipmentFamily.allCases.firstIndex(of: b.family)!
    if fa != fb { return fa < fb }
    if a.arms != b.arms { return a.arms == .two }
    let pa = a.position.map { Position.allCases.firstIndex(of: $0)! } ?? -1
    let pb = b.position.map { Position.allCases.firstIndex(of: $0)! } ?? -1
    if pa != pb { return pa < pb }
    return (a.tag ?? "") < (b.tag ?? "")
}
