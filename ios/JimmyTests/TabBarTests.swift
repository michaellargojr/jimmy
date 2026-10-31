import SwiftUI
import Testing
@testable import Jimmy

// The Workout circle's J: the stem on the right, the hook curling under it to the left.

@Suite struct TabBarTests {
    @Test func theHookCurlsDownNotUp() {
        let r = JMark().path(in: CGRect(x: 0, y: 0, width: 24, height: 24)).boundingRect
        #expect(abs(r.minY - 4.2) < 0.05)
        #expect(abs(r.maxY - 18.8) < 0.05)
        #expect(abs(r.minX - 4.6) < 0.05)
        #expect(abs(r.maxX - 15) < 0.05)
    }

    @Test func theJStaysCenteredInAWideFrame() {
        let r = JMark().path(in: CGRect(x: 0, y: 0, width: 48, height: 24)).boundingRect
        // Same size as in a square, moved over by half the extra width.
        #expect(abs(r.minX - 16.6) < 0.05)
        #expect(abs(r.maxY - 18.8) < 0.05)
    }
}
