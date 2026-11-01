import Foundation

// Duplicate a routine and save edits made from the split page (rules in Model/RoutineCopies.swift).

extension AppStore {
    /// A new routine from the draft, added to the routine list. Splits are left as they are.
    @discardableResult
    func createRoutine(from draft: RoutineDraft) -> Routine {
        let r = draft.routine()
        put(r)
        return r
    }

    /// "Save as new routine" from the split page: the copy takes that spot in the split, and
    /// the original stays in the routine list and any other split.
    @discardableResult
    func saveAsNewRoutine(_ draft: RoutineDraft, splitId: String, slot: Int) -> Routine? {
        guard var s = splits.first(where: { $0.id == splitId }), s.routineIds.indices.contains(slot) else { return nil }
        let before = s
        let r = draft.routine()
        routines.append(r)
        s.replace(at: slot, with: r.id)
        s.noteMadeHere(r.id)
        put(s)
        routineUndo = RoutineUndo(message: "Saved \(r.name)", splitId: splitId, splitBefore: before, createdRoutineId: r.id)
        return r
    }

    /// "Update <routine>": the original changes everywhere it is used. Past workouts never change.
    func updateRoutine(_ draft: RoutineDraft, routineId: String, splitId: String, undoable: Bool = true) {
        guard let old = routine(routineId) else { return }
        var r = draft.routine(id: routineId)
        r.name = old.name
        put(r)
        routineUndo = undoable ? RoutineUndo(message: "Updated \(old.name)", splitId: splitId, routineBefore: old) : nil
    }

    func undoRoutineChange() {
        guard let u = routineUndo else { return }
        if let s = u.splitBefore { put(s) }
        if let r = u.routineBefore { put(r) }
        if let id = u.createdRoutineId { routines.removeAll { $0.id == id }; markDirty() }
        routineUndo = nil
    }
}
