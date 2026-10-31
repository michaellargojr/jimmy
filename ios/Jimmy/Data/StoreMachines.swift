import Foundation

// Machines as their own variations, on the store (rules in Model/Machines.swift).

extension AppStore {
    /// The kind from the list a machine variation is, if any.
    func machineType(of v: Version) -> MachineType? {
        guard v.family == .machine, let b = base(of: v) else { return nil }
        return machineTypes(forBase: b.name).first { $0.fits(v) }
    }

    /// A machine with no Plates or Stack yet takes the way its kind usually comes.
    func withLoading(_ spec: VariationSpec, base b: Exercise) -> VariationSpec { withUsualLoading(spec, base: b.name) }

    /// Machines saved before Plates and Stack take the way their kind usually comes, so the ones
    /// you have keep matching. Machines not in the list stay unset. True when any changed.
    @discardableResult
    func fillMachineLoading() -> Bool {
        var changed = false
        for i in versions.indices where versions[i].family == .machine && versions[i].loading == nil {
            guard let t = machineType(of: versions[i]) else { continue }
            versions[i].loading = t.loading
            changed = true
        }
        return changed
    }

    /// Your machines of one kind with these arms and this loading, the plain one first, then by
    /// name. A kind that doesn't fix the position matches the position picked.
    func machines(of t: MachineType, baseId: String, arms: Arms, position: Position?, loading: Loading?) -> [Version] {
        let pos = t.position ?? position
        return versions.filter { $0.exerciseId == baseId && $0.arms == arms && $0.position == pos && $0.loading == loading && t.fits($0) }
            .sorted { ($0.machine ?? "").lowercased() < ($1.machine ?? "").lowercased() }
    }

    /// Your machines with these arms that fit no kind in the list (named before the list, or added
    /// as Other), with this loading or none saved.
    func unlistedMachines(base: Exercise, arms: Arms, loading: Loading?) -> [Version] {
        let types = machineTypes(forBase: base.name)
        return versions.filter { v in
            v.exerciseId == base.id && v.family == .machine && v.arms == arms && (v.loading == nil || v.loading == loading)
                && !types.contains { $0.fits(v) }
        }
        .sorted(by: variationSort)
    }

    /// The variation for `spec`, made if new. A new one starts with the rep range and set defaults
    /// of `like`, the one it sits beside, so another gym's machine starts where you are.
    func makeVariation(base b: Exercise, spec given: VariationSpec, like: Version?) -> Version {
        let spec = withLoading(given, base: b)
        if let found = findVariation(baseId: b.id, key: spec.key) { return found }
        var v = makeVariation(base: b, spec: spec, repMin: like?.repMin, repMax: like?.repMax)
        if let like {
            v.defaultSets = like.defaultSets
            v.defaultWarmup = like.defaultWarmup
            put(v)
        }
        return v
    }

    /// False when you already have this machine loaded the other way, so switching would make two the same.
    func canSetLoading(_ v: Version, _ l: Loading) -> Bool {
        var k = VariationSpec(v)
        k.loading = l
        guard let other = findVariation(baseId: v.exerciseId, key: k.key) else { return true }
        return other.id == v.id
    }

    /// Switches a machine between Plates and Stack. Its history stays with it.
    func setLoading(_ versionId: String, _ l: Loading) {
        guard var v = version(versionId), v.family == .machine, v.loading != l, canSetLoading(v, l) else { return }
        v.loading = l
        put(v)
    }

    /// Styles the app offers to make their own variation (Model/Splits.swift), widest gap first.
    var splitOffers: [SplitOffer] {
        let live = Set(versions.map(\.id))
        return findSplitOffers(workouts: workouts, styles: styles.filter { live.contains($0.versionId) }, kept: Set(settings.keptStyles))
    }

    /// Keeps a style a style: the app won't offer to split it again.
    func keepStyle(_ styleId: String) {
        guard !settings.keptStyles.contains(styleId) else { return }
        update { $0.keptStyles.append(styleId) }
    }

    /// Workouts with something logged in this style.
    func styleSessions(_ styleId: String) -> Int {
        workouts.filter { w in w.items.contains { $0.styleId == styleId && $0.sets.contains { $0.hasData } } }.count
    }

    /// Makes a style its own variation, named after it ("Underhand", "D Stars", or the kind it
    /// names, like "Pec deck"), and moves everything logged in it there. Nil for an empty style.
    @discardableResult
    func makeStyleOwnVariation(_ styleId: String) -> Version? {
        guard let st = style(styleId), let v = version(st.versionId), let b = base(of: v),
              let own = ownVariation(of: StyleSpec(st), name: st.name, beside: v, types: machineTypes(forBase: b.name)) else { return nil }
        let nv = makeVariation(base: b, spec: own.spec, like: v)
        guard nv.id != v.id else { return nil }
        let rest = makeStyle(for: nv, spec: own.rest)
        let out = promotingStyle(historyState, styleId: styleId, to: nv.id, rest: rest?.id)
        workouts = out.workouts
        routines = out.routines
        styles = out.styles
        markDirty()
        return nv
    }
}
