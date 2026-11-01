import Foundation

// Duplicate a routine (dropping exercises before it is made) and edit a routine from the split
// page. A change to a routine taken from the routine list asks first: save as a new routine,
// update the original, or discard.

/// A routine being edited in the draft sheet. Nothing is saved until Create or Done.
struct RoutineDraft: Equatable {
    /// One row of the sheet. The id keeps rows steady while they are removed and dragged.
    struct Row: Identifiable, Equatable {
        let id: String
        var item: RoutineItem
    }

    var name: String
    var rows: [Row]
    var groups: [ExerciseGroup]

    init(_ r: Routine, name: String? = nil) {
        self.name = name ?? r.name
        rows = r.items.map { Row(id: uid(), item: $0) }
        groups = r.groups
    }

    var items: [RoutineItem] { rows.map(\.item) }

    mutating func remove(id: String) {
        rows.removeAll { $0.id == id }
        tidyGroups()
    }

    /// Array.move(fromOffsets:toOffset:) is SwiftUI's; this is the same move by hand.
    mutating func move(from offsets: IndexSet, to destination: Int) {
        let moving = offsets.sorted().map { rows[$0] }
        let before = offsets.filter { $0 < destination }.count
        for i in offsets.sorted(by: >) { rows.remove(at: i) }
        rows.insert(contentsOf: moving, at: min(max(destination - before, 0), rows.count))
    }

    mutating func append(_ item: RoutineItem) {
        rows.append(Row(id: uid(), item: item))
    }

    /// A group left with one exercise is no longer a superset; a group left with none goes.
    mutating func tidyGroups() {
        for g in groups where rows.filter({ $0.item.groupId == g.id }).count == 1 {
            for i in rows.indices where rows[i].item.groupId == g.id { rows[i].item.groupId = nil }
        }
        groups.removeAll { g in !rows.contains { $0.item.groupId == g.id } }
    }

    /// Same exercises, styles, order and groups as the routine.
    func matches(_ r: Routine) -> Bool { items == r.items && groups == r.groups }

    /// The draft as a routine: the original's id when updating, a fresh one with fresh group ids for a copy.
    func routine(id: String? = nil) -> Routine {
        guard id == nil else { return Routine(id: id!, name: name, items: items, groups: groups) }
        var fresh: [String: String] = [:]
        for g in groups { fresh[g.id] = uid() }
        let items = self.items.map { it -> RoutineItem in
            var i = it
            i.groupId = it.groupId.flatMap { fresh[$0] }
            return i
        }
        return Routine(name: name, items: items, groups: groups.map { ExerciseGroup(id: fresh[$0.id]!, type: $0.type) })
    }
}

/// "Shoulders" to "Shoulders 2", "Shoulders 2" to "Shoulders 3", skipping names already in use.
func copyName(_ name: String, taken: [String]) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    var stem = trimmed, n = 2
    if let space = trimmed.lastIndex(of: " "), let k = Int(trimmed[trimmed.index(after: space)...]), k >= 1 {
        stem = String(trimmed[..<space]); n = k + 1
    }
    let used = Set(taken.map { $0.lowercased() })
    while used.contains("\(stem) \(n)".lowercased()) { n += 1 }
    return "\(stem) \(n)"
}

/// What changed, in a few plain words: "Removed Upright Row - Added Arnold Press - New order".
func routineChanges(from old: [RoutineItem], to new: [RoutineItem], name: (RoutineItem) -> String) -> String {
    struct Key: Hashable { var v: String; var s: String? }
    func key(_ i: RoutineItem) -> Key { Key(v: i.versionId, s: i.styleId) }
    func counts(_ xs: [RoutineItem]) -> [Key: Int] { xs.reduce(into: [:]) { $0[key($1), default: 0] += 1 } }
    // Walk each list against the other's counts: what is left over was removed or added.
    var inNew = counts(new), inOld = counts(old)
    var keptOld: [Key] = [], keptNew: [Key] = [], removed: [RoutineItem] = [], added: [RoutineItem] = []
    for i in old {
        let k = key(i)
        if inNew[k, default: 0] > 0 { inNew[k, default: 0] -= 1; keptOld.append(k) } else { removed.append(i) }
    }
    for i in new {
        let k = key(i)
        if inOld[k, default: 0] > 0 { inOld[k, default: 0] -= 1; keptNew.append(k) } else { added.append(i) }
    }
    var parts: [String] = []
    if !removed.isEmpty { parts.append("Removed " + removed.map(name).joined(separator: ", ")) }
    if !added.isEmpty { parts.append("Added " + added.map(name).joined(separator: ", ")) }
    if keptOld != keptNew { parts.append("New order") }
    if parts.isEmpty && old != new { parts.append("Groups changed") }
    return parts.joined(separator: " - ")
}

extension Split {
    /// The spot in this cycle a workout's routine stands for. A routine swapped out with
    /// "Save as new routine" still counts for the one that took its place, so Up next keeps going.
    func slotRoutineId(for routineId: String) -> String? {
        if routineIds.contains(routineId) { return routineId }
        var id = routineId
        var seen: Set<String> = [id]
        while let next = replaced?[id], !seen.contains(next) {
            if routineIds.contains(next) { return next }
            seen.insert(next); id = next
        }
        return nil
    }

    /// Put another routine in one spot of the cycle. When the old routine leaves the cycle
    /// entirely, remember the swap so its workouts keep their place for Up next.
    mutating func replace(at index: Int, with newId: String) {
        guard routineIds.indices.contains(index) else { return }
        let old = routineIds[index]
        routineIds[index] = newId
        var map = replaced ?? [:]
        map[newId] = nil
        if !routineIds.contains(old) { map[old] = newId } else { map[old] = nil }
        replaced = map.isEmpty ? nil : map
    }

    /// A routine joining the cycle by hand stands for itself again.
    mutating func add(_ routineId: String) {
        routineIds.append(routineId)
        replaced?[routineId] = nil
        if replaced?.isEmpty == true { replaced = nil }
    }

    mutating func noteMadeHere(_ routineId: String) {
        var ids = madeHere ?? []
        if !ids.contains(routineId) { ids.append(routineId) }
        madeHere = ids
    }
}

/// The spot after the last finished workout from this cycle (newest first in `finished`), or the
/// first spot when none is from it.
func upNextSlot(in split: Split, finished: [Workout]) -> Int? {
    let ids = split.routineIds
    guard !ids.isEmpty else { return nil }
    for w in finished {
        if let rid = w.routineId, let slot = split.slotRoutineId(for: rid), let i = ids.firstIndex(of: slot) {
            return (i + 1) % ids.count
        }
    }
    return 0
}

/// Edits from the split page ask first unless the routine was made on that split page and is
/// used nowhere else, in this split or another.
func asksBeforeSaving(_ routineId: String, in split: Split, splits: [Split]) -> Bool {
    guard split.madeHere?.contains(routineId) == true else { return true }
    let uses = splits.reduce(0) { n, s in n + s.routineIds.filter { $0 == routineId }.count }
    return uses > 1
}

/// What the Undo bar on the split page puts back.
struct RoutineUndo: Identifiable {
    let id = uid()
    var message: String
    var splitId: String
    var splitBefore: Split?
    var routineBefore: Routine?
    var createdRoutineId: String?
}
