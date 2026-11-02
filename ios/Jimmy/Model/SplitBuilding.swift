import Foundation

// Putting a split together: a routine built from exercises already in other routines, and the
// order of the split page while the split is new.

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
    case goals, coverage, newRoutine, inSplit, addRoutine
}

/// Coverage is always last (Michael, Nov 2): the routines come first, the numbers after. While a
/// split is being put together (opened with no routines yet) In this split comes before New routine.
func splitSections(creating: Bool) -> [SplitSection] {
    creating ? [.goals, .inSplit, .newRoutine, .addRoutine, .coverage]
             : [.goals, .newRoutine, .inSplit, .addRoutine, .coverage]
}
