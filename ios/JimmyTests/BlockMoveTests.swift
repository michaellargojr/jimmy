import Foundation
import Testing
@testable import Jimmy

// A group moves as one: holding its header drags every member together, and a member's handle
// only reorders it inside its group. Loose exercises move between groups, never into one.

private func item(_ v: String, _ g: String? = nil) -> RoutineItem {
    RoutineItem(versionId: v, groupId: g)
}

private func routine(_ items: [RoutineItem]) -> Routine {
    let ids = items.compactMap(\.groupId).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    return Routine(name: "Push", items: items, groups: ids.map { ExerciseGroup(id: $0, type: .superset) })
}

private func order(_ r: Routine) -> [String] { r.items.map(\.versionId) }
private func group(_ r: Routine, _ v: String) -> String? { r.items.first { $0.versionId == v }?.groupId }

@Suite struct BlockMoveTests {
    @Test func aGroupIsOneBlock() {
        let r = routine([item("a"), item("b", "g"), item("c", "g"), item("d")])
        #expect(r.blocks == [ExerciseBlock(range: 0..<1, group: nil), ExerciseBlock(range: 1..<3, group: "g"),
                             ExerciseBlock(range: 3..<4, group: nil)])
    }

    @Test func aLoneMemberIsLoose() {
        let r = Routine(name: "Push", items: [item("a", "g"), item("b")], groups: [])
        #expect(r.blocks.allSatisfy { $0.group == nil })
        #expect(r.blocks.count == 2)
    }

    @Test func draggingTheHeaderMovesTheWholeGroup() {
        let r = moveBlocks(routine([item("a"), item("b", "g"), item("c", "g"), item("d")]), from: [1], to: 0)
        #expect(order(r) == ["b", "c", "a", "d"])
        #expect(group(r, "b") == "g" && group(r, "c") == "g")
        #expect(r.groups.count == 1)
    }

    @Test func aGroupMovesToTheEnd() {
        let r = moveBlocks(routine([item("a", "g"), item("b", "g"), item("c"), item("d")]), from: [0], to: 3)
        #expect(order(r) == ["c", "d", "a", "b"])
        #expect(group(r, "a") == "g" && group(r, "b") == "g")
    }

    @Test func aLooseExerciseSkipsOverAGroup() {
        let r = moveBlocks(routine([item("a"), item("b", "g"), item("c", "g"), item("d")]), from: [0], to: 2)
        #expect(order(r) == ["b", "c", "a", "d"])
        #expect(group(r, "a") == nil)
        #expect(group(r, "b") == "g" && group(r, "c") == "g")
    }

    @Test func twoGroupsSwap() {
        let r = moveBlocks(routine([item("a", "g"), item("b", "g"), item("c", "h"), item("d", "h"), item("e", "h")]), from: [1], to: 0)
        #expect(order(r) == ["c", "d", "e", "a", "b"])
        #expect(r.groups.first { $0.id == "h" }?.type == .triset)
    }

    @Test func aMemberReordersInsideItsGroup() {
        let r = moveMember(routine([item("a"), item("b", "g"), item("c", "g"), item("d", "g")]), from: 1, to: 3)
        #expect(order(r) == ["a", "c", "d", "b"])
        #expect(["b", "c", "d"].allSatisfy { group(r, $0) == "g" })
    }

    @Test func aMemberCannotLeaveItsGroup() {
        let r0 = routine([item("a"), item("b", "g"), item("c", "g")])
        #expect(moveMember(r0, from: 1, to: 0) == r0)
    }

    @Test func ticksFollowTheirExercises() {
        let blocks = routine([item("a"), item("b", "g"), item("c", "g"), item("d")]).blocks
        // a and d ticked; the group moves to the top.
        #expect(ticks([0, 3], after: orderAfterBlockMove(blocks, from: [1], to: 0)) == [2, 3])
        // b ticked; it moves to the end of its group.
        #expect(ticks([1], after: orderAfterMemberMove(count: 4, from: 1, to: 2)) == [2])
    }

    @Test func overviewGroupsMoveTheSameWay() {
        var w = Workout(name: "Push", items: [WorkoutItem(versionId: "a", sets: []),
                                              WorkoutItem(versionId: "b", groupId: "g", sets: []),
                                              WorkoutItem(versionId: "c", groupId: "g", sets: [])])
        w.groups = [ExerciseGroup(id: "g", type: .superset)]
        let moved = moveBlocks(w, from: [1], to: 0)
        #expect(moved.items.map(\.versionId) == ["b", "c", "a"])
    }
}
