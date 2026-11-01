import SwiftUI
import Testing
@testable import Jimmy

// The Workout tile's J: the app icon's shape, fitted into whatever frame it gets.

@Suite struct TabBarTests {
    @Test func theJFillsAFrameOfItsOwnShape() {
        let r = JLogo().path(in: CGRect(x: 0, y: 0, width: 58.4, height: 73)).boundingRect
        #expect(abs(r.minX) < 0.5 && abs(r.minY) < 0.5)
        #expect(abs(r.maxX - 58.4) < 0.5 && abs(r.maxY - 73) < 0.5)
    }

    @Test func theJStaysCenteredInAWideFrame() {
        let r = JLogo().path(in: CGRect(x: 0, y: 0, width: 100, height: 73)).boundingRect
        // Same height, moved over by half the extra width.
        #expect(abs(r.minX - 20.8) < 0.5 && abs(r.maxX - 79.2) < 0.5)
        #expect(abs(r.maxY - 73) < 0.5)
    }

    @Test func theTileStandsALittleOutOfTheBar() {
        #expect(WorkoutTile.rise > 0 && WorkoutTile.rise < WorkoutTile.size / 2)
        #expect(WorkoutTile.slot > WorkoutTile.size)
    }
}
