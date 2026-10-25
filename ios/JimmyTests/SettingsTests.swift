import Foundation
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
        #expect(Set(AccentScheme.allCases.compactMap(\.iconName)) == ["AppIcon-Mint", "AppIcon-Ice", "AppIcon-Red"])
    }
}
