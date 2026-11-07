import Foundation

// Supersets, trisets and circuits, the same everywhere: the Workout page's Overview and a routine's
// page. Tick two or more loose exercises to make a group; tick a grouped one to ungroup it.

/// One exercise in a list that can be grouped.
protocol GroupMember {
    var groupId: String? { get set }
}

/// A list of exercises that can be grouped: a workout or a routine.
protocol GroupedExercises {
    associatedtype Item: GroupMember
    var items: [Item] { get set }
    var groups: [ExerciseGroup] { get set }
}

extension WorkoutItem: GroupMember {}
extension RoutineItem: GroupMember {}
extension Workout: GroupedExercises {}
extension Routine: GroupedExercises {}

extension RoutineDraft.Row: GroupMember {
    var groupId: String? {
        get { item.groupId }
        set { item.groupId = newValue }
    }
}

extension RoutineDraft {
    /// The sheet's rows as a list that groups, keeping each row's id through every change.
    struct Rows: GroupedExercises {
        var items: [Row]
        var groups: [ExerciseGroup]
    }

    var groupable: Rows {
        get { Rows(items: rows, groups: groups) }
        set { rows = newValue.items; groups = newValue.groups }
    }
}

extension GroupedExercises {
    /// The group the exercise at `i` is really in: one it shares with at least one other exercise.
    func liveGroup(at i: Int) -> String? {
        guard items.indices.contains(i), let g = items[i].groupId else { return nil }
        return items.filter { $0.groupId == g }.count >= 2 ? g : nil
    }
}

/// Where a row sits in its group: whether it starts or ends the shared card, and its number among
/// the members. Loose rows start and end their own card.
typealias GroupPlace = (group: String?, first: Bool, last: Bool, members: Int, number: Int)

extension GroupedExercises {
    func groupPlace(at i: Int) -> GroupPlace {
        guard let g = liveGroup(at: i) else { return (nil, true, true, 0, 0) }
        let first = i == 0 || items[i - 1].groupId != g
        let last = i == items.count - 1 || items[i + 1].groupId != g
        let members = items.indices.filter { items[$0].groupId == g }
        return (g, first, last, members.count, (members.firstIndex(of: i) ?? 0) + 1)
    }
}

/// Keeps groups whole after any change. A group split apart keeps only its longest run,
/// a group left with one exercise dissolves, and every group is named by its count.
func tidyGroups<L: GroupedExercises>(_ w: L) -> L {
    var w = w
    let n = w.items.count
    // Each group's runs of consecutive members; only the longest stays in the group.
    var runs: [String: [Range<Int>]] = [:]
    var i = 0
    while i < n {
        guard let g = w.items[i].groupId else { i += 1; continue }
        var j = i
        while j < n, w.items[j].groupId == g { j += 1 }
        runs[g, default: []].append(i..<j)
        i = j
    }
    for (_, rs) in runs {
        let keep = rs.firstIndex { $0.count == rs.map(\.count).max() } ?? 0
        for (k, r) in rs.enumerated() where k != keep { for x in r { w.items[x].groupId = nil } }
    }
    var counts: [String: Int] = [:]
    for it in w.items { if let g = it.groupId { counts[g, default: 0] += 1 } }
    for x in w.items.indices { if let g = w.items[x].groupId, counts[g, default: 0] < 2 { w.items[x].groupId = nil } }
    w.groups = w.groups.compactMap { g in
        guard let c = counts[g.id], c >= 2 else { return nil }
        return ExerciseGroup(id: g.id, type: .forCount(c))
    }
    return w
}

/// A drag. The moved exercise joins a group when dropped between two of its members,
/// stays in its own group while it still touches it, and otherwise leaves it.
/// A routine exercise in a list, with an id that stays with it when it moves. Routine items have
/// no id of their own, so it is the variation and style, plus a count when the same one is in twice.
struct RoutineRow: Identifiable, Hashable {
    let id: String
    let index: Int
    let item: RoutineItem
}

func routineRows(_ items: [RoutineItem]) -> [RoutineRow] {
    var seen: [String: Int] = [:]
    return items.enumerated().map { i, item in
        let key = item.versionId + "|" + (item.styleId ?? "")
        seen[key, default: 0] += 1
        return RoutineRow(id: key + "#\(seen[key]!)", index: i, item: item)
    }
}

