import SwiftUI

// Exercises tab: bases by muscle > a base's variations > a variation's styles.

struct ExercisesList: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var query = ""
    @State private var muscle: MuscleGroup? = nil
    @State private var all = true

    private struct MuscleSection: Identifiable { var id: String { muscle.rawValue }; var muscle: MuscleGroup; var list: [Exercise] }

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    private var grouped: [MuscleSection] {
        let used = store.usedExerciseIds
        let pool = store.exercises.filter { all || used.contains($0.id) }
        let groups = muscle.map { [$0] } ?? MuscleGroup.chipOrder
        return groups.compactMap { m in
            let list = pool.filter { muscle == nil ? $0.muscleGroup == m : $0.groups.contains(m) }.sorted { $0.name < $1.name }
            return list.isEmpty ? nil : MuscleSection(muscle: m, list: list)
        }
    }

    /// Search results, best first: names with the word, then the muscle group or main muscle, then other names it goes by.
    private var results: [Exercise] {
        let q = trimmed
        let ranked: [(Exercise, Int)] = store.exercises.compactMap { e in
            if let m = muscle, !e.groups.contains(m) { return nil }
            guard let r = searchRank(e, q) else { return nil }
            return (e, r)
        }
        return ranked.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.name < $1.0.name }.map { $0.0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(placeholder: "Search exercises", text: $query)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(text: "All", on: all, small: true) { all = true }
                    Chip(text: "Mine", on: !all, small: true) { all = false }
                    Rectangle().fill(p.border).frame(width: 1, height: 20)
                    ForEach(MuscleGroup.chipOrder, id: \.self) { m in
                        Chip(text: m.label, on: muscle == m, small: true) { muscle = muscle == m ? nil : m }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 6)
            List {
                if trimmed.isEmpty {
                    ForEach(grouped) { sec in
                        Section {
                            ForEach(sec.list) { e in
                                NavigationLink(value: e) { baseRow(e) }.rowCard(p)
                            }
                        } header: {
                            SectionLabel(sec.muscle.label).padding(.leading, 16)
                        }
                    }
                    if grouped.isEmpty {
                        Text(all ? "Nothing here." : "Nothing yet. Tap All.")
                            .font(.system(size: 14)).foregroundStyle(p.muted).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                } else {
                    ForEach(results) { e in
                        NavigationLink(value: e) { baseRow(e) }.rowCard(p)
                    }
                    if results.isEmpty {
                        Text("Nothing matches \"\(query)\".")
                            .font(.system(size: 14)).foregroundStyle(p.muted).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                }
            }
            .cardList()
        }
        .background(p.bg.ignoresSafeArea())
    }

    /// Yours show in the accent colour with how many variations you have. Under the name: the main muscles.
    private func baseRow(_ e: Exercise) -> some View {
        let count = store.variations(of: e.id).count
        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(e.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                if !e.primary.isEmpty || !e.secondary.isEmpty {
                    MuscleTags(primary: e.primary, secondary: e.secondary)
                }
            }
            Spacer()
            if count > 0 { Text("\(count)").font(.system(size: 14, weight: .heavy)).foregroundStyle(p.accent) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

/// How well an exercise matches a search, lower is better, nil for no match.
/// 0: the name has the words. 1: its muscle group or a main muscle matches. 2: another name it goes by matches.
func searchRank(_ e: Exercise, _ q: String) -> Int? {
    guard !q.isEmpty else { return 0 }
    if e.name.lowercased().contains(q) { return 0 }
    if q.count >= 3 {
        if e.groups.contains(where: { g in g.searchWords.contains { $0.hasPrefix(q) || q.hasPrefix($0) } }) { return 1 }
        if e.primary.contains(where: { $0.lowercased().contains(q) }) { return 1 }
    }
    if e.aliases.contains(where: { $0.lowercased().contains(q) }) { return 2 }
    return nil
}

extension MuscleGroup {
    /// Words someone might type to mean this group.
    var searchWords: [String] {
        switch self {
        case .Chest: return ["chest", "pecs"]
        case .Back: return ["back", "lats"]
        case .Shoulders: return ["shoulders", "delts"]
        case .Biceps: return ["biceps"]
        case .Triceps: return ["triceps"]
        case .Forearms: return ["forearms"]
        case .Legs: return ["legs", "quads", "hamstrings"]
        case .Glutes: return ["glutes"]
        case .Calves: return ["calves", "calf"]
        case .Abs: return ["abs", "core"]
        }
    }
}

/// One base: the muscles in words, your variations, and more you could add.
struct BasePageView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let exerciseId: String
    @State private var adding = false

    private var base: Exercise? { store.exercise(exerciseId) }

    var body: some View {
        if let e = base {
            let mine = store.variations(of: e.id)
            let suggested = (libraryBase(named: e.name)?.variations ?? []).filter { s in !mine.contains { $0.key == s.key } }
            List {
                Section {
                    MuscleTags(primary: e.primary, secondary: e.secondary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .rowCard(p, radius: Radius.card)
                } header: {
                    SectionLabel("Muscles").padding(.leading, 16)
                }
                Section {
                    ForEach(mine) { v in
                        NavigationLink(value: v) { variationRow(v) }.rowCard(p)
                            .swipeActions {
                                if sessions(v) == 0 {
                                    Button(role: .destructive) { store.deleteVersion(v.id) } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                    }
                    if mine.isEmpty {
                        Text("No variations yet.").font(.system(size: 14)).foregroundStyle(p.muted).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                } header: {
                    SectionLabel("Variations").padding(.leading, 16)
                }
                Section {
                    PillButton(title: "Add variation", style: .primary, icon: "plus", full: true) { adding = true }
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                // Shortcuts under the button: one tap adds a common variation.
                if !suggested.isEmpty {
                    Section {
                        ForEach(suggested, id: \.self) { s in
                            Button { store.makeVariation(base: e, spec: s) } label: {
                                HStack {
                                    Text(variationLabel(s, legs: e.isLegs)).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                                    if let n = s.nick { Text(n).font(.system(size: 12)).foregroundStyle(p.muted) }
                                    Spacer()
                                    Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .rowCard(p)
                        }
                    }
                }
            }
            .cardList()
            .navigationTitle(e.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                if mine.isEmpty, e.custom == true || libraryBase(named: e.name) == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) { store.deleteExercise(e.id) } label: { Image(systemName: "trash") }
                    }
                }
            }
            .sheet(isPresented: $adding) {
                AddExerciseSheet(base: e) { _, _ in }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
        }
    }

    private func variationRow(_ v: Version) -> some View {
        let last = lastSession(versionId: v.id, workouts: store.workouts, versions: store.versions)
        let styles = store.styles(of: v.id)
        return HStack {
            VStack(alignment: .leading, spacing: 8) {
                VariationChips(tags: store.variationChips(v))
                Text([last.map { "\($0.daysAgo == 0 ? "today" : "\($0.daysAgo)d ago")" + (topSet($0.item).map { " - \($0.formatted)" } ?? "") },
                      styles.isEmpty ? nil : "\(styles.count) style\(styles.count == 1 ? "" : "s")",
                      "\(v.repMin)-\(v.repMax) rep range"].compactMap { $0 }.joined(separator: " - "))
                    .font(.system(size: 12.5)).foregroundStyle(p.muted).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func sessions(_ v: Version) -> Int {
        store.workouts.filter { w in w.items.contains { $0.versionId == v.id && $0.sets.contains { $0.hasData } } }.count
    }
}

/// Main muscles as big bright tags, helpers as small dim tags under them, so you can see
/// which muscle groups you are collecting. Plain words for beginners.
struct MuscleTags: View {
    @Environment(\.palette) private var p
    let primary: [String]
    let secondary: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if primary.isEmpty && secondary.isEmpty {
                Text("Muscles not set").font(.system(size: 14)).foregroundStyle(p.muted)
            }
            if !primary.isEmpty {
                FlowRow(spacing: 5, lineSpacing: 5) {
                    ForEach(Array(primary.enumerated()), id: \.offset) { _, m in
                        Text(capitalized(m)).font(.system(size: 13.5, weight: .bold)).foregroundStyle(p.text).lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(p.isDark ? Color(hex: 0x2A2C31) : Color(hex: 0xE3E5EC), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            if !secondary.isEmpty {
                FlowRow(spacing: 5, lineSpacing: 4) {
                    ForEach(Array(secondary.enumerated()), id: \.offset) { _, m in
                        Text(capitalized(m)).font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(p.isDark ? Color(hex: 0x6E717A) : Color(hex: 0x8A8F9A)).lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(p.isDark ? Color(hex: 0x18191D) : Color(hex: 0xF0F1F5), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
            }
        }
    }
}

/// One variation: its styles, progress, form cues, defaults (rep range first) and notes.
struct VersionEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let versionId: String

    // Notes edit a local draft and save when you leave the field. Writing to the store on
    // every keystroke re-sorted the list behind this screen and knocked the keyboard away.
    @FocusState private var notesFocused: Bool
    @State private var draftNotes = ""
    @State private var loaded = false
    @State private var editingStyle: Style? = nil
    @State private var newStyle = false
    @State private var editingRange = false

    private var version: Version? { store.version(versionId) }

    private func loadDrafts() {
        guard !loaded, let v = version else { return }
        draftNotes = v.notes ?? ""; loaded = true
    }

    private func commitNotes() {
        guard loaded, var v = store.version(versionId) else { return }
        let notes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if (notes.isEmpty ? nil : notes) != v.notes { v.notes = notes.isEmpty ? nil : notes; store.put(v) }
    }

    var body: some View {
        if let v = version {
            let b = Binding(get: { store.version(versionId) ?? v }, set: { store.put($0) })
            let styles = store.styles(of: v.id)
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.baseName(v)).font(.system(size: 24, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
                        VariationChips(tags: store.variationChips(v))
                        if let e = store.base(of: v) {
                            SectionLabel("Muscles").padding(.top, 8)
                            MuscleTags(primary: regionOverrides(base: e.name, variation: v)?.primary ?? e.primary,
                                       secondary: regionOverrides(base: e.name, variation: v)?.secondary ?? e.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Styles") {
                    ForEach(styles) { s in
                        Button { editingStyle = s } label: {
                            HStack {
                                Text(s.label.isEmpty ? "Style" : s.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                                Spacer()
                                if let last = lastSession(versionId: v.id, styleId: s.id, workouts: store.workouts, versions: store.versions), last.sameStyle {
                                    Text("\(last.daysAgo)d ago").font(.system(size: 13)).foregroundStyle(p.muted)
                                }
                                Chevron()
                            }
                        }
                        .swipeActions { Button(role: .destructive) { store.deleteStyle(s.id) } label: { Label("Delete", systemImage: "trash") } }
                    }
                    Button { newStyle = true } label: { Label("Add style", systemImage: "plus").foregroundStyle(p.accent) }
                }
                Section {
                    NavigationLink { ExerciseProgressView(versionId: v.id) } label: { Label("Progress over time", systemImage: "chart.xyaxis.line") }
                }
                Section {
                    NavigationLink { FormCuesView(versionId: v.id) } label: {
                        HStack {
                            Label("Form cues", systemImage: "play.rectangle")
                            Spacer()
                            let n = store.formCueCount(v.id)
                            if n > 0 { Text("\(n)").font(.system(size: 15, weight: .bold)).foregroundStyle(p.accent) }
                        }
                    }
                }
                Section("Defaults") {
                    // Where every workout starts; a workout's own pick (the gear or the card) beats it.
                    Button { editingRange = true } label: {
                        HStack {
                            Text("Rep range").foregroundStyle(p.text)
                            Spacer()
                            Text("\(v.repMin)-\(v.repMax)").font(.system(size: 16, weight: .heavy)).monospacedDigit().foregroundStyle(p.accent)
                            Chevron()
                        }
                    }
                    Stepper("Working sets \(v.defaultSets)", value: b.defaultSets, in: 1...8)
                    Toggle("Warm-up set", isOn: b.defaultWarmup)
                }
                Section("Notes") {
                    TextField("Setup, what to watch", text: $draftNotes, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($notesFocused)
                }
            }
            .scrollContentBackground(.hidden)
            .background(p.bg.ignoresSafeArea())
            .tint(p.accent)
            .navigationTitle(store.baseName(v))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(p.bg, for: .navigationBar)
            .onAppear(perform: loadDrafts)
            .onChange(of: notesFocused) { _, _ in commitNotes() }
            .onDisappear(perform: commitNotes)
            .sheet(item: $editingStyle) { s in
                StyleEditorSheet(version: v, style: s).presentationDetents([.large]).presentationBackground(p.card)
            }
            .sheet(isPresented: $newStyle) {
                StyleEditorSheet(version: v, style: nil).presentationDetents([.large]).presentationBackground(p.card)
            }
            .sheet(isPresented: $editingRange) {
                RepRangeSheet(range: RepRange(v.repMin, v.repMax)) { r in
                    guard var nv = store.version(versionId) else { return }
                    nv.repMin = r.lo; nv.repMax = r.hi; store.put(nv)
                }
                .presentationBackground(p.card)
            }
        }
    }
}

/// Make or change a style of a variation.
struct StyleEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let version: Version
    let style: Style?
    @State private var spec = StyleSpec()
    @State private var name = ""
    var onSave: ((Style) -> Void)? = nil

    init(version: Version, style: Style?, onSave: ((Style) -> Void)? = nil) {
        self.version = version; self.style = style; self.onSave = onSave
        if let s = style {
            _spec = State(initialValue: StyleSpec(attachment: s.attachment, cableHeight: s.cableHeight.flatMap { CableHeight(rawValue: $0) },
                                                  benchAngle: s.benchAngle, barType: s.barType, grip: s.grip, machine: s.machine))
            _name = State(initialValue: s.name ?? "")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style == nil ? "New style" : "Style").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                        Text(store.fullName(version)).font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    Spacer()
                    Button("Close") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
                }
                Card(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Style")
                        StyleFields(family: version.family, position: version.position, spec: $spec)
                        TextField("Name, optional", text: $name)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                            .padding(.horizontal, 12).frame(height: 40)
                            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                            .foregroundStyle(p.text)
                    }
                }
                let preview = name.isEmpty ? spec.label : name
                Text(preview.isEmpty ? "Pick at least one thing" : preview).font(.system(size: 15, weight: .semibold)).foregroundStyle(preview.isEmpty ? p.muted : p.accent)
                PillButton(title: "Save", style: .primary, full: true) {
                    guard !preview.isEmpty else { return }
                    var s = style ?? spec.style(for: version.id)
                    s.attachment = spec.attachment; s.cableHeight = spec.cableHeight?.rawValue; s.benchAngle = spec.benchAngle
                    s.barType = spec.barType; s.grip = spec.grip; s.machine = spec.machine
                    s.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name.trimmingCharacters(in: .whitespaces)
                    store.put(s)
                    onSave?(s)
                    dismiss()
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
