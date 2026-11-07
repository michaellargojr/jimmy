import Foundation
import Testing
@testable import Jimmy

@Suite struct AppVersionTests {
    @Test func showsVersionAndBuild() {
        #expect(AppVersion.label(version: "2.2", build: "2") == "Jimmy 2.2 - Build 2")
        #expect(AppVersion.label(version: "2.2.1", build: "3") == "Jimmy 2.2.1 - Build 3")
    }
    @Test func leavesOutWhatIsMissing() {
        #expect(AppVersion.label(version: "2.2", build: nil) == "Jimmy 2.2")
        #expect(AppVersion.label(version: "2.2", build: "") == "Jimmy 2.2")
    }
    @Test func readsTheNumbersTheAppWasBuiltWith() {
        // Tests run inside the app, so this is the project's real version, not a typed-in one.
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        #expect(version?.isEmpty == false)
        #expect(build?.isEmpty == false)
        #expect(AppVersion.current == "Jimmy \(version ?? "") - Build \(build ?? "")")
    }
}
