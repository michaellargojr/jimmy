import Foundation

// Close and wide grip moved from styles into the variation (Michael, Nov 2026).

extension AppStore {
    /// A close or wide grip saved as a style, from before grip width was part of the variation,
    /// becomes the variation with that grip: one you have, or a new one that starts from the old
    /// one's rep range, set defaults and nickname. Everything logged in the style moves there (Michael
    /// picked moving them), as Make it its own variation does, routines included. What else the
    /// style said (a rope, a cable height, underhand) stays a style on it. True when any moved.
    @discardableResult
    func moveGripStyles() -> Bool {
        var moved = false
        for st in styles {
            guard let g = GripWidth(styleGrip: st.grip), let v = version(st.versionId), let b = base(of: v) else { continue }
            var spec = VariationSpec(v)
            spec.grip = g
            let had = Set(versions.map(\.id))
            var nv = makeVariation(base: b, spec: spec, like: v)
            if !had.contains(nv.id), let n = cleanNickname(v.nickname) {
                nv.nickname = n
                put(nv)
            }
            var restSpec = StyleSpec(st)
            restSpec.grip = nil
            let existed = findStyle(versionId: nv.id, key: restSpec.key) != nil
            var rest = makeStyle(for: nv, spec: restSpec)
            if !existed, var r = rest, let name = st.name, !name.isEmpty {
                r.name = name
                put(r)
                rest = r
            }
            let out = promotingStyle(historyState, styleId: st.id, to: nv.id, rest: rest?.id)
            workouts = out.workouts
            routines = out.routines
            styles = out.styles
            moved = true
        }
        if moved { markDirty() }
        return moved
    }
}
