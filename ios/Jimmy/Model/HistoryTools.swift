import Foundation

// Copy, move and erase one variation's history, from the History group on its page in Plan.
// Only finished workouts change: a workout in progress is left alone.

/// Everything a history change touches, kept whole so Undo can put it back.
struct HistoryState: Equatable {
    var workouts: [Workout]
    var routines: [Routine]
    var styles: [Style]
    var watchVersionId: String?
}

/// Finished workouts where this variation has a set logged.
func historySessions(_ versionId: String, workouts: [Workout]) -> [Workout] {
    workouts.filter { w in w.isFinished && w.items.contains { $0.versionId == versionId && $0.sets.contains { $0.hasData } } }
}

/// "1 session", "4 sessions".
func sessionsText(_ n: Int) -> String { "\(n) \(n == 1 ? "session" : "sessions")" }

/// The target's style that matches a source style. Made under the target when it has none,
/// so an attachment or bench angle is not lost on the way.
private func matchingStyle(_ id: String?, on target: String, styles: inout [Style]) -> String? {
    guard let id, let s = styles.first(where: { $0.id == id }), !s.isEmpty else { return nil }
    if s.versionId == target { return s.id }
    if let same = styles.first(where: { $0.versionId == target && $0.key == s.key && ($0.name ?? "") == (s.name ?? "") }) { return same.id }
    var made = s
    made.id = uid()
    made.versionId = target
    styles.append(made)
    return made.id
}

/// Copies every finished session of `from` onto `to`. A picked `styleId` (one of the target's
/// styles) goes on every copied session; otherwise each keeps its own style.
/// With `move` the sessions leave `from`, and routines and the watched exercise switch to `to`.
func copyingHistory(_ s: HistoryState, from: String, to: String, styleId: String? = nil, move: Bool) -> HistoryState {
    guard from != to else { return s }
    var out = s
    for i in out.workouts.indices where out.workouts[i].isFinished {
        var w = out.workouts[i]
        let sources = w.items.filter { $0.versionId == from && (move || $0.sets.contains { $0.hasData }) }
        for src in sources {
            let style = styleId ?? matchingStyle(src.styleId, on: to, styles: &out.styles)
            let sets = move ? src.sets : src.sets.map { var c = $0; c.id = uid(); return c }
            if let t = w.items.firstIndex(where: { $0.versionId == to }) {
                // The target was done that day too: these sets go on the end of it.
                w.items[t].sets += sets
                if w.items[t].styleId == nil { w.items[t].styleId = style }
                if (w.items[t].note ?? "").isEmpty { w.items[t].note = src.note }
                if move { w.items.removeAll { $0.id == src.id } }
            } else if let k = w.items.firstIndex(where: { $0.id == src.id }) {
                if move {
                    w.items[k].versionId = to
                    w.items[k].styleId = style
                } else {
                    // A copy of the whole entry, so anything saved on it (a note, its rep range) comes along.
                    var copy = src
                    copy.id = uid()
                    copy.versionId = to
                    copy.styleId = style
                    copy.groupId = nil
                    copy.sets = sets
                    w.items.insert(copy, at: k + 1)
                }
            }
        }
        out.workouts[i] = w
    }
    guard move else { return out }
    for i in out.routines.indices where out.routines[i].items.contains(where: { $0.versionId == from }) {
        if out.routines[i].items.contains(where: { $0.versionId == to }) {
            out.routines[i].items.removeAll { $0.versionId == from }
        } else {
            for j in out.routines[i].items.indices where out.routines[i].items[j].versionId == from {
                out.routines[i].items[j].versionId = to
                out.routines[i].items[j].styleId = styleId ?? matchingStyle(out.routines[i].items[j].styleId, on: to, styles: &out.styles)
            }
        }
    }
    if out.watchVersionId == from { out.watchVersionId = to }
    return out
}

/// Takes a variation out of every finished workout. A workout left with nothing logged is deleted.
func erasingHistory(_ s: HistoryState, versionId: String) -> HistoryState {
    var out = s
    out.workouts = s.workouts.compactMap { w in
        guard w.isFinished, w.items.contains(where: { $0.versionId == versionId }) else { return w }
        var w = w
        w.items.removeAll { $0.versionId == versionId }
        return w.items.contains { $0.sets.contains { $0.hasData } } ? w : nil
    }
    return out
}

/// The last copy, move or erase, so the history page can offer Undo for a few seconds.
struct HistoryUndo: Identifiable {
    enum Kind { case copy, move, erase }
    let id = uid()
    var kind: Kind
    var message: String
    var before: HistoryState
    /// The history page the change lands on: the target after a copy or move, the variation itself after an erase.
    var landedOn: String
}
