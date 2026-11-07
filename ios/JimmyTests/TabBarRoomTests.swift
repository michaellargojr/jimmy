import CoreGraphics
import Testing
@testable import Jimmy

// The room every page keeps under the floating bar: its last row stops above the Workout tile,
// on phones with a home indicator (34) and with a Home button (0).

@Suite struct TabBarRoomTests {
    /// The top of the Workout tile, measured up from the bottom of the screen.
    private func tileTop(_ device: CGFloat) -> CGFloat {
        TabBarRoom.lift(device: device) + JimmyTabBar.height + WorkoutTile.rise
    }

    @Test func pagesStopClearOfTheTile() {
        for device: CGFloat in [34, 0] {
            #expect(device + TabBarRoom.room(device: device) == tileTop(device) + TabBarRoom.clearance)
            #expect(TabBarRoom.clearance >= 8)
        }
    }

    @Test func theBarFloatsIntoTheHomeIndicatorsSpace() {
        // Like the system's bar on an iPhone 12 mini or 17: 21 up from the bottom edge.
        #expect(TabBarRoom.lift(device: 34) == 21)
        #expect(TabBarRoom.lift(device: 0) == 8)
    }

    @Test func theRoomIsWhatTheBarAddsToThePhonesOwnInset() {
        #expect(TabBarRoom.room(device: 34) == 72)
        #expect(TabBarRoom.room(device: 0) == 93)
    }
}
