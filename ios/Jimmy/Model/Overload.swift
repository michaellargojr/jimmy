import Foundation

// Progression rules, ported verbatim from src/overload.ts.

enum Verdict { case up, down, none }

let UP_FIRST_OFFSET = 2   // set 1 must reach repMax + 2
let UP_SECOND_OFFSET = -1 // set 2 must reach repMax - 1

func workingSets(_ sets: [SetEntry]) -> [SetEntry] { sets.filter { $0.kind == .working } }

/// Verdict for a finished (or in-progress) exercise. Warm-ups are ignored.
func verdict(_ sets: [SetEntry], repMin: Int, repMax: Int) -> Verdict {
    let w = workingSets(sets).filter { $0.reps != nil }
    guard let s1 = w.first, let r1 = s1.reps else { return .none }
    if r1 < repMin { return .down }
    if w.count >= 2, let r2 = w[1].reps {
        if r1 >= repMax + UP_FIRST_OFFSET && r2 >= repMax + UP_SECOND_OFFSET { return .up }
    }
    return .none
}

func verdict(_ sets: [SetEntry], _ v: Version) -> Verdict { verdict(sets, repMin: v.repMin, repMax: v.repMax) }

/// Did this set beat the same-index set last time? Same unit assumed.
func improved(now: SetEntry, last: SetEntry?) -> Bool {
    guard let last, let nr = now.reps, let nw = now.weight, let lw = last.weight, let lr = last.reps else { return false }
    if nw > lw { return true }
    if nw == lw && nr > lr { return true }
    return false
}

/// Pair today's sets with last time's sets by kind + ordinal (+ side when present).
func matchLast(now: SetEntry, nowAll: [SetEntry], lastAll: [SetEntry]) -> SetEntry? {
    let sameKindNow = nowAll.filter { $0.kind == now.kind && (now.side == nil || $0.side == now.side) }
    guard let idx = sameKindNow.firstIndex(where: { $0.id == now.id }) else { return nil }
    let sameKindLast = lastAll.filter { $0.kind == now.kind && (now.side == nil || $0.side == now.side) }
    return idx < sameKindLast.count ? sameKindLast[idx] : nil
}
