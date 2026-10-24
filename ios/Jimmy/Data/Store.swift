import Foundation
import Observation

/// Single source of truth. Everything lives in memory and is written to one JSON file
/// in Documents (same shape as the web export), debounced after each change.
@Observable
final class AppStore {
    var exercises: [Exercise] = []
    var versions: [Version] = []
    var styles: [Style] = []
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
    func style(_ id: String?) -> Style? { id.flatMap { id in styles.first { $0.id == id } } }
    func exercise(_ id: String) -> Exercise? { exercises.first { $0.id == id } }
    func base(of v: Version) -> Exercise? { exercise(v.exerciseId) }
    /// Variations of a base, in display order.
    func variations(of exerciseId: String) -> [Version] { versions.filter { $0.exerciseId == exerciseId }.sorted(by: variationSort) }
    func styles(of versionId: String) -> [Style] { styles.filter { $0.versionId == versionId } }
    /// Bases that have at least one variation: the ones Michael actually does.
    var usedExerciseIds: Set<String> { Set(versions.map { $0.exerciseId }) }

    // MARK: Labels

    /// "Lateral Raise"
    func baseName(_ v: Version) -> String { base(of: v)?.name ?? v.name }
    /// "Cable · one arm · standing"
    func variationText(_ v: Version) -> String { variationLabel(v, legs: base(of: v)?.isLegs ?? false) }
    /// "Cable · one arm · standing · Rope" or just the variation when there is no style.
    func subtitle(_ v: Version, styleId: String? = nil) -> String {
        let s = style(styleId)?.label ?? ""
        return s.isEmpty ? variationText(v) : variationText(v) + " · " + s
    }
    /// "Lateral Raise · Cable · one arm", for lists that show one line.
    func fullName(_ v: Version, styleId: String? = nil) -> String { baseName(v) + " · " + subtitle(v, styleId: styleId) }
    func routine(_ id: String) -> Routine? { routines.first { $0.id == id } }
    func workout(_ id: String) -> Workout? { workouts.first { $0.id == id } }
    func muscle(of v: Version) -> MuscleGroup? { exercise(v.exerciseId)?.muscleGroup }

