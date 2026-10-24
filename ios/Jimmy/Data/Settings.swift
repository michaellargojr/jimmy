import Foundation

enum Appearance: String, Codable, CaseIterable { case dark, light, system }

enum AccentScheme: String, Codable, CaseIterable {
    case lime, mint, amber, ice, red
    var label: String {
        switch self {
        case .lime: return "Lime"
        case .mint: return "Mint"
        case .amber: return "Amber"
        case .ice: return "Ice"
        case .red: return "Signal red"
        }
    }
}

enum HomeBlock: String, Codable, CaseIterable, Identifiable {
    case quote, upNext, week, recent, allRoutines, watchExercise
    var id: String { rawValue }
    var title: String {
        switch self {
        case .quote: return "Mantra"
        case .upNext: return "Up next"
        case .week: return "This week"
        case .recent: return "Recent workouts"
        case .allRoutines: return "All routines"
        case .watchExercise: return "Exercise to watch"
        }
    }
    var subtitle: String {
        switch self {
        case .quote: return "Bordered card, bold and plain"
        case .upNext: return "Next routine in the split, one tap to start"
        case .week: return "Seven day strip"
        case .recent: return "Last two, with up or down"
        case .allRoutines: return "Every routine in the split, start any"
        case .watchExercise: return "Progress line for one exercise you pick"
        }
    }
}

struct HomeBlockSetting: Codable, Hashable, Identifiable {
    var block: HomeBlock
    var on: Bool
    var id: String { block.rawValue }

    static let defaults: [HomeBlockSetting] = [
        .init(block: .upNext, on: true), .init(block: .week, on: true), .init(block: .recent, on: true),
        .init(block: .quote, on: true), .init(block: .allRoutines, on: false), .init(block: .watchExercise, on: false),
    ]

    /// The order before the Mantra card moved to the bottom of Home. Saved
    /// settings still in this order are migrated to the new default order.
    static let legacyOrder: [HomeBlock] = [.quote, .upNext, .week, .recent, .allRoutines, .watchExercise]
}

/// The Mantra shown on Home. The stored key stays `quote` so web exports still decode.
let DEFAULT_QUOTE = "Keep stacking days and you'll inevitably make a change."

/// Settings. The first few keys match the web app so its export decodes here.
struct Settings: Codable, Hashable {
    var id: String = "settings"
    var unit: WeightUnit = .kg
    var theme: String = "dark" // kept for web compatibility
    var sound: Bool = true
    var seeded: Bool? = true
    var appearance: Appearance = .dark
    var scheme: AccentScheme = .lime
    var quote: String = DEFAULT_QUOTE
    var homeBlocks: [HomeBlockSetting] = HomeBlockSetting.defaults
    var restTimer: Bool = false
    var restSeconds: Int = 90
    var activeSplitId: String?
    var watchVersionId: String?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? "settings"
        unit = (try? c.decode(WeightUnit.self, forKey: .unit)) ?? .kg
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? "dark"
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        seeded = try c.decodeIfPresent(Bool.self, forKey: .seeded)
        appearance = (try? c.decode(Appearance.self, forKey: .appearance)) ?? (theme == "light" || theme == "paper" ? .light : .dark)
        scheme = (try? c.decode(AccentScheme.self, forKey: .scheme)) ?? .lime
        quote = try c.decodeIfPresent(String.self, forKey: .quote) ?? DEFAULT_QUOTE
        var blocks = (try? c.decode([HomeBlockSetting].self, forKey: .homeBlocks)) ?? HomeBlockSetting.defaults
        for d in HomeBlockSetting.defaults where !blocks.contains(where: { $0.block == d.block }) { blocks.append(d) }
        if blocks.map(\.block) == HomeBlockSetting.legacyOrder {
            blocks = HomeBlockSetting.defaults.map { d in .init(block: d.block, on: blocks.first { $0.block == d.block }?.on ?? d.on) }
        }
        homeBlocks = blocks
        restTimer = try c.decodeIfPresent(Bool.self, forKey: .restTimer) ?? false
        restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        activeSplitId = try c.decodeIfPresent(String.self, forKey: .activeSplitId)
        watchVersionId = try c.decodeIfPresent(String.self, forKey: .watchVersionId)
    }
}
