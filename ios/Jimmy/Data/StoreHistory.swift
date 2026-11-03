import Foundation

// Copy, move and erase history on the store (see Model/HistoryTools.swift for the rules).

extension AppStore {
    var historyState: HistoryState {
        HistoryState(workouts: workouts, routines: routines, styles: styles, watchVersionId: settings.watchVersionId)
    }

    /// A workout in progress always stays as it is now, so Undo never takes back sets logged since.
    private func setHistory(_ s: HistoryState) {
        workouts = s.workouts.filter { $0.isFinished } + workouts.filter { !$0.isFinished }
        routines = s.routines
        styles = s.styles
        settings.watchVersionId = s.watchVersionId
        markDirty()
    }

    func copyHistory(from: Version, to: Version, styleId: String? = nil, move: Bool) {
        let before = historyState
        let n = historySessions(from.id, workouts: workouts).count
        setHistory(copyingHistory(before, from: from.id, to: to.id, styleId: styleId, move: move))
        historyUndo = HistoryUndo(kind: move ? .move : .copy, message: "\(move ? "Moved" : "Copied") \(sessionsText(n))", before: before, landedOn: to.id)
    }

    func eraseHistory(_ v: Version) {
        let before = historyState
        let n = historySessions(v.id, workouts: workouts).count
        setHistory(erasingHistory(before, versionId: v.id))
        historyUndo = HistoryUndo(kind: .erase, message: "Erased \(sessionsText(n))", before: before, landedOn: v.id)
    }

    func undoHistory() {
        guard let u = historyUndo else { return }
        setHistory(u.before)
        historyUndo = nil
    }
}
