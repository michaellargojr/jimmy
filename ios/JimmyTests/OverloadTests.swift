import Testing
@testable import Jimmy

// The same cases as src/overload.test.ts in the web app.

private func W(_ reps: Int?, _ weight: Double = 30, _ kind: SetKind = .working, plus: Bool = false, side: Side? = nil) -> SetEntry {
    SetEntry(kind: kind, unit: .kg, weight: weight, reps: reps, plus: plus, side: side)
}

@Suite struct VerdictTests {
    @Test func ignoresWarmupsAndEmpty() {
        #expect(verdict([W(20, 10, .warmup)], repMin: 5, repMax: 8) == .none)
        #expect(verdict([], repMin: 5, repMax: 8) == .none)
    }
    @Test func downWhenFirstWorkingSetUnderRange() {
        #expect(verdict([W(20, 10, .warmup), W(4), W(8)], repMin: 5, repMax: 8) == .down)
    }
    @Test func upWhenSet1AtMaxPlus2AndSet2AtMaxMinus1() {
        #expect(verdict([W(10), W(7)], repMin: 5, repMax: 8) == .up)
        #expect(verdict([W(10), W(8)], repMin: 5, repMax: 8) == .up)
        #expect(verdict([W(10), W(6)], repMin: 5, repMax: 8) == .none)
        #expect(verdict([W(9), W(8)], repMin: 5, repMax: 8) == .none)
        #expect(verdict([W(10)], repMin: 5, repMax: 8) == .none)
    }
    @Test func inRangeIsNone() {
        #expect(verdict([W(7), W(6)], repMin: 5, repMax: 8) == .none)
    }
}

@Suite struct ImprovedTests {
    @Test func moreWeightOrSameWeightMoreReps() {
        #expect(improved(now: W(8, 30), last: W(8, 25)))
        #expect(improved(now: W(9, 30), last: W(8, 30)))
        #expect(!improved(now: W(8, 30), last: W(8, 30)))
        #expect(!improved(now: W(8, 30), last: nil))
        #expect(!improved(now: W(nil, 30), last: W(8, 30)))
    }
}

@Suite struct MatchLastTests {
    @Test func pairsByKindOrdinalAndSide() {
        let now = [W(12, 10, .warmup), W(8), W(7)]
        let last = [W(11, 10, .warmup), W(10), W(8)]
        #expect(matchLast(now: now[1], nowAll: now, lastAll: last)?.reps == 10)
        #expect(matchLast(now: now[2], nowAll: now, lastAll: last)?.reps == 8)
        #expect(matchLast(now: now[0], nowAll: now, lastAll: last)?.reps == 11)
        let nowL = [W(5, 30, side: .L), W(4, 30, side: .R)]
        let lastL = [W(7, 30, side: .R), W(6, 30, side: .L)]
        #expect(matchLast(now: nowL[0], nowAll: nowL, lastAll: lastL)?.reps == 6)
    }
}

@Suite struct ParserAndSeedTests {
    @Test func parsesCompactSetLines() {
        let s = parseSetLine("W L 30x15+ p5 # note here")
        #expect(s.kind == .warmup && s.side == .L && s.weight == 30 && s.reps == 15 && s.plus && s.partials == 5 && s.note == "note here")
        let t = parseSetLine("EZ 15x12+")
        #expect(t.bar == .ez && t.weight == 15 && t.reps == 12 && t.plus)
        let u = parseSetLine("-x-")
        #expect(u.weight == nil && u.reps == nil)
    }
    @Test func seedBuildsEverything() {
        let s = buildSeed()
        #expect(s.gyms.count == 2)
        #expect(s.versions.count == 40)
        #expect(s.routines.count == 4)
        #expect(s.workouts.count == 10)
        #expect(s.splits.first?.routineIds.count == 4)
        #expect(s.exercises.count > 100)
    }
    @Test func snapshotRoundTrips() throws {
        let store = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("jimmy-test-\(uid()).json"))
        store.resetToSeed()
        let data = try store.snapshot().encoded()
        let back = try Snapshot.decode(data)
        #expect(back.workouts.count == store.workouts.count)
        #expect(back.versions.count == store.versions.count)
        #expect(back.settings?.quote == DEFAULT_QUOTE)
    }
}
