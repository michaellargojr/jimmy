import CoreGraphics
import Testing
@testable import Jimmy

// Swiping between exercises on the Workout page: one exercise per swipe with a light touch,
// and a long exercise scrolls to its end before the next swipe moves on.

private let page: CGFloat = 600   // nudge 72, magnet 60

private func rest(_ start: CGFloat, _ coast: CGFloat, _ heights: [CGFloat]) -> CGFloat {
    PaneSnap.rest(start: start, coast: coast, heights: heights, page: page)
}

@Suite struct PaneSnapShortTests {
    let three: [CGFloat] = [600, 600, 600]

    @Test func aLightFlickMovesToTheNextExercise() {
        #expect(rest(0, 100, three) == 600)
        #expect(rest(600, 700, three) == 1200)
    }

    @Test func aSmallDragSpringsBack() {
        #expect(rest(0, 50, three) == 0)
        #expect(rest(600, 560, three) == 600)
    }

    @Test func backUpLandsOnTheOneBefore() {
        #expect(rest(600, 450, three) == 0)
        #expect(rest(1200, 1000, three) == 600)
    }

    @Test func aHardFlickStillMovesOnlyOne() {
        #expect(rest(0, 5000, three) == 600)
        #expect(rest(1200, -3000, three) == 600)
    }

    @Test func theEndsStayPut() {
        #expect(rest(0, -200, three) == 0)
        #expect(rest(1200, 1500, three) == 1200)
    }

    @Test func aPaneShorterThanTheScreenCountsAsAScreen() {
        // Unmeasured (0) or short, each still fills a page.
        #expect(rest(0, 100, [0, 0]) == 600)
        #expect(rest(0, 100, [350, 400]) == 600)
    }
}

@Suite struct PaneSnapTallTests {
    // The first exercise runs 300 past the screen: its end sits at 300, the next title at 900.
    let tall: [CGFloat] = [900, 600]

    @Test func insideALongExerciseItScrollsFreely() {
        #expect(rest(0, 150, tall) == 150)
        #expect(rest(200, 120, tall) == 120)
    }

    @Test func aFlickStopsAtItsEndBeforeMovingOn() {
        #expect(rest(0, 2000, tall) == 300)
        #expect(rest(150, 2000, tall) == 300)
        #expect(rest(300, 400, tall) == 900)
    }

    @Test func comingToRestNearAnEdgeSettlesOnIt() {
        #expect(rest(0, 260, tall) == 300)
        #expect(rest(200, 40, tall) == 0)
    }

    @Test func fromTheMiddleItNeverSkipsBack() {
        #expect(rest(150, -500, tall) == 0)
    }

    @Test func backFromTheNextLandsOnTheTitle() {
        #expect(rest(900, 800, tall) == 0)
        #expect(rest(900, 870, tall) == 900)
    }
}

@Suite struct PaneSnapBetweenTests {
    let three: [CGFloat] = [600, 600, 600]

    @Test func caughtBetweenTwoItCarriesOnTheWayItWasGoing() {
        #expect(rest(900, 950, three) == 1200)
        #expect(rest(900, 850, three) == 600)
    }

    @Test func letGoBetweenTwoItSettlesOnTheNearer() {
        #expect(rest(700, 700, three) == 600)
        #expect(rest(1100, 1100, three) == 1200)
    }

    @Test func nothingToSnapToLeavesTheSwipeAlone() {
        #expect(PaneSnap.rest(start: 0, coast: 120, heights: [], page: 600) == 120)
        #expect(PaneSnap.rest(start: 0, coast: 120, heights: [600], page: 0) == 120)
    }
}

@Suite struct PaneSnapGapTests {
    // 120 of empty space under each pane, so the next title never shows through the tab bar.
    private func rest(_ start: CGFloat, _ coast: CGFloat, _ heights: [CGFloat]) -> CGFloat {
        PaneSnap.rest(start: start, coast: coast, heights: heights, page: 600, gap: 120)
    }
    let three: [CGFloat] = [600, 600, 600]

    @Test func swipesStepOverTheGap() {
        #expect(rest(0, 100, three) == 720)
        #expect(rest(720, 600, three) == 0)
        #expect(rest(1440, 1700, three) == 1440)
    }

    @Test func aLongExerciseStillStopsAtItsEndFirst() {
        #expect(rest(0, 2000, [900, 600]) == 300)
        #expect(rest(300, 400, [900, 600]) == 1020)
        #expect(rest(1020, 900, [900, 600]) == 0)
    }

    @Test func letGoInTheGapItSettlesOnTheNearer() {
        #expect(rest(300, 300, three) == 0)
        #expect(rest(500, 500, three) == 720)
    }
}

@Suite struct PaneSnapSliverTests {
    // An exercise only 10 taller than the screen: one swipe still moves on, it doesn't stop for 10 points.
    let sliver: [CGFloat] = [610, 600, 600]

    @Test func oneSwipePassesAShortOverhang() {
        #expect(rest(0, 220, sliver) == 610)
    }

    @Test func aSmallDragStillShowsTheLastFewPoints() {
        #expect(rest(0, 30, sliver) == 10)
    }

    @Test func backFromItsEndGoesToTheOneBefore() {
        #expect(rest(610, 450, [600, 610, 600]) == 0)
    }

    @Test func nearTheEndOfALongExerciseCountsAsTheEnd() {
        #expect(rest(250, 400, [900, 600]) == 900)
        #expect(rest(250, 280, [900, 600]) == 300)
    }
}
