import Foundation

// The app notices: a style whose weights keep landing far from the rest of its variation probably
// needs its own history. It offers to make it its own variation; you split it or keep it.

/// One offer: this style runs heavier (or lighter) than the rest of its variation.
struct SplitOffer: Identifiable, Hashable {
    var styleId: String
    var versionId: String
    /// The best set of the style's last session, and of the rest's last session, for the two numbers.
    var styleSet: SetEntry
    var restSet: SetEntry
    var heavier: Bool
    var id: String { styleId }
}

/// How strong a session was: its best working set as an estimated one-rep max in kg (Epley), so
/// 60×10 and 65×8 compare fairly. Nil when nothing weighted was logged.
func sessionStrength(_ item: WorkoutItem) -> Double? {
    item.sets.compactMap { s -> Double? in
        guard s.kind == .working, let w = s.weight, w > 0, let r = s.reps, r > 0 else { return nil }
        let kg = s.unit == .lbs ? w * 0.45359237 : w
        return kg * (1 + Double(r) / 30)
    }.max()
}

/// Styles worth offering as their own variation. A style needs its last `sessions` finished
/// sessions and the rest of its variation (no style, or other styles) its last `sessions` too, and
/// each of the style's must sit at least `gap` from the rest's average, all on the same side. Styles
/// you kept are skipped. One offer per variation (the widest gap), widest first.
func findSplitOffers(workouts: [Workout], styles: [Style], kept: Set<String>, sessions n: Int = 2, gap: Double = 0.15) -> [SplitOffer] {
    let done = sortedNewestFirst(workouts.filter { !$0.isActive })
    var best: [String: (offer: SplitOffer, size: Double)] = [:]
    for st in styles where !kept.contains(st.id) {
        var mine: [(x: Double, item: WorkoutItem)] = []
        var rest: [(x: Double, item: WorkoutItem)] = []
        for w in done {
            for item in w.items where item.versionId == st.versionId {
                guard let x = sessionStrength(item) else { continue }
                if item.styleId == st.id {
                    if mine.count < n { mine.append((x, item)) }
                } else if rest.count < n {
                    rest.append((x, item))
                }
            }
            if mine.count == n && rest.count == n { break }
        }
        guard mine.count == n, rest.count == n else { continue }
        let avg = rest.map(\.x).reduce(0, +) / Double(n)
        guard avg > 0 else { continue }
        let rel = mine.map { $0.x / avg - 1 }
        let heavier = rel.allSatisfy { $0 >= gap }
        guard heavier || rel.allSatisfy({ $0 <= -gap }),
              let ss = topSet(mine[0].item), let rs = topSet(rest[0].item) else { continue }
        let size = abs(rel.reduce(0, +) / Double(n))
        if let b = best[st.versionId], b.size >= size { continue }
        best[st.versionId] = (SplitOffer(styleId: st.id, versionId: st.versionId, styleSet: ss, restSet: rs, heavier: heavier), size)
    }
    return best.values.sorted { $0.size > $1.size }.map(\.offer)
}
