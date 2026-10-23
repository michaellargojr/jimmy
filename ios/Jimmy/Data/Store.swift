import Foundation
import Observation

/// Single source of truth. Everything lives in memory and is written to one JSON file
/// in Documents (same shape as the web export), debounced after each change.
@Observable
final class AppStore {
    var exercises: [Exercise] = []
    var versions: [Version] = []
    var workouts: [Workout] = []
    var routines: [Routine] = []
    var gyms: [Gym] = []
    var splits: [Split] = []
    var ideas: [Idea] = []
    var settings = Settings()
    var loaded = false

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("jimmy.json")
    }

    // MARK: Lookups

    var versionsById: [String: Version] { Dictionary(versions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }
    var exercisesById: [String: Exercise] { Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }
    func version(_ id: String) -> Version? { versions.first { $0.id == id } }
    func exercise(_ id: String) -> Exercise? { exercises.first { $0.id == id } }
    func routine(_ id: String) -> Routine? { routines.first { $0.id == id } }
    func workout(_ id: String) -> Workout? { workouts.first { $0.id == id } }
    func muscle(of v: Version) -> MuscleGroup? { exercise(v.exerciseId)?.muscleGroup }

    var activeWorkout: Workout? { workouts.first { $0.isActive } }
    var finishedWorkouts: [Workout] { sortedNewestFirst(workouts.filter { $0.isFinished }) }
    var activeSplit: Split? {
        if let id = settings.activeSplitId, let s = splits.first(where: { $0.id == id }) { return s }
        return splits.first
    }

    /// The routine to suggest next: the one after the last finished routine in the active split,
    /// or the one you have gone longest without.
    var upNextRoutine: Routine? {
        if let split = activeSplit, !split.routineIds.isEmpty {
            let ids = split.routineIds
            if let last = finishedWorkouts.first(where: { $0.routineId != nil && ids.contains($0.routineId!) }),
               let idx = ids.firstIndex(of: last.routineId!) {
                return routine(ids[(idx + 1) % ids.count])
            }
            return routine(ids[0])
        }
        return routines.sorted { a, b in
            (routineLast(a, workouts: workouts)?.date ?? "0") < (routineLast(b, workouts: workouts)?.date ?? "0")
        }.first
    }

    // MARK: Load and save

    func load() {
        if let data = try? Data(contentsOf: fileURL), let s = try? Snapshot.decode(data) {
            apply(s)
            if splits.isEmpty, !routines.isEmpty { seedSplitFromRoutines() }
        } else {
            resetToSeed()
        }
        loaded = true
    }

    private func apply(_ s: Snapshot) {
        exercises = s.exercises; versions = s.versions; workouts = s.workouts; routines = s.routines
        gyms = s.gyms; ideas = s.ideas; splits = s.splits
        if let st = s.settings { settings = st }
    }

    func snapshot() -> Snapshot {
        Snapshot(exportedAt: ISO8601DateFormatter().string(from: Date()), exercises: exercises, versions: versions,
                 workouts: workouts, routines: routines, gyms: gyms, settings: settings, ideas: ideas, splits: splits)
    }

    func markDirty() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.saveNow() }
        }
    }

    func saveNow() {
        do {
            let data = try snapshot().encoded()
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Jimmy: save failed: \(error)")
        }
    }

    func resetToSeed() {
        let keepIdeas = ideas
        let keepSettings = settings
        let s = buildSeed()
        exercises = s.exercises; versions = s.versions; workouts = s.workouts; routines = s.routines
        gyms = s.gyms; splits = s.splits; ideas = keepIdeas
        settings = keepSettings
        settings.activeSplitId = s.splits.first?.id
        markDirty()
    }

    /// Replace everything with an export. Ideas are kept if the import has none.
    func importSnapshot(_ s: Snapshot) {
        let keepIdeas = ideas
        let keepSettings = settings
        apply(s)
        if ideas.isEmpty { ideas = keepIdeas }
        if s.settings == nil { settings = keepSettings }
        if splits.isEmpty { seedSplitFromRoutines() }
        markDirty()
    }

    private func seedSplitFromRoutines() {
        let split = Split(name: "My split", routineIds: routines.map { $0.id })
        splits = [split]
        settings.activeSplitId = split.id
    }

    // MARK: Mutations

    private func upsert<T: Identifiable>(_ list: inout [T], _ item: T) {
        if let i = list.firstIndex(where: { $0.id == item.id }) { list[i] = item } else { list.append(item) }
    }

    func put(_ w: Workout) { upsert(&workouts, w); markDirty() }
    func deleteWorkout(_ id: String) { workouts.removeAll { $0.id == id }; markDirty() }
    func put(_ r: Routine) { upsert(&routines, r); markDirty() }
    func deleteRoutine(_ id: String) {
        routines.removeAll { $0.id == id }
        for i in splits.indices { splits[i].routineIds.removeAll { $0 == id } }
        markDirty()
    }
    func put(_ v: Version) { upsert(&versions, v); markDirty() }
    func deleteVersion(_ id: String) { versions.removeAll { $0.id == id }; markDirty() }
    func put(_ e: Exercise) { upsert(&exercises, e); markDirty() }
    func put(_ g: Gym) { upsert(&gyms, g); markDirty() }
    func put(_ s: Split) { upsert(&splits, s); markDirty() }
    func deleteSplit(_ id: String) {
        splits.removeAll { $0.id == id }
        if settings.activeSplitId == id { settings.activeSplitId = splits.first?.id }
        markDirty()
    }
    func put(_ i: Idea) { upsert(&ideas, i); markDirty() }
    func deleteIdea(_ id: String) { ideas.removeAll { $0.id == id }; markDirty() }
    func update(_ f: (inout Settings) -> Void) { f(&settings); markDirty() }

    // MARK: Workflows

    @discardableResult
    func startWorkout(from r: Routine) -> Workout {
        let w = workoutFromRoutine(r, versions: versions, unit: settings.unit, workouts: workouts)
        put(w)
        return w
    }

    @discardableResult
    func startQuickWorkout() -> Workout {
        let w = Workout(name: "Quick workout", startedAt: nowMs())
        put(w)
        return w
    }

    func finishWorkout(_ id: String) {
        guard var w = workout(id) else { return }
        w.endedAt = nowMs()
        // Drop exercises that never got a set logged so history stays clean.
        w.items.removeAll { !$0.isDone && !$0.sets.contains { $0.hasData } }
        if w.items.isEmpty { deleteWorkout(id) } else { put(w) }
    }

    /// Create a version for a library entry (or a custom name) so it can be used in a workout.
    func makeVersion(name: String, muscle: MuscleGroup, equipment: Equipment, arms: Arms = .two) -> Version {
        let ex: Exercise
        if let e = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { ex = e }
        else { ex = Exercise(name: name, muscleGroup: muscle); put(ex) }
        let v = Version(exerciseId: ex.id, name: name, equipment: equipment, arms: arms)
        put(v)
        return v
    }

    var exportURL: URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("jimmy-\(today()).json")
        guard let data = try? snapshot().encoded() else { return nil }
        try? data.write(to: url, options: .atomic)
        return url
    }
}