func moveItem<L: GroupedExercises>(_ w: L, from: IndexSet, to: Int) -> L {
    var w = w
    // The same as List's move(fromOffsets:toOffset:), which lives in SwiftUI.
    let picked = from.map { w.items[$0] }
    for i in from.reversed() { w.items.remove(at: i) }
    let at = to - from.filter { $0 < to }.count
    w.items.insert(contentsOf: picked, at: at)
    for i in at..<(at + picked.count) {
        let prev = i > 0 ? w.items[i - 1].groupId : nil
        let next = i + 1 < w.items.count ? w.items[i + 1].groupId : nil
        if let g = prev, g == next { w.items[i].groupId = g }
        else if let g = w.items[i].groupId, g != prev, g != next { w.items[i].groupId = nil }
    }
    return tidyGroups(w)
}

/// The ticked loose exercises (by place in the list) become one group, pulled together at the
/// first one's place.
func makeGroup<L: GroupedExercises>(_ w: L, at ticked: Set<Int>) -> L {
    var w = w
    let idxs = ticked.filter { w.items.indices.contains($0) }.sorted()
    guard idxs.count >= 2, let at = idxs.first else { return w }
    let gid = uid()
    let chosen: [L.Item] = idxs.map { i in
        var it = w.items[i]
        it.groupId = gid
        return it
    }
    for i in idxs.reversed() { w.items.remove(at: i) }
    w.items.insert(contentsOf: chosen, at: min(at, w.items.count))
    w.groups.append(ExerciseGroup(id: gid, type: .forCount(chosen.count)))
    return tidyGroups(w)
}

/// One exercise and whether it was ticked, so the tick follows it while the list is rearranged.
private struct Ticked<Item> {
    var item: Item
    var on: Bool
}

/// The ticked exercises (by place in the list) leave their groups. If two or more stay, they keep
/// together and the ones leaving sit just below them, in order; otherwise the group dissolves
/// where it is.
func ungroup<L: GroupedExercises>(_ w: L, at ticked: Set<Int>) -> L {
    var w = w
    var rows = w.items.indices.map { Ticked(item: w.items[$0], on: ticked.contains($0)) }
    var gids: [String] = []
    for r in rows where r.on {
        if let g = r.item.groupId, !gids.contains(g) { gids.append(g) }
    }
    for gid in gids {
        let members = rows.filter { $0.item.groupId == gid }
        let leaving = members.filter { $0.on }
        if members.count - leaving.count < 2 {
            for x in rows.indices where rows[x].item.groupId == gid { rows[x].item.groupId = nil }
            continue
        }
        rows.removeAll { $0.item.groupId == gid && $0.on }
        let end = (rows.lastIndex { $0.item.groupId == gid } ?? -1) + 1
        let freed = leaving.map { r -> Ticked<L.Item> in
            var r = r
            r.item.groupId = nil
            return r
        }
        rows.insert(contentsOf: freed, at: end)
    }
    w.items = rows.map(\.item)
    return tidyGroups(w)
}

/// Overview ticks by exercise id, since its exercises carry one.
func makeGroup(_ w: Workout, ids: Set<String>) -> Workout {
    makeGroup(w, at: Set(w.items.indices.filter { ids.contains(w.items[$0].id) }))
}

func ungroup(_ w: Workout, ids: Set<String>) -> Workout {
    ungroup(w, at: Set(w.items.indices.filter { ids.contains(w.items[$0].id) }))
}

/// Where ticks (by place in the list) end up after a drag, so they follow their exercises.
func ticksAfterMove(_ ticked: Set<Int>, count: Int, from: IndexSet, to: Int) -> Set<Int> {
    var order = Array(0..<count)
    let picked = from.filter { $0 < count }.map { order[$0] }
    for i in from.filter({ $0 < count }).reversed() { order.remove(at: i) }
    order.insert(contentsOf: picked, at: min(to - from.filter { $0 < to && $0 < count }.count, order.count))
    return Set(order.indices.filter { ticked.contains(order[$0]) })
}

/// Where ticks (by place in the list) end up after rows are deleted: the deleted ones go, the
/// rest shift up.
func ticksAfterDelete(_ ticked: Set<Int>, deleted: IndexSet) -> Set<Int> {
    Set(ticked.filter { !deleted.contains($0) }.map { i in i - deleted.filter { $0 < i }.count })
}
