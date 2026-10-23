import Foundation

/// The JSON export. Same shape as the web app's Settings > Export, plus `splits`.
struct Snapshot: Codable {
    var version: Int = 1
    var exportedAt: String
    var exercises: [Exercise]
    var versions: [Version]
    var workouts: [Workout]
    var routines: [Routine]
    var gyms: [Gym]
    var settings: Settings?
    var ideas: [Idea]
    var splits: [Split]

    init(exportedAt: String, exercises: [Exercise], versions: [Version], workouts: [Workout], routines: [Routine],
         gyms: [Gym], settings: Settings?, ideas: [Idea], splits: [Split]) {
        self.exportedAt = exportedAt; self.exercises = exercises; self.versions = versions; self.workouts = workouts
        self.routines = routines; self.gyms = gyms; self.settings = settings; self.ideas = ideas; self.splits = splits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try c.decodeIfPresent(String.self, forKey: .exportedAt) ?? ""
        exercises = try c.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        versions = try c.decodeIfPresent([Version].self, forKey: .versions) ?? []
        workouts = try c.decodeIfPresent([Workout].self, forKey: .workouts) ?? []
        routines = try c.decodeIfPresent([Routine].self, forKey: .routines) ?? []
        gyms = try c.decodeIfPresent([Gym].self, forKey: .gyms) ?? []
        settings = try? c.decodeIfPresent(Settings.self, forKey: .settings)
        ideas = try c.decodeIfPresent([Idea].self, forKey: .ideas) ?? []
        splits = try c.decodeIfPresent([Split].self, forKey: .splits) ?? []
    }

    static func decode(_ data: Data) throws -> Snapshot {
        try JSONDecoder().decode(Snapshot.self, from: data)
    }

    func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }
}
