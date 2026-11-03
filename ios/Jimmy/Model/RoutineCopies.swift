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

    mutating func remove(id: String) { remove(ids: [id]) }

    /// Duplicate: the unticked rows leave together, then groups are tidied once.
    mutating func remove(ids: Set<String>) {
        rows.removeAll { ids.contains($0.id) }
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

/// Another routine already goes by this name, in any case, spaces at the ends ignored. `except`
/// is the routine being renamed, which may keep its own name. An empty name is never taken.
func routineNameTaken(_ name: String, in routines: [Routine], except: String? = nil) -> Bool {
    let n = name.trimmingCharacters(in: .whitespaces).lowercased()
    guard !n.isEmpty else { return false }
    return routines.contains { $0.id != except && $0.name.trimmingCharacters(in: .whitespaces).lowercased() == n }
}

/// A new routine's name: what was typed, or "New routine" when left empty ("New routine 2" when
/// that is taken).
func newRoutineName(_ typed: String, taken: [String]) -> String {
    let n = typed.trimmingCharacters(in: .whitespaces)
    if !n.isEmpty { return n }
    let used = Set(taken.map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
    return used.contains("new routine") ? copyName("New routine", taken: taken) : "New routine"
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

    /// A routine joining the cycle by hand stands for itself again. It goes at the end, or at
    /// `index` (a copy goes right after the routine it was made from).
    mutating func add(_ routineId: String, at index: Int? = nil) {
        if let i = index, i >= 0, i <= routineIds.count { routineIds.insert(routineId, at: i) } else { routineIds.append(routineId) }
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
/// first spot when none is from it. A spot picked with Make next comes first; once it is done the
/// cycle carries on from that spot, and once anything else from the cycle is done the pick is over.
func upNextSlot(in split: Split, finished: [Workout]) -> Int? {
    let ids = split.routineIds
    guard !ids.isEmpty else { return nil }
    let cycle = cycleWorkouts(in: split, finished: finished, limit: 2)
    if let pick = split.nextPick, ids.indices.contains(pick.slot), ids[pick.slot] == pick.routineId {
        if cycle.first?.workout.id == pick.after { return pick.slot }
        if let done = cycle.first, ids[done.slot] == pick.routineId, cycle.dropFirst().first?.workout.id == pick.after {
            return (pick.slot + 1) % ids.count
        }
    }
    if let last = cycle.first { return (last.slot + 1) % ids.count }
    return 0
}

/// The newest finished workouts from this cycle, each with the spot it stands for.
func cycleWorkouts(in split: Split, finished: [Workout], limit: Int) -> [(workout: Workout, slot: Int)] {
    var out: [(workout: Workout, slot: Int)] = []
    for w in finished where out.count < limit {
        if let rid = w.routineId, let id = split.slotRoutineId(for: rid), let i = split.routineIds.firstIndex(of: id) {
            out.append((w, i))
        }
    }
    return out
}

/// What Make next remembers: the spot, the routine in it then, and the newest finished workout
/// from the cycle at that moment (nil when there was none).
struct NextPick: Codable, Hashable {
    var slot: Int
    var routineId: String
    var after: String?
}

extension Split {
    /// Make next: this spot comes up next, on Home and the Workout tab.
    mutating func makeNext(_ slot: Int, finished: [Workout]) {
        guard routineIds.indices.contains(slot) else { return }
        nextPick = NextPick(slot: slot, routineId: routineIds[slot],
                            after: cycleWorkouts(in: self, finished: finished, limit: 1).first?.workout.id)
    }
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
