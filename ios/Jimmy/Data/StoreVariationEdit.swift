import Foundation

// Changing a variation you have, and two variations with the same blocks told apart by nickname.

/// Which of your variations with the same blocks a pick means. Two can share every block when
/// their nicknames differ (Michael, Nov 2026), so a nickname you type picks one or makes a new one.
enum NicknamePick: Equatable {
    /// The first one you have, whatever its nickname (the field shows its own).
    case any
    /// The one with this nickname (nil: the one with none), or a new one.
    case named(String?)
}

/// Nicknames match without minding capitals or spaces at the ends; none matches none.
func sameNickname(_ a: String?, _ b: String?) -> Bool {
    cleanNickname(a)?.lowercased() == cleanNickname(b)?.lowercased()
}

extension AppStore {
    func findVariation(baseId: String, key: VariationKey, nickname pick: NicknamePick) -> Version? {
        guard case .named(let n) = pick else { return findVariation(baseId: baseId, key: key) }
        return versions.first { $0.exerciseId == baseId && $0.key == key && sameNickname($0.nickname, n) }
    }

    /// The blocks a variation takes from an edit. A switch of equipment drops what only fit the
    /// old one (a machine's kind and name, Plates or Stack); a machine takes how its kind usually comes.
    func editedSpec(_ v: Version, _ given: VariationSpec) -> VariationSpec {
        var spec = given
        if spec.family != v.family { spec.tag = nil; spec.loading = nil }
        if spec.family != .machine { spec.machine = nil; spec.loading = nil }
        spec.machine = machineName(spec.machine)
        guard let b = base(of: v) else { return spec }
        return withLoading(spec, base: b)
    }

    /// Another variation of the same exercise with these blocks and this nickname: an edit that
    /// would make two the same is refused.
    func variationClash(_ versionId: String, spec: VariationSpec, nickname: String?) -> Version? {
        guard let v = version(versionId) else { return nil }
        let key = editedSpec(v, spec).key
        return versions.first { $0.id != versionId && $0.exerciseId == v.exerciseId && $0.key == key && sameNickname($0.nickname, nickname) }
    }

    /// Changes a variation's blocks and nickname, to fix how it was set up. Everything logged in it,
    /// its styles, form cues and routines stay with it. False when it would match another one.
    @discardableResult
    func editVariation(_ versionId: String, spec given: VariationSpec, nickname: String?) -> Bool {
        guard var v = version(versionId), variationClash(versionId, spec: given, nickname: nickname) == nil else { return false }
        let spec = editedSpec(v, given)
        if spec.family != v.family { v.equipment = spec.family.equipment }
        v.arms = spec.arms
        v.position = spec.position
        v.armPosition = spec.armPosition
        v.tag = spec.tag
        v.machine = spec.machine
        v.loading = spec.family == .machine ? spec.loading : nil
        v.singleDumbbell = spec.family == .dumbbell && spec.single ? true : nil
        v.grip = spec.grip
        v.nickname = cleanNickname(nickname)
        if let b = base(of: v) { v.name = b.name + " · " + variationLabel(spec, legs: b.isLegs) }
        put(v)
        return true
    }

    /// False when another variation with the same blocks already goes by this nickname.
    func canUseNickname(_ versionId: String, _ text: String?) -> Bool {
        guard let v = version(versionId) else { return false }
        return !versions.contains { $0.id != versionId && $0.exerciseId == v.exerciseId && $0.key == v.key && sameNickname($0.nickname, text) }
    }
}
