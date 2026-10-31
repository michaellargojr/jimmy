import Foundation
import Testing
@testable import Jimmy

// Overview: grouping by ticking boxes, ungrouping, reordering, and group names from the count.

private func item(_ id: String, _ g: String? = nil) -> WorkoutItem {
    WorkoutItem(id: id, versionId: "v", groupId: g, sets: [])
}

private func workout(_ items: [WorkoutItem]) -> Workout {
    let ids = items.compactMap(\.groupId).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    return Workout(name: "Shoulders", items: items, groups: ids.map { ExerciseGroup(id: $0, type: .circuit) })
}

private func order(_ w: Workout) -> [String] { w.items.map(\.id) }
private func groupOf(_ w: Workout, _ id: String) -> String? { w.items.first { $0.id == id }?.groupId }
private func name(_ w: Workout, _ id: String) -> GroupType? {
    groupOf(w, id).flatMap { g in w.groups.first { $0.id == g }?.type }
}

@Suite struct GroupNameTests {
    @Test func namedByCount() {
        #expect(GroupType.forCount(2) == .superset)
        #expect(GroupType.forCount(3) == .triset)
        #expect(GroupType.forCount(4) == .circuit)
        #expect(GroupType.forCount(6) == .circuit)
    }

    @Test func aStoredNameFollowsTheCount() {
        // Seeded as a circuit, but only two exercises: a superset.
        let w = tidyGroups(workout([item("a", "g"), item("b", "g"), item("c")]))
        #expect(name(w, "a") == .superset)
    }
}

@Suite struct OverviewGroupingTests {
    @Test func twoTickedLooseOnesMakeASuperset() {
        let w = makeGroup(workout([item("a"), item("b"), item("c"), item("d")]), ids: ["b", "d"])
        #expect(order(w) == ["a", "b", "d", "c"])           // pulled together at the first one's place
        #expect(groupOf(w, "b") != nil && groupOf(w, "b") == groupOf(w, "d"))
        #expect(name(w, "b") == .superset)
        #expect(w.groups.count == 1)
    }

    @Test func threeMakeATriset() {
        let w = makeGroup(workout([item("a"), item("b"), item("c")]), ids: ["a", "b", "c"])
        #expect(name(w, "a") == .triset)
    }

    @Test func oneTickedIsNotAGroup() {
        let w0 = workout([item("a"), item("b")])
        #expect(makeGroup(w0, ids: ["a"]) == w0)
    }

    @Test func ungroupingOneOfASupersetDissolvesIt() {
        let w = ungroup(workout([item("a", "g"), item("b", "g"), item("c")]), ids: ["a"])
        #expect(order(w) == ["a", "b", "c"])                // stays in place
        #expect(w.items.allSatisfy { $0.groupId == nil })
        #expect(w.groups.isEmpty)
    }

    @Test func ungroupingTheMiddleOfATrisetLeavesASuperset() {
        let w = ungroup(workout([item("a", "g"), item("b", "g"), item("c", "g"), item("d")]), ids: ["b"])
        #expect(order(w) == ["a", "c", "b", "d"])           // b sits just below what's left
        #expect(groupOf(w, "a") == "g" && groupOf(w, "c") == "g" && groupOf(w, "b") == nil)
        #expect(name(w, "a") == .superset)
    }

    @Test func ungroupingTwoOfACircuitKeepsTheirOrder() {
        let w = ungroup(workout([item("a", "g"), item("b", "g"), item("c", "g"), item("d", "g")]), ids: ["a", "c"])
        #expect(order(w) == ["b", "d", "a", "c"])
        #expect(name(w, "b") == .superset && groupOf(w, "a") == nil)
    }
}

@Suite struct OverviewReorderTests {
    @Test func aMemberDraggedAwayLeavesItsGroup() {
        // a, [b c d], e: drag d to the end.
        var w = workout([item("a"), item("b", "g"), item("c", "g"), item("d", "g"), item("e")])
        w = moveItem(w, from: [3], to: 5)
        #expect(order(w) == ["a", "b", "c", "e", "d"])
        #expect(groupOf(w, "d") == nil && name(w, "b") == .superset)
    }

    @Test func draggedToTheTopTheLongerRunKeepsTheGroup() {
        var w = workout([item("x"), item("a", "g"), item("b", "g"), item("c", "g")])
        w = moveItem(w, from: [3], to: 0)
        #expect(order(w) == ["c", "x", "a", "b"])
        #expect(groupOf(w, "c") == nil && groupOf(w, "a") == "g" && groupOf(w, "b") == "g")
    }

    @Test func aLooseOneDroppedInsideAGroupJoinsIt() {
        var w = workout([item("a", "g"), item("b", "g"), item("x")])
        w = moveItem(w, from: [2], to: 1)
        #expect(order(w) == ["a", "x", "b"])
        #expect(groupOf(w, "x") == "g" && name(w, "a") == .triset)
    }

    @Test func movingWithinAGroupKeepsIt() {
        var w = workout([item("a", "g"), item("b", "g"), item("c")])
        w = moveItem(w, from: [1], to: 0)
        #expect(order(w) == ["b", "a", "c"])
        #expect(groupOf(w, "a") == "g" && groupOf(w, "b") == "g")
    }

    @Test func droppedNextToAGroupStaysLoose() {
        var w = workout([item("a", "g"), item("b", "g"), item("x"), item("y")])
        w = moveItem(w, from: [3], to: 2)                    // y lands right below b
        #expect(order(w) == ["a", "b", "y", "x"])
        #expect(groupOf(w, "y") == nil && name(w, "a") == .superset)
    }

    @Test func aMemberDroppedInsideAnotherGroupJoinsThatOne() {
        var w = workout([item("a", "g"), item("b", "g"), item("c", "h"), item("d", "h"), item("e", "h")])
        w = moveItem(w, from: [0], to: 4)                    // a lands between d and e
        #expect(order(w) == ["b", "c", "d", "a", "e"])
        #expect(groupOf(w, "a") == "h" && groupOf(w, "b") == nil && name(w, "c") == .circuit)
        #expect(w.groups.count == 1)
    }

    @Test func aSplitGroupKeepsItsLongestRun() {
        // Older data with a group broken in two.
        let w = tidyGroups(workout([item("a", "g"), item("x"), item("b", "g"), item("c", "g")]))
        #expect(groupOf(w, "a") == nil && groupOf(w, "b") == "g" && groupOf(w, "c") == "g")
    }

    @Test func neighbouringGroupsStaySeparate() {
        let w = tidyGroups(workout([item("a", "g"), item("b", "g"), item("c", "h"), item("d", "h")]))
        #expect(groupOf(w, "b") == "g" && groupOf(w, "c") == "h")
        #expect(w.groups.count == 2)
    }

    @Test func deletingFromASupersetDissolvesIt() {
        var w = workout([item("a", "g"), item("b", "g"), item("c")])
        w.items.removeAll { $0.id == "a" }
        w = tidyGroups(w)
        #expect(groupOf(w, "b") == nil && w.groups.isEmpty)
    }
}
