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
    /// Form cues library. See ClipFiles for where the files live.
    var clips: [Clip] = []
    var settings = Settings()
    var loaded = false
    /// The last copy, move or erase of a history, while its Undo bar shows. Never saved.
    var historyUndo: HistoryUndo?

    /// Backups to a folder in iCloud Drive. See Backup.swift.
    let backups: Backups

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    /// A store with its own file (tests) keeps its backup folder in memory, so it never
    /// writes into the folder the app on this device backs up to.
    init(fileURL: URL? = nil, backups: Backups? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("jimmy.json")
        self.backups = backups ?? Backups(defaults: fileURL == nil ? UserDefaults.standard : nil)
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
    /// The Workout title, built from the blocks: "Dumbbell Shoulder Press", "Cable Overhead Tricep
    /// Extension". A named machine reads last: "Machine Calf Raise (D Stars)", "Machine Iso-lateral
    /// Pulldown (D Stars)". Plan keeps base names.
    func workoutName(_ v: Version) -> String {
        var words: [String] = []
        switch v.family {
        case .body: break
        case .bar: words.append("Barbell")
        default: words.append(v.family.label)
        }
        let tag = v.tag?.trimmingCharacters(in: .whitespaces) ?? ""
        let namedMachine = v.family == .machine && tag.first?.isUppercase == true
        if !tag.isEmpty && !namedMachine { words.append(tag.split(separator: " ").map { capitalized(String($0)) }.joined(separator: " ")) }
        words.append(baseName(v))
        let names = [namedMachine ? tag : nil, v.machine?.trimmingCharacters(in: .whitespaces)].compactMap { $0 }.filter { !$0.isEmpty }
        return words.joined(separator: " ") + (names.isEmpty ? "" : " (\(names.joined(separator: " - ")))")
    }
    /// The Workout subtitle: "Two arms", "One arm - seated", "One leg".
    func armsText(_ v: Version) -> String {
        let legs = base(of: v)?.isLegs ?? false
        var parts: [String] = []
        if v.arms == .one || v.family != .body { parts.append(capitalized(v.arms.label(legs: legs))) }
        if let pos = v.position { parts.append(parts.isEmpty ? capitalized(pos.label) : pos.label) }
        return parts.joined(separator: " - ")
    }
    /// The whole variation as chips: "Cable", "Two arms". For Plan, History and lists.
    func variationChips(_ v: Version) -> [String] {
        variationParts(family: v.family, arms: v.arms, position: v.position, tag: v.tag, machine: v.machine,
                       loading: v.loading, legs: base(of: v)?.isLegs ?? false)
            .map { capitalized($0) }
    }
    /// The same words as armsText, one per chip: "Two arms", "Seated". The Workout card's title
    /// already names the equipment, so it shows only these, plus Plates or Stack for a machine.
    func variationTags(_ v: Version) -> [String] {
        let legs = base(of: v)?.isLegs ?? false
        var tags: [String] = []
        if v.family == .machine, let l = v.loading { tags.append(capitalized(l.label)) }
        if v.arms == .one || v.family != .body { tags.append(capitalized(v.arms.label(legs: legs))) }
        if let pos = v.position { tags.append(capitalized(pos.label)) }
        return tags
    }
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
            if fillMachineLoading() { markDirty() }
        } else {
            resetToSeed()
        }
        loaded = true
    }

    private func apply(_ s: Snapshot) {
        exercises = s.exercises; versions = s.versions; styles = s.styles; workouts = s.workouts; routines = s.routines
        gyms = s.gyms; ideas = s.ideas; splits = s.splits
        // Keep clips already on this phone; add any the import knows about whose file is here.
        var known = Dictionary(clips.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for c in s.clips where known[c.id] == nil { known[c.id] = c }
        clips = known.values.filter { ClipFiles.exists($0) }.sorted { $0.addedAt > $1.addedAt }
        let have = Set(clips.map { $0.id })
        for i in versions.indices { versions[i].clipIds.removeAll { !have.contains($0) } }
        if let st = s.settings { settings = st }
    }

    func snapshot() -> Snapshot {
        Snapshot(exportedAt: ISO8601DateFormatter().string(from: Date()), exercises: exercises, versions: versions, styles: styles,
                 workouts: workouts, routines: routines, gyms: gyms, settings: settings, ideas: ideas, splits: splits, clips: clips)
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
        fillMachineLoading()
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
        fillMachineLoading()
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

    // MARK: Form cues

    func clip(_ id: String) -> Clip? { clips.first { $0.id == id } }
    /// The clips on a variation, in its order.
    func clips(of versionId: String) -> [Clip] { (version(versionId)?.clipIds ?? []).compactMap { clip($0) } }
    /// How many variations use a clip.
    func usage(of clipId: String) -> [Version] { versions.filter { $0.clipIds.contains(clipId) } }
    func formCueCount(_ versionId: String) -> Int {
        guard let v = version(versionId) else { return 0 }
        return v.clipIds.count + v.media.count
    }

    /// Add a stored clip to the library (if new) and to the end of a variation's list.
    func attach(_ c: Clip, to versionId: String?) {
        if clip(c.id) == nil { clips.insert(c, at: 0) }
        if let versionId, var v = version(versionId), !v.clipIds.contains(c.id) {
            v.clipIds.append(c.id)
            upsert(&versions, v)
        }
        markDirty()
    }
    func attach(clipIds ids: [String], to versionId: String) {
        guard var v = version(versionId) else { return }
        for id in ids where !v.clipIds.contains(id) && clip(id) != nil { v.clipIds.append(id) }
        put(v)
    }
    func detach(_ clipId: String, from versionId: String) {
        guard var v = version(versionId) else { return }
        v.clipIds.removeAll { $0 == clipId }
        put(v)
    }
    /// Deletes the clip and its file. Only allowed when no variation uses it.
    func deleteClip(_ id: String) {
        guard usage(of: id).isEmpty, let c = clip(id) else { return }
        clips.removeAll { $0.id == id }
        ClipFiles.remove(c)
        markDirty()
    }
    func addLink(_ raw: String, to versionId: String) {
        guard var v = version(versionId), let url = normalizedLink(raw) else { return }
        guard !v.media.contains(where: { $0.url == url }) else { return }
        v.media.append(Media(type: url.lowercased().contains("tiktok.com") ? "tiktok" : "video", url: url))
        put(v)
    }
    func removeLink(_ url: String, from versionId: String) {
        guard var v = version(versionId) else { return }
        v.media.removeAll { $0.url == url }
        put(v)
    }
    func deleteIdea(_ id: String) { ideas.removeAll { $0.id == id }; markDirty() }
    func update(_ f: (inout Settings) -> Void) { f(&settings); markDirty() }

    // MARK: Workflows

    @discardableResult
    func startWorkout(from r: Routine) -> Workout {
        var w = workoutFromRoutine(r, versions: versions, styles: styles, unit: settings.unit, workouts: workouts)
        w.repTemplate = settings.repTemplate == .standard ? nil : settings.repTemplate
        put(w)
        return w
    }

    @discardableResult
    func startQuickWorkout() -> Workout {
        let w = Workout(name: "Quick workout", startedAt: nowMs(), repTemplate: settings.repTemplate == .standard ? nil : settings.repTemplate)
        put(w)
        return w
    }

    // MARK: Rep ranges

    func repGroup(_ v: Version) -> RepGroup { exerciseRepGroup(base: baseName(v), family: v.family, tag: v.tag) }

    /// What this exercise works to in this workout.
    func repRange(_ item: WorkoutItem, in w: Workout) -> RepRange? {
        guard let v = version(item.versionId) else { return nil }
        return effectiveRepRange(item: item, workout: w, version: v, group: repGroup(v))
    }

    func setRepTemplate(_ t: RepTemplate, workoutId: String) {
        guard let w = workout(workoutId) else { return }
        put(settingRepTemplate(t, on: w))
    }

    /// Exercises with nothing logged, not even a warm-up. Finish drops them so history stays clean.
    func unlogged(_ w: Workout) -> [WorkoutItem] {
        w.items.filter { !$0.isDone && !$0.sets.contains { $0.hasData } }
    }

    func finishWorkout(_ id: String) {
        guard var w = workout(id) else { return }
        w.endedAt = nowMs()
        let drop = Set(unlogged(w).map(\.id))
        w.items.removeAll { drop.contains($0.id) }
        w = freezingRepRanges(w, versions: versions) { self.repGroup($0) }
        if w.items.isEmpty { deleteWorkout(id) } else { put(w); backUp() }
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
    func makeVariation(base: Exercise, spec given: VariationSpec, repMin: Int? = nil, repMax: Int? = nil) -> Version {
        let spec = withLoading(given, base: base)
        if let v = findVariation(baseId: base.id, key: spec.key) { return v }
        let name = base.name + " · " + variationLabel(spec, legs: base.isLegs)
        let v = Version(exerciseId: base.id, name: name, equipment: spec.family.equipment, arms: spec.arms, position: spec.position,
                        tag: spec.tag, machine: spec.machine, loading: spec.loading, repMin: repMin ?? 5, repMax: repMax ?? 8)
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
    enum AddVerdict: Equatable {
        case existing(Version, Style?), newStyle(Version), newVariation
        var isExisting: Bool { if case .existing = self { return true }; return false }
    }

    func addVerdict(base: Exercise, variation: VariationSpec, style: StyleSpec) -> AddVerdict {
        guard let v = findVariation(baseId: base.id, key: withLoading(variation, base: base).key) else { return .newVariation }
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
}
