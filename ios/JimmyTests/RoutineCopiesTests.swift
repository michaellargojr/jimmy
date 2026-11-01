import Foundation
import Testing
@testable import Jimmy

// Duplicate a routine and save edits made from the split page.

@Suite struct RoutineCopiesTests {
    private func finished(_ date: String, _ routineId: String) -> Workout {
        Workout(name: "W", date: date, routineId: routineId, startedAt: 1, endedAt: 2)
    }

    @Test func copyNames() {
        #expect(copyName("Shoulders", taken: ["Shoulders"]) == "Shoulders 2")
        #expect(copyName("Shoulders", taken: ["Shoulders", "shoulders 2"]) == "Shoulders 3")
        #expect(copyName("Shoulders 2", taken: ["Shoulders", "Shoulders 2"]) == "Shoulders 3")
        #expect(copyName("Push 10", taken: []) == "Push 11")
        #expect(copyName("Biceps, Forearms, Abs", taken: []) == "Biceps, Forearms, Abs 2")
    }

    @Test func removingTidiesGroups() {
        let g = ExerciseGroup(id: "g", type: .superset)
        let r = Routine(name: "Arms", items: [RoutineItem(versionId: "a", groupId: "g"), RoutineItem(versionId: "b", groupId: "g"), RoutineItem(versionId: "c")], groups: [g])
        var d = RoutineDraft(r)
        #expect(d.matches(r))
        d.remove(id: d.rows[1].id)
        // A superset of one is just an exercise again, and the group goes.
        #expect(d.items.map(\.groupId) == [nil, nil])
        #expect(d.groups.isEmpty)
        #expect(!d.matches(r))
    }

    @Test func moveIsSwiftUIsMove() {
        let r = Routine(name: "R", items: ["a", "b", "c", "d"].map { RoutineItem(versionId: $0) })
        var d = RoutineDraft(r)
        d.move(from: [0], to: 3)
        #expect(d.items.map(\.versionId) == ["b", "c", "a", "d"])
        d.move(from: [3], to: 0)
        #expect(d.items.map(\.versionId) == ["d", "b", "c", "a"])
        d.move(from: [0, 1], to: 4)
        #expect(d.items.map(\.versionId) == ["c", "a", "d", "b"])
    }

    @Test func copyGetsFreshIdsUpdateKeepsIt() {
        let g = ExerciseGroup(id: "g", type: .superset)
        let r = Routine(id: "r1", name: "Arms", items: [RoutineItem(versionId: "a", groupId: "g"), RoutineItem(versionId: "b", groupId: "g")], groups: [g])
        let d = RoutineDraft(r, name: "Arms 2")
        let copy = d.routine()
        #expect(copy.id != "r1")
        #expect(copy.name == "Arms 2")
        #expect(copy.groups.count == 1 && copy.groups[0].id != "g")
        #expect(copy.items.allSatisfy { $0.groupId == copy.groups[0].id })
        let same = RoutineDraft(r).routine(id: "r1")
        #expect(same == r)
    }

    @Test func changeWords() {
        let names = ["p": "Shoulder Press", "l": "Lateral Raise", "u": "Upright Row", "a": "Arnold Press"]
        let name = { (i: RoutineItem) in names[i.versionId] ?? "?" }
        let old = ["p", "l", "u"].map { RoutineItem(versionId: $0) }
        #expect(routineChanges(from: old, to: ["p", "l"].map { RoutineItem(versionId: $0) }, name: name) == "Removed Upright Row")
        #expect(routineChanges(from: old, to: ["p", "l", "a"].map { RoutineItem(versionId: $0) }, name: name) == "Removed Upright Row - Added Arnold Press")
        #expect(routineChanges(from: old, to: ["l", "p", "u"].map { RoutineItem(versionId: $0) }, name: name) == "New order")
        // The same exercise twice: dropping the second is not a new order.
        let twice = ["l", "p", "l"].map { RoutineItem(versionId: $0) }
        #expect(routineChanges(from: twice, to: ["l", "p"].map { RoutineItem(versionId: $0) }, name: name) == "Removed Lateral Raise")
    }

    @Test func saveAsNewKeepsUpNextInPlace() {
        // Shoulders, Back, Arms; Shoulders was done last, so Back is up next.
        var s = Split(name: "Cycle", routineIds: ["sh", "bk", "ar"])
        let done = [finished("2026-10-31", "sh"), finished("2026-10-23", "ar")]
        #expect(upNextSlot(in: s, finished: done) == 1)
        s.replace(at: 0, with: "sh2")
        #expect(s.routineIds == ["sh2", "bk", "ar"])
        #expect(s.slotRoutineId(for: "sh") == "sh2")
        #expect(upNextSlot(in: s, finished: done) == 1)
        // A second swap follows the chain.
        s.replace(at: 0, with: "sh3")
        #expect(s.slotRoutineId(for: "sh") == "sh3")
        #expect(upNextSlot(in: s, finished: done) == 1)
        // Adding the original back by hand: it stands for itself again.
        s.add("sh")
        #expect(s.slotRoutineId(for: "sh") == "sh")
    }

    @Test func swapOfOneOfTwoSpotsLeavesNoTrail() {
        var s = Split(name: "PPL", routineIds: ["push", "pull", "legs", "push", "pull", "legs"])
        s.replace(at: 3, with: "push2")
        #expect(s.routineIds == ["push", "pull", "legs", "push2", "pull", "legs"])
        #expect(s.replaced == nil)
        #expect(s.slotRoutineId(for: "push") == "push")
    }

    @Test func whenToAsk() {
        var mine = Split(name: "Mine", routineIds: ["new", "old"])
        mine.noteMadeHere("new")
        let other = Split(name: "Other", routineIds: ["old"])
        // Made on this split page and used nowhere else: saves straight away.
        #expect(!asksBeforeSaving("new", in: mine, splits: [mine, other]))
        // Taken from the routine list: asks.
        #expect(asksBeforeSaving("old", in: mine, splits: [mine, other]))
        // Made here but now in another split too: asks.
        let shared = Split(name: "Shared", routineIds: ["new"])
        #expect(asksBeforeSaving("new", in: mine, splits: [mine, shared]))
    }

    @Test func splitsWithoutTheNewFieldsStillLoad() throws {
        let json = #"{"id":"s","name":"Cycle","routineIds":["a","b"]}"#
        let s = try JSONDecoder().decode(Split.self, from: Data(json.utf8))
        #expect(s.replaced == nil && s.madeHere == nil)
        var t = s
        t.replace(at: 0, with: "a2")
        t.noteMadeHere("a2")
        let back = try JSONDecoder().decode(Split.self, from: JSONEncoder().encode(t))
        #expect(back.replaced == ["a": "a2"])
        #expect(back.madeHere == ["a2"])
    }
}
