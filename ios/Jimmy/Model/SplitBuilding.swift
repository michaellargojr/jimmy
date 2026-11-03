import Foundation

// Putting a split together: a routine built from exercises already in other routines, and the
// order of the split page.

/// One ticked exercise: which routine, and its spot in that routine's list.
struct RoutinePick: Hashable {
    var routineId: String
    var index: Int
}

/// Exercises picked out of other routines, ready to join the routine being built.
struct PickedExercises: Equatable {
    var items: [RoutineItem] = []
    var groups: [ExerciseGroup] = []
    var isEmpty: Bool { items.isEmpty }
}

/// The ticked exercises as rows for the routine being built: each routine's picks in that
/// routine's order, routines in the order given. A superset, triset or circuit whose members were
/// all ticked stays one, under a fresh group id; one ticked only in part comes apart.
func pickedExercises(from routines: [Routine], picks: Set<RoutinePick>) -> PickedExercises {
    var out = PickedExercises()
    for r in routines {
        let chosen = r.items.indices.filter { picks.contains(RoutinePick(routineId: r.id, index: $0)) }
        guard !chosen.isEmpty else { continue }
        var fresh: [String: String] = [:]
        for g in r.groups {
            let members = r.items.indices.filter { r.items[$0].groupId == g.id }
            guard members.count > 1, members.allSatisfy({ chosen.contains($0) }) else { continue }
            let id = uid()
            fresh[g.id] = id
            out.groups.append(ExerciseGroup(id: id, type: g.type))
        }
        for i in chosen {
            var item = r.items[i]
            item.groupId = item.groupId.flatMap { fresh[$0] }
            out.items.append(item)
        }
    }
    return out
}

extension Routine {
    /// Picked exercises join at the end, their kept groups with them.
    mutating func add(_ picked: PickedExercises) {
        items.append(contentsOf: picked.items)
        groups.append(contentsOf: picked.groups)
    }
}

extension RoutineDraft {
    /// Picked exercises join the sheet at the end, their kept groups with them.
    mutating func add(_ picked: PickedExercises) {
        for item in picked.items { append(item) }
        groups.append(contentsOf: picked.groups)
    }
}

/// The parts of the split page, top to bottom.
enum SplitSection: Hashable {
    case goals, inSplit, coverage, use, notes
}

/// The split page (Michael, Nov 2): its routines first, under a big "In this split" with Edit;
/// then Goals right above Coverage; Notes at the very bottom. Use this split shows only while it
/// isn't the active one. New routine and Add an existing routine live in the Edit split sheet.
func splitSections(active: Bool) -> [SplitSection] {
    active ? [.inSplit, .goals, .coverage, .notes]
           : [.inSplit, .goals, .coverage, .use, .notes]
}
