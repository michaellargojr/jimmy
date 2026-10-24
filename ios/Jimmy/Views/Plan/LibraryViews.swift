import SwiftUI

// Exercises tab: bases by muscle > a base's variations > a variation's styles.

struct ExercisesList: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var query = ""
    @State private var muscle: MuscleGroup? = nil
    @State private var all = false

    private struct MuscleSection: Identifiable { var id: String { muscle.rawValue }; var muscle: MuscleGroup; var list: [Exercise] }

    private var grouped: [MuscleSection] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let used = store.usedExerciseIds
        let pool = store.exercises.filter { e in
            (all || !q.isEmpty || used.contains(e.id))
            && (q.isEmpty || e.name.lowercased().contains(q) || e.aliases.contains { $0.lowercased().contains(q) })
        }
        let groups = muscle.map { [$0] } ?? MuscleGroup.chipOrder
        return groups.compactMap { m in
            let list = pool.filter { muscle == nil ? $0.muscleGroup == m : $0.groups.contains(m) }.sorted { $0.name < $1.name }
            return list.isEmpty ? nil : MuscleSection(muscle: m, list: list)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(placeholder: "Search exercises", text: $query)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(text: "Mine", on: !all, small: true) { all = false }
                    Chip(text: "All", on: all, small: true) { all = true }
                    Rectangle().fill(p.border).frame(width: 1, height: 20)
                    ForEach(MuscleGroup.chipOrder, id: \.self) { m in
                        Chip(text: m.label, on: muscle == m, small: true) { muscle = muscle == m ? nil : m }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 6)
            List {
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
                    Text(query.isEmpty ? (all ? "Nothing here." : "Nothing yet. Tap New or All.") : "Nothing matches \"\(query)\".")
                        .font(.system(size: 14)).foregroundStyle(p.muted).listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
            }
            .cardList()
        }
        .background(p.bg.ignoresSafeArea())
    }

    private func baseRow(_ e: Exercise) -> some View {
        let vs = store.variations(of: e.id)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(vs.isEmpty ? p.secondary : p.text)
                Text(vs.isEmpty ? e.primary.joined(separator: ", ") : vs.map { store.variationText($0) }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(2)
            }
            Spacer()
            if !vs.isEmpty { Text("\(vs.count)").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
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
                    MusclesLine(primary: e.primary, secondary: e.secondary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .rowCard(p, radius: Radius.card)
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
                    } header: {
                        SectionLabel("Add").padding(.leading, 16)
                    }
                }
                Section {
                    PillButton(title: "Other variation", icon: "plus", full: true) { adding = true }
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(store.variationText(v)).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                Text([last.map { "\($0.daysAgo == 0 ? "today" : "\($0.daysAgo)d ago")" + (topSet($0.item).map { " · \($0.formatted)" } ?? "") },
                      styles.isEmpty ? nil : "\(styles.count) style\(styles.count == 1 ? "" : "s")",
                      "\(v.repRange) reps"].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func sessions(_ v: Version) -> Int {
        store.workouts.filter { w in w.items.contains { $0.versionId == v.id && $0.sets.contains { $0.hasData } } }.count
    }
}

/// "Side delt" in the accent, then "also upper traps" muted. Plain words for beginners.
struct MusclesLine: View {
    @Environment(\.palette) private var p
    let primary: [String]
    let secondary: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if primary.isEmpty && secondary.isEmpty {
                Text("Muscles not set").font(.system(size: 14)).foregroundStyle(p.muted)
            }
            if !primary.isEmpty {
                Text(capitalized(primary.joined(separator: ", "))).font(.system(size: 16, weight: .bold)).foregroundStyle(p.accent)
            }
            if !secondary.isEmpty {
                Text("also " + secondary.joined(separator: ", ")).font(.system(size: 14)).foregroundStyle(p.muted)
            }
        }
    }
}

/// One variation: rep range, defaults, notes, its styles, and progress.
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.baseName(v)).font(.system(size: 24, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
                        Text(store.variationText(v)).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
                        if let e = store.base(of: v) {
                            MusclesLine(primary: regionOverrides(base: e.name, variation: v)?.primary ?? e.primary,
                                        secondary: regionOverrides(base: e.name, variation: v)?.secondary ?? e.secondary)
                                .padding(.top, 6)
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
                Section("Rep range") {
                    Stepper("Min \(v.repMin)", value: b.repMin, in: 1...50)
                    Stepper("Max \(v.repMax)", value: b.repMax, in: 1...60)
                    Text("Go up when set 1 reaches \(v.repMax + UP_FIRST_OFFSET) and set 2 reaches \(v.repMax + UP_SECOND_OFFSET). Go down when set 1 is under \(v.repMin).")
                        .font(.system(size: 13)).foregroundStyle(p.muted)
                }
                Section("Defaults") {
                    Stepper("Working sets \(v.defaultSets)", value: b.defaultSets, in: 1...8)
                    Toggle("Warm-up set", isOn: b.defaultWarmup)
                }
                Section("Notes") {
                    TextField("Setup, what to watch", text: $draftNotes, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($notesFocused)
                }
                Section {
                    NavigationLink { ExerciseProgressView(versionId: v.id) } label: { Label("Progress over time", systemImage: "chart.xyaxis.line") }
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
