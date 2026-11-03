import Foundation
import Testing
@testable import Jimmy

@Suite struct KeyboardDismissTests {
    // A field whose text sits from 300 to 340 on screen.
    private func closes(_ y: CGFloat) -> Bool { KeyboardDismiss.closes(tapY: y, fieldTop: 300, fieldBottom: 340) }

    @Test func tapsAwayFromTheFieldClose() {
        #expect(closes(100))
        #expect(closes(600))
        #expect(closes(283))
        #expect(closes(357))
    }

    @Test func tapsOnTheFieldsOwnRowKeepIt() {
        #expect(!closes(320))   // the field, or Add and the clear button beside it
        #expect(!closes(284))   // the padding above
        #expect(!closes(356))   // the padding below
    }

    @Test func returnComesOutOfOneThoughtFields() {
        #expect(KeyboardDismiss.withoutLineBreaks("Keep stacking days") == nil)
        #expect(KeyboardDismiss.withoutLineBreaks("Keep stacking days\n") == "Keep stacking days")
        #expect(KeyboardDismiss.withoutLineBreaks("Keep\r\nstacking") == "Keepstacking")
    }
}
