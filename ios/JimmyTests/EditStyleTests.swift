import Foundation
import Testing
@testable import Jimmy

// Edit style on the workout card: the list puts the card's style first, and adding detail to a
// style keeps it the same style, so the sessions logged in it stay with it.

@Suite struct EditStyleTests {
    @Test func theCardsStyleComesFirst() {
        let a = Style(versionId: "v", attachment: "rope")
        let b = Style(versionId: "v", attachment: "v-bar")
        let c = Style(versionId: "v", attachment: "straight bar")
        #expect(editStyleOrder([a, b, c], currentId: c.id).map(\.id) == [c.id, a.id, b.id])
        #expect(editStyleOrder([a, b, c], currentId: a.id).map(\.id) == [a.id, b.id, c.id])
        #expect(editStyleOrder([a, b, c], currentId: nil).map(\.id) == [a.id, b.id, c.id])
        #expect(editStyleOrder([a, b, c], currentId: "gone").map(\.id) == [a.id, b.id, c.id])
    }

    @Test func addingACableHeightKeepsTheSameStyle() {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("edit-style-\(uid()).json"))
        var rope = Style(versionId: "v", attachment: "rope")
        s.put(rope)
        rope.cableHeight = CableHeight.chest.rawValue
        s.put(rope)
        #expect(s.styles(of: "v").count == 1)
        #expect(s.style(rope.id)?.label == "Rope · Chest height")
    }
}