    var activeWorkout: Workout? { workouts.first { $0.isActive } }
    var finishedWorkouts: [Workout] { sortedNewestFirst(workouts.filter { $0.isFinished }) }
    /// The split a routine's coverage is judged on: the active split when it holds the routine, else the first that does.
    func split(containing routineId: String) -> Split? {
        if let a = activeSplit, a.routineIds.contains(routineId) { return a }
        return splits.first { $0.routineIds.contains(routineId) }
    }
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
            if s.version < 2 { migrateToLibraryV2(); markDirty() }
        } else {
            resetToSeed()
        }
        loaded = true
    }

    private func apply(_ s: Snapshot) {
        exercises = s.exercises; versions = s.versions; styles = s.styles; workouts = s.workouts; routines = s.routines
        gyms = s.gyms; ideas = s.ideas; splits = s.splits
        if let st = s.settings { settings = st }
    }

    func snapshot() -> Snapshot {
        Snapshot(exportedAt: ISO8601DateFormatter().string(from: Date()), exercises: exercises, versions: versions, styles: styles,
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
        exercises = s.exercises; versions = s.versions; styles = s.styles; workouts = s.workouts; routines = s.routines
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
        if s.version < 2 { migrateToLibraryV2() }
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
    func deleteVersion(_ id: String) {
        versions.removeAll { $0.id == id }
        styles.removeAll { $0.versionId == id }
        markDirty()
    }
    func put(_ s: Style) { upsert(&styles, s); markDirty() }
    func deleteStyle(_ id: String) {
        styles.removeAll { $0.id == id }
        for i in routines.indices { for j in routines[i].items.indices where routines[i].items[j].styleId == id { routines[i].items[j].styleId = nil } }
        markDirty()
    }
    func put(_ e: Exercise) { upsert(&exercises, e); markDirty() }
    func deleteExercise(_ id: String) {
        for v in versions where v.exerciseId == id { styles.removeAll { $0.versionId == v.id } }
        versions.removeAll { $0.exerciseId == id }
        exercises.removeAll { $0.id == id }
        markDirty()
    }
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
        let w = workoutFromRoutine(r, versions: versions, styles: styles, unit: settings.unit, workouts: workouts)
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

    // MARK: Library

    /// The base with this name, from the library or the ones Michael added.
    func base(named name: String) -> Exercise? {
        let n = name.trimmingCharacters(in: .whitespaces)
        return exercises.first { $0.name.caseInsensitiveCompare(n) == .orderedSame }
            ?? exercises.first { $0.aliases.contains { $0.caseInsensitiveCompare(n) == .orderedSame } }
    }

    /// A base that is not in the library.
    @discardableResult
    func addBase(name: String, group: MuscleGroup) -> Exercise {
        if let e = base(named: name) { return e }
        let e = Exercise(name: name.trimmingCharacters(in: .whitespaces), muscleGroup: group, custom: true)
        put(e)
        return e
    }

    func findVariation(baseId: String, key: VariationKey) -> Version? {
        versions.first { $0.exerciseId == baseId && $0.key == key }
    }

    /// The variation with these fields, created if needed.
    @discardableResult
    func makeVariation(base: Exercise, spec: VariationSpec, repMin: Int? = nil, repMax: Int? = nil) -> Version {
        if let v = findVariation(baseId: base.id, key: spec.key) { return v }
        let name = base.name + " · " + variationLabel(spec, legs: base.isLegs)
        let v = Version(exerciseId: base.id, name: name, equipment: spec.family.equipment, arms: spec.arms, position: spec.position,
                        tag: spec.tag, repMin: repMin ?? 5, repMax: repMax ?? 8)
        put(v)
        return v
    }

    func findStyle(versionId: String, key: StyleKey) -> Style? {
        styles.first { $0.versionId == versionId && $0.key == key }
    }

    /// The style with these fields under a variation, created if needed. Empty specs give no style.
    @discardableResult
    func makeStyle(for v: Version, spec: StyleSpec) -> Style? {
        if spec.isEmpty { return nil }
        if let s = findStyle(versionId: v.id, key: spec.key) { return s }
        let s = spec.style(for: v.id)
        put(s)
        return s
    }

    /// Where a picked variation and style land: an existing variation, a new style of it, or a new variation.
    enum AddVerdict: Equatable { case existing(Version, Style?), newStyle(Version), newVariation }

    func addVerdict(base: Exercise, variation: VariationSpec, style: StyleSpec) -> AddVerdict {
        guard let v = findVariation(baseId: base.id, key: variation.key) else { return .newVariation }
        if style.isEmpty { return .existing(v, nil) }
        if let s = findStyle(versionId: v.id, key: style.key) { return .existing(v, s) }
        return .newStyle(v)
    }

    /// Resolve a pick to a variation and style, creating what is missing.
    func resolve(base: Exercise, variation: VariationSpec, style: StyleSpec, repMin: Int? = nil, repMax: Int? = nil) -> (Version, Style?) {
        let v = makeVariation(base: base, spec: variation, repMin: repMin, repMax: repMax)
        return (v, makeStyle(for: v, spec: style))
    }

    /// Old exports and the first iOS build named versions freely ("Cable Pulldown (Extended)").
    /// Map each one onto a base, variation and style by its name; merge versions that land on one variation.
    func migrateToLibraryV2() {
        struct Slot: Hashable { var baseId: String; var key: VariationKey }
        var merged: [String: String] = [:]          // old version id -> surviving version id
        var styleFor: [String: String] = [:]         // old version id -> style id to stamp on its items
        var bySlot: [Slot: String] = [:]
        var out: [Version] = []

        func ensureBase(_ name: String, _ group: MuscleGroup) -> Exercise {
            if let e = base(named: name) { return e }
            let e = libraryBase(named: name)?.exercise ?? Exercise(name: name, muscleGroup: group, custom: true)
            exercises.append(e)
            return e
        }
        func ensureStyle(_ versionId: String, _ spec: StyleSpec) -> String {
            if let st = findStyle(versionId: versionId, key: spec.key) { return st.id }
            let st = spec.style(for: versionId)
            styles.append(st)
            return st.id
        }

        for var v in versions {
            guard let m = legacyMapping(for: v.name) else {
                if base(of: v) == nil { v.exerciseId = ensureBase(v.name, .Back).id }
                out.append(v); continue
            }
            let b = ensureBase(m.base, m.group)
            let slot = Slot(baseId: b.id, key: m.variation.key)
            if let keep = bySlot[slot] {
                merged[v.id] = keep
                if !m.style.isEmpty { styleFor[v.id] = ensureStyle(keep, m.style) }
                continue
            }
            v.exerciseId = b.id
            v.equipment = m.variation.family.equipment; v.arms = m.variation.arms; v.position = m.variation.position; v.tag = m.variation.tag
            v.name = b.name + " · " + variationLabel(m.variation, legs: b.isLegs)
            v.machine = nil
            out.append(v); bySlot[slot] = v.id
            if !m.style.isEmpty { styleFor[v.id] = ensureStyle(v.id, m.style) }
        }
        versions = out
        for i in workouts.indices {
            for j in workouts[i].items.indices {
                let old = workouts[i].items[j].versionId
                if let s = styleFor[old], workouts[i].items[j].styleId == nil { workouts[i].items[j].styleId = s }
                if let keep = merged[old] { workouts[i].items[j].versionId = keep }
            }
        }
        for i in routines.indices {
            for j in routines[i].items.indices {
                let old = routines[i].items[j].versionId
                if let s = styleFor[old], routines[i].items[j].styleId == nil { routines[i].items[j].styleId = s }
                if let keep = merged[old] { routines[i].items[j].versionId = keep }
            }
        }
        if let w = settings.watchVersionId, let keep = merged[w] { settings.watchVersionId = keep }

        // Replace the old flat library (names like "Cable Hammer Curl") with the encyclopedia bases.
        let used = usedExerciseIds
        exercises.removeAll { !used.contains($0.id) && libraryBase(named: $0.name) == nil && $0.custom != true }
        for lib in LIBRARY where base(named: lib.name) == nil { exercises.append(lib.exercise) }
        for i in exercises.indices {
            if let lib = libraryBase(named: exercises[i].name) {
                exercises[i].muscleGroup = lib.group; exercises[i].alsoGroups = lib.also
                exercises[i].primary = lib.primary; exercises[i].secondary = lib.secondary
                for a in lib.aliases where !exercises[i].aliases.contains(a) { exercises[i].aliases.append(a) }
            }
        }
    }

    var exportURL: URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("jimmy-\(today()).json")
        guard let data = try? snapshot().encoded() else { return nil }
        try? data.write(to: url, options: .atomic)
        return url
    }
}
