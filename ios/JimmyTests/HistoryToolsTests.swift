import Foundation
import Testing
@testable import Jimmy

// Copy, move and erase a variation's history from its history page.

private func S(_ weight: Double, _ reps: Int?, _ kind: SetKind = .working) -> SetEntry {
    SetEntry(kind: kind, unit: .kg, weight: weight, reps: reps)
}

private func finished(_ date: String, _ items: [WorkoutItem]) -> Workout {
    Workout(name: "Shoulders", date: date, startedAt: 1, endedAt: 2, items: items)
}

@Suite struct HistoryToolsTests {
    let press = "press", raise = "raise", other = "other"

    private func state() -> HistoryState {
        let w1 = finished("2026-09-09", [WorkoutItem(versionId: press, sets: [S(15, 10, .warmup), S(30, 8), S(30, 6)]),
                                          WorkoutItem(versionId: other, sets: [S(20, 10)])])
        let w2 = finished("2026-10-10", [WorkoutItem(versionId: press, sets: [S(30, 6), S(30, 7)])])
        let active = Workout(name: "Now", startedAt: 3, items: [WorkoutItem(versionId: press, sets: [S(30, nil)])])
        let routine = Routine(name: "Shoulders", items: [RoutineItem(versionId: press), RoutineItem(versionId: other)])
        return HistoryState(workouts: [w1, w2, active], routines: [routine], styles: [], watchVersionId: press)
    }

    @Test func copyKeepsBoth() {
        let s = copyingHistory(state(), from: press, to: raise, move: false)
        #expect(historySessions(press, workouts: s.workouts).count == 2)
        #expect(historySessions(raise, workouts: s.workouts).count == 2)
        // Same sets, new ids, sitting right after the original.
        let w1 = s.workouts[0]
        #expect(w1.items.map(\.versionId) == [press, raise, other])
        #expect(w1.items[1].sets.map(\.reps) == [10, 8, 6])
        #expect(Set(w1.items[1].sets.map(\.id)).isDisjoint(with: w1.items[0].sets.map(\.id)))
        // Routines and the watched exercise stay put on a copy.
        #expect(s.routines[0].items.map(\.versionId) == [press, other])
        #expect(s.watchVersionId == press)
    }

    @Test func moveLeavesNothingBehind() {
        let s = copyingHistory(state(), from: press, to: raise, move: true)
        #expect(historySessions(press, workouts: s.workouts).isEmpty)
        #expect(historySessions(raise, workouts: s.workouts).map(\.date) == ["2026-09-09", "2026-10-10"])
        #expect(s.workouts[0].items.map(\.versionId) == [raise, other])
        #expect(s.routines[0].items.map(\.versionId) == [raise, other])
        #expect(s.watchVersionId == raise)
    }

    @Test func workoutInProgressIsLeftAlone() {
        let before = state()
        for s in [copyingHistory(before, from: press, to: raise, move: true), erasingHistory(before, versionId: press)] {
            let now = s.workouts.first { !$0.isFinished }
            #expect(now == before.workouts[2])
        }
    }

    @Test func sameDayTargetGetsTheSetsAdded() {
        var s0 = state()
        s0.workouts[1].items.append(WorkoutItem(versionId: raise, sets: [S(10, 12)]))
        let s = copyingHistory(s0, from: press, to: raise, move: true)
        let w2 = s.workouts[1]
        #expect(w2.items.count == 1)
        #expect(w2.items[0].versionId == raise)
        #expect(w2.items[0].sets.map(\.reps) == [12, 6, 7])
    }

    @Test func stylesFollowTheirMatchOrAreMade() {
        var s0 = state()
        let rope = Style(versionId: press, attachment: "rope")
        let ropeOnRaise = Style(versionId: raise, attachment: "rope")
        let bench = Style(versionId: press, benchAngle: 45)
        s0.styles = [rope, ropeOnRaise, bench]
        s0.workouts[0].items[0].styleId = rope.id
        s0.workouts[1].items[0].styleId = bench.id
        let s = copyingHistory(s0, from: press, to: raise, move: true)
        #expect(s.workouts[0].items[0].styleId == ropeOnRaise.id)
        let made = s.styles.first { $0.versionId == raise && $0.benchAngle == 45 }
        #expect(made != nil)
        #expect(s.workouts[1].items[0].styleId == made?.id)
        // A picked style wins over all of them.
        let picked = copyingHistory(s0, from: press, to: raise, styleId: ropeOnRaise.id, move: true)
        #expect(picked.workouts.filter(\.isFinished).flatMap(\.items).filter { $0.versionId == raise }.allSatisfy { $0.styleId == ropeOnRaise.id })
    }

    @Test func eraseDropsEmptyWorkouts() {
        let s = erasingHistory(state(), versionId: press)
        #expect(historySessions(press, workouts: s.workouts).isEmpty)
        // Sep 9 keeps the other exercise; Oct 10 had only the press, so it goes.
        #expect(s.workouts.filter(\.isFinished).map(\.date) == ["2026-09-09"])
        #expect(s.workouts[0].items.map(\.versionId) == [other])
        #expect(s.routines == state().routines)
    }

    @Test func copyOntoItselfChangesNothing() {
        #expect(copyingHistory(state(), from: press, to: press, move: true) == state())
    }

    @Test func undoPutsItBack() {
        let store = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("history-\(uid()).json"))
        let e = Exercise(name: "Shoulder Press", muscleGroup: .Shoulders)
        let from = Version(id: press, exerciseId: e.id, name: "x", equipment: .machine, arms: .two)
        let to = Version(id: raise, exerciseId: e.id, name: "y", equipment: .machine, arms: .two)
        let s = state()
        store.exercises = [e]; store.versions = [from, to]
        store.workouts = s.workouts; store.routines = s.routines; store.settings.watchVersionId = press
        store.copyHistory(from: from, to: to, move: true)
        #expect(store.historyUndo?.message == "Moved 2 sessions")
        #expect(store.historyUndo?.landedOn == raise)
        store.undoHistory()
        #expect(store.historyState == s)
        #expect(store.historyUndo == nil)
        store.eraseHistory(from)
        #expect(store.historyUndo?.message == "Erased 2 sessions")
        #expect(historySessions(press, workouts: store.workouts).isEmpty)
    }
}
