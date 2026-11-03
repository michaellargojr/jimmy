import Foundation
import Testing
@testable import Jimmy

// A routine's page groups the way the Workout page's Overview does: tick boxes, then
// Make a superset or Ungroup. Ticks are by place in the list, since routine rows carry no id.

private func item(_ v: String, _ g: String? = nil) -> RoutineItem {
    RoutineItem(versionId: v, groupId: g)
}

private func routine(_ items: [RoutineItem]) -> Routine {
    let ids = items.compactMap(\.groupId).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    return Routine(name: "Push", items: items, groups: ids.map { ExerciseGroup(id: $0, type: .circuit) })
}

private func order(_ r: Routine) -> [String] { r.items.map(\.versionId) }
private func group(_ r: Routine, _ v: String) -> String? { r.items.first { $0.versionId == v }?.groupId }

@Suite struct RoutineGroupingTests {
    @Test func twoTickedLooseOnesMakeASuperset() {
        let r = makeGroup(routine([item("a"), item("b"), item("c"), item("d")]), at: [1, 3])
        #expect(order(r) == ["a", "b", "d", "c"])
        #expect(group(r, "b") != nil && group(r, "b") == group(r, "d"))
        #expect(r.groups.count == 1 && r.groups.first?.type == .superset)
    }

    @Test func oneTickedIsNotAGroup() {
        let r0 = routine([item("a"), item("b")])
        #expect(makeGroup(r0, at: [0]) == r0)
    }

    @Test func ungroupingOneOfASupersetDissolvesIt() {
        let r = ungroup(routine([item("a", "g"), item("b", "g"), item("c")]), at: [0])
        #expect(order(r) == ["a", "b", "c"])
        #expect(r.items.allSatisfy { $0.groupId == nil })
        #expect(r.groups.isEmpty)
    }

    @Test func ungroupingTheMiddleOfATrisetLeavesASuperset() {
        let r = ungroup(routine([item("a", "g"), item("b", "g"), item("c", "g"), item("d")]), at: [1])
        #expect(order(r) == ["a", "c", "b", "d"])
        #expect(group(r, "b") == nil)
        #expect(r.groups.first?.type == .superset)
    }

    @Test func aLooseOneDroppedInsideAGroupJoinsIt() {
        let r = moveItem(routine([item("a", "g"), item("b", "g"), item("x")]), from: [2], to: 1)
        #expect(order(r) == ["a", "x", "b"])
        #expect(group(r, "x") == "g")
        #expect(r.groups.first?.type == .triset)
    }

    @Test func aMemberDraggedAwayLeavesItsGroup() {
        let r = moveItem(routine([item("a", "g"), item("b", "g"), item("x")]), from: [0], to: 3)
        #expect(order(r) == ["b", "x", "a"])
        #expect(r.items.allSatisfy { $0.groupId == nil })
    }

    @Test func aLoneLeftoverIsNotShownAsAGroup() {
        let r = routine([item("a", "g"), item("b")])
        #expect(r.liveGroup(at: 0) == nil)
        #expect(r.groupPlace(at: 0).group == nil)
    }

    @Test func membersAreNumberedAndShareOneCard() {
        let r = routine([item("x"), item("a", "g"), item("b", "g"), item("c", "g")])
        let p = (1...3).map { r.groupPlace(at: $0) }
        #expect(p.map { $0.number } == [1, 2, 3])
        #expect(p.allSatisfy { $0.members == 3 })
        #expect(p.map { $0.first } == [true, false, false])
        #expect(p.map { $0.last } == [false, false, true])
        #expect(r.groupPlace(at: 0).first && r.groupPlace(at: 0).last)
    }

    @Test func ticksFollowTheirRowsWhenDragged() {
        // Rows a b c d, b and d ticked; d dragged to the top.
        #expect(ticksAfterMove([1, 3], count: 4, from: [3], to: 0) == [0, 2])
        // a dragged to the end.
        #expect(ticksAfterMove([0], count: 3, from: [0], to: 3) == [2])
    }

    @Test func ticksShiftUpWhenARowIsDeleted() {
        #expect(ticksAfterDelete([0, 2, 3], deleted: [2]) == [0, 2])
    }

    @Test func theSplitSheetsDraftGroupsAndKeepsItsRows() {
        let r = routine([item("a"), item("b"), item("c")])
        var d = RoutineDraft(r)
        let ids = d.rows.map(\.id)
        d.groupable = makeGroup(d.groupable, at: [0, 2])
        #expect(d.rows.map(\.id) == [ids[0], ids[2], ids[1]])
        #expect(d.groupable.liveGroup(at: 0) != nil && d.groupable.liveGroup(at: 0) == d.groupable.liveGroup(at: 1))
        #expect(d.groups.count == 1 && d.groups.first?.type == .superset)
        #expect(!d.matches(r))
        d.groupable = ungroup(d.groupable, at: [1])
        #expect(d.items.allSatisfy { $0.groupId == nil })
        #expect(d.groups.isEmpty)
    }
}
