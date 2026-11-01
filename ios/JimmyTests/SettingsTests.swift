import Foundation
import SwiftUI
import Testing
@testable import Jimmy

@Suite struct SchemeTests {
    private func scheme(_ raw: String) throws -> AccentScheme {
        let json = #"{"id":"settings","scheme":"\#(raw)"}"#
        return try JSONDecoder().decode(Settings.self, from: Data(json.utf8)).scheme
    }

    @Test func orangeIsTheDefault() {
        #expect(Settings().scheme == .orange)
    }
    @Test func retiredSchemesBecomeOrange() throws {
        #expect(try scheme("lime") == .orange)
        #expect(try scheme("amber") == .orange)
        #expect(try scheme("mint") == .mint)
    }
    @Test func everyColorButOrangeHasItsOwnIcon() {
        #expect(AccentScheme.orange.iconName == nil)
        #expect(Set(AccentScheme.allCases.compactMap(\.iconName)) == ["AppIcon-Mint", "AppIcon-Ice", "AppIcon-Red", "AppIcon-Crimson"])
    }
    @Test func signalRedIsNowFlamingoAndStillSavedAsRed() throws {
        #expect(try scheme("red") == .flamingo)
        #expect(AccentScheme.flamingo.label == "Flamingo")
        var s = Settings()
        s.scheme = .flamingo
        let json = String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
        #expect(json.contains(#""scheme":"red""#))
    }
    @Test func crimsonIsSavedAndRestored() throws {
        #expect(try scheme("crimson") == .crimson)
        #expect(AccentScheme.crimson.label == "Crimson")
    }
    @Test func crimsonGetsAWhiteStartButton() {
        for dark in [true, false] {
            #expect(Palette.make(scheme: .crimson, dark: dark).accentPill == .white)
            let orange = Palette.make(scheme: .orange, dark: dark)
            #expect(orange.accentPill == (dark ? orange.bg : orange.text))
        }
    }
    @Test func noColorNameSaysRed() {
        #expect(AccentScheme.allCases.allSatisfy { !$0.label.lowercased().contains("red") })
    }
}
