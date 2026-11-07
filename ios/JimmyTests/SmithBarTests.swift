import Foundation
import Testing
@testable import Jimmy

// A Smith machine's bar is always straight: no EZ bar for a Smith style or variation.

@Suite struct SmithBarTests {
    private let bar = Version(exerciseId: "e", name: "Calf Raise · Bar", equipment: .barbell, arms: .two, defaultWarmup: false, defaultSets: 2)

    @Test func smithStyleOffersNoBarChoice() {
        let smith = Style(versionId: bar.id, barType: .smith)
        #expect(isSmith(bar, style: smith))
        #expect(!offersBarChoice(bar, style: smith))
        #expect(offersBarChoice(bar, style: Style(versionId: bar.id, barType: .barbell)))
        #expect(offersBarChoice(bar, style: nil))
    }

    @Test func smithVariationOffersNoBarChoice() {
        let v = Version(exerciseId: "e", name: "Calf Raise · Smith", equipment: .smith, arms: .two, defaultWarmup: false, defaultSets: 1)
        #expect(!offersBarChoice(v, style: nil))
    }

    @Test func smithSetsStartOnTheStraightBarEvenAfterAnEZSession() {
        let last = Workout(name: "Legs", items: [WorkoutItem(versionId: bar.id, sets: [SetEntry(kind: .working, unit: .kg, weight: 40, reps: 10, bar: .ez)])])
        let sets = defaultSets(for: bar, style: Style(versionId: bar.id, barType: .smith), unit: .kg, workouts: [last])
        #expect(sets.allSatisfy { $0.bar == .straight })
    }
}
