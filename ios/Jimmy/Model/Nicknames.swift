import Foundation

// Nicknames: the name everyone at the gym uses for a few exact setups ("Bayesian Curl").
// A variation's nickname is its own field, typed or cleared by you. The app only suggests one
// when every block matches the setup the name means; a twist on it (another equipment, another
// position) gets no suggestion. Checked Nov 1, 2026 against BarBend and mennohenselmans.com
// (Bayesian), Merriam-Webster, Fitness Volt and Oxygen (preacher, standing preacher), Athlean-X (spider) and
// Wikipedia (skull crusher, pec deck).

/// The nickname the app suggests for a setup, or nil. `styleMachines` are the machine names of
/// the variation's styles: a pec deck saved as a style still counts.
func suggestNickname(base: String, family: EquipmentFamily, position: Position?, armPosition: ArmPosition? = nil, tag: String?,
                     styleMachines: [String] = []) -> String? {
    let tag = (tag ?? "").trimmingCharacters(in: .whitespaces).lowercased()
    // A machine's tag is its type; anywhere else a tag is a twist the name doesn't cover.
    let plain = tag.isEmpty || family == .machine
    switch base {
    case "Curl":
        guard plain else { return nil }
        // Cable from behind: the arm drawn back past the body, facing away from the stack,
        // standing or seated.
        if family == .cable, armPosition == .behind, position == nil || position == .standing || position == .seated {
            return "Bayesian Curl"
        }
        // The back of the upper arm on an angled pad, whatever the equipment. Standing behind
        // the pad (an incline bench) is the standing preacher curl.
        if armPosition == .onPad {
            if position == nil || position == .seated { return "Preacher Curl" }
            if position == .standing { return "Standing Preacher Curl" }
        }
        // Chest down on an incline bench, arms hanging straight.
        if position == .chestSupported, armPosition == nil { return "Spider Curl" }
    case "Tricep Extension":
        guard tag.isEmpty, armPosition == nil else { return nil }
        if family == .bar || family == .dumbbell, position == .lying { return "Skull Crusher" }
    case "Chest Fly":
        let machines = styleMachines.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        if family == .machine, tag == "pec deck" || machines.contains("pec deck") { return "Pec Deck" }
    default:
        break
    }
    return nil
}

/// What the Nickname field saves: trimmed, and nil when empty.
func cleanNickname(_ text: String?) -> String? {
    let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? nil : t
}
