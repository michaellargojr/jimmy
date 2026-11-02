import Foundation

// Machines as their own variations. Each kind of machine (Seed/MachineTypes.swift) needs its own
// weights, so it is its own variation. Two machines of one kind are told apart by a name and keep
// separate histories; machines that differ only slightly stay styles of one variation. The same
// goes for any style: everything starts as a style, and one that turns out to need its own
// weights (an underhand grip that runs heavier) can become its own variation.

/// The name a machine (or a style made its own variation) is saved under: trimmed, first letter
/// capitalized, so it reads as a name in the title ("Machine Calf Raise (D Stars)"). Nothing typed gives nil.
func machineName(_ text: String?) -> String? {
    let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = t.first else { return nil }
    return first.uppercased() + t.dropFirst()
}

/// A machine with no Plates or Stack yet takes the way its kind usually comes. Others are unchanged.
func withUsualLoading(_ spec: VariationSpec, base name: String) -> VariationSpec {
    guard spec.family == .machine, spec.loading == nil,
          let t = machineTypes(forBase: name).first(where: { $0.fits(tag: spec.tag, position: spec.position, arm: spec.armPosition) }) else { return spec }
    var out = spec
    out.loading = t.loading
    return out
}

/// The kind from the list that a typed name names ("pec deck", "Iso-lateral pulldown"), if any.
func machineType(named text: String?, in types: [MachineType]) -> MachineType? {
    let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !t.isEmpty else { return nil }
    return types.first { $0.name.lowercased() == t || ($0.tag?.lowercased() == t) }
}

/// The variation a machine name makes beside `v`: another kind from the list when the name is one
/// ("Pec deck"), otherwise the same kind under that name ("D Stars").
func namedMachineSpec(_ text: String?, beside v: Version, types: [MachineType]) -> VariationSpec? {
    if v.family == .machine, let t = machineType(named: text, in: types), !t.fits(v) {
        return VariationSpec(family: .machine, arms: v.arms, position: t.position ?? v.position, armPosition: t.arm ?? v.armPosition,
                             tag: t.tag, loading: t.loading)
    }
    guard let name = machineName(text) else { return nil }
    var spec = VariationSpec(v)
    spec.machine = name
    return spec
}

/// The app's pick for a machine name typed on a style: its own variation when the name is another
/// kind from the list; otherwise a style, since you went to the style to name it. You can switch.
func styleNameIsOwnVariation(_ text: String?, beside v: Version, types: [MachineType]) -> Bool {
    guard v.family == .machine, let t = machineType(named: text, in: types) else { return false }
    return !t.fits(v)
}

/// The variation a style becomes on its own beside `v`, and what stays a style on it. On a machine,
/// the machine name decides (namedMachineSpec) and the rest (a grip) stays its style. Otherwise the
/// variation is this one under the style's words ("Underhand", "Rope · Chest height"). Nil for an
/// empty style.
func ownVariation(of s: StyleSpec, name: String? = nil, beside v: Version, types: [MachineType]) -> (spec: VariationSpec, rest: StyleSpec)? {
    if v.family == .machine, machineName(s.machine) != nil, let spec = namedMachineSpec(s.machine, beside: v, types: types) {
        var rest = s
        rest.machine = nil
        return (spec, rest)
    }
    let given = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard let words = machineName(given.isEmpty ? s.label : given) else { return nil }
    var spec = VariationSpec(v)
    spec.machine = [v.machine, words].compactMap { $0 }.joined(separator: " - ")
    return (spec, StyleSpec())
}

/// A style that turned out to need its own history: everything logged in it moves to the
/// variation `to`, which takes the style's place, and the style goes. Workouts in progress move
/// too, since those sets were done that way. Routines that named the style follow it. What was
/// left of the style (a grip beside a machine name) lands as `rest`, a style of `to`.
func promotingStyle(_ s: HistoryState, styleId: String, to: String, rest: String? = nil) -> HistoryState {
    var out = s
    for i in out.workouts.indices {
        for j in out.workouts[i].items.indices where out.workouts[i].items[j].styleId == styleId {
            out.workouts[i].items[j].versionId = to
            out.workouts[i].items[j].styleId = rest
        }
    }
    for i in out.routines.indices {
        for j in out.routines[i].items.indices where out.routines[i].items[j].styleId == styleId {
            out.routines[i].items[j].versionId = to
            out.routines[i].items[j].styleId = rest
        }
    }
    out.styles.removeAll { $0.id == styleId }
    return out
}
