import SwiftUI

/// The routine builder (Michael's picks A and 2). New routine: name it, then tick exercises out of
/// your existing routines (tap one to open it), or from the exercise list: search or browse by
/// muscle group like Plan › Exercises, open an exercise and tick its variations, or set up a new
/// variation or a new exercise right there. Create routine. From a routine's page or the split
/// page's edit sheet it is the same without the name, and Add. Nothing is saved until Create or Add.
struct RoutineBuilderSheet: View {
    enum Mode: Equatable {
        case create
        /// Adding to a routine, which is left out of the Routines tab.
        case add(to: String)
    }
    private enum Tab { case routines, exercises }

    /// The full setup, opened from inside the builder.
    private enum Setup: Identifiable {
        case variation(Exercise)
        case newBase(String)
        var id: String {
            switch self {
            case let .variation(e): return "v-" + e.id
            case let .newBase(n): return "n-" + n
            }
        }
    }

    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    /// The name (create only) and the rows, once Create or Add is tapped.
    let onDone: (String, PickedExercises) -> Void

    @State private var name = ""
    /// Create only: the name page comes first, by itself; then the exercises.
    @State private var named = false
    @State private var tab: Tab = .routines
    @State private var picks: [BuilderPick] = []
    /// The routine opened in the Routines tab.
    @State private var openRoutine: String? = nil
    /// The exercise opened in the Exercises tab.
    @State private var openBase: String? = nil
    @State private var query = ""
    @State private var all = true
    @State private var muscle: MuscleGroup? = nil
    @State private var bases: [BaseUse] = []
    @State private var setup: Setup? = nil
    /// Groups you said to copy as a group, and every group already asked about.
    @State private var keep: Set<GroupKey> = []
    @State private var asked: Set<GroupKey> = []
    /// The "Copy as a superset?" question, when two or more of a group are ticked.
    @State private var offer: GroupOffer? = nil
    @FocusState private var nameFocused: Bool

    private var isCreate: Bool { mode == .create }
    private var routines: [Routine] {
        let skip: String? = { if case let .add(id) = mode { return id }; return nil }()
        return store.routines.filter { $0.id != skip && !$0.items.isEmpty }
    }
    private var nameTaken: Bool { isCreate && routineNameTaken(name, in: store.routines) }
    private var canFinish: Bool { !picks.isEmpty && !nameTaken }
    private var onNamePage: Bool { isCreate && !named }
    private var nameReady: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !nameTaken }
    private var openedRoutine: Routine? { openRoutine.flatMap { rid in routines.first { $0.id == rid } } }
    private var openedBase: BaseUse? { openBase.flatMap { bid in bases.first { $0.id == bid } } }
    /// Inside a routine or an exercise: how many of its rows are ticked.
    private var tickedHere: Int? {
        if let r = openedRoutine {
            return picks.filter { if case let .routine(pk) = $0 { return pk.routineId == r.id }; return false }.count
        }
        if let b = openedBase {
            return b.variations.filter { u in picks.contains { versionId(of: $0) == u.id } }.count
        }
        return nil
    }
    private var canTap: Bool { onNamePage ? nameReady : tickedHere.map { $0 > 0 } ?? canFinish }
    /// Inside a routine or an exercise the button only takes the ticks back to the lists, so you can
    /// go on to another routine; the routine is made (or added to) from the first page.
    private var buttonTitle: String {
        func ex(_ n: Int) -> String { n == 1 ? "1 exercise" : "\(n) exercises" }
        if onNamePage { return "Next" }
        if let n = tickedHere { return n == 0 ? "Add to routine" : "Add to routine - \(ex(n))" }
        let n = picks.count
        if isCreate { return n == 0 ? "Create routine" : "Create routine - \(ex(n))" }
        return n == 0 ? "Add exercises" : "Add \(ex(n))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if onNamePage {
                header
                nameField
                Spacer(minLength: 0)
            } else if let r = openedRoutine {
                insideRoutine(r)
            } else if let b = openedBase {
                insideBase(b)
            } else {
                if isCreate { chooseHeader } else { header }
                tabs
                if tab == .routines { routineList } else { exerciseList }
            }
            PillButton(title: buttonTitle, style: .primary, full: true, height: 54) {
                if onNamePage { toExercises() } else if tickedHere != nil { addToRoutine() } else { finish() }
            }
                .disabled(!canTap)
                .opacity(canTap ? 1 : 0.4)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
                .background(p.card)
        }
        .background(p.card)
        .alert(offer.map(\.title) ?? "", isPresented: Binding(get: { offer != nil }, set: { if !$0 { offer = nil } }), presenting: offer) { o in
            Button(o.copyTitle) { answer(o, copy: true) }
            Button("Add separately", role: .cancel) { answer(o, copy: false) }
        } message: { o in
            Text(o.message)
        }
        .interactiveDismissDisabled(!picks.isEmpty || !name.trimmingCharacters(in: .whitespaces).isEmpty)
        .sheet(item: $setup) { s in
            // A ZStack, not a Group: a Group hands the detents to each child.
            ZStack {
                switch s {
                case let .variation(e): AddExerciseSheet(base: e) { v, st in added(v, st) }
                case let .newBase(n): AddExerciseSheet(newBase: n) { v, st in added(v, st) }
                }
            }
            .presentationDetents([.large])
            .presentationBackground(p.card)
        }
        .onAppear {
            reload()
            if routines.isEmpty { tab = .exercises }
        }
        .onChange(of: store.versions.count) { _, _ in reload() }
        .onChange(of: store.exercises.count) { _, _ in reload() }
        .task {
            #if DEBUG
            if demo() { return }
            #endif
            guard isCreate else { return }
            // Focus once the sheet has settled, or the keyboard never attaches.
            try? await Task.sleep(nanoseconds: 450_000_000)
            nameFocused = true
        }
    }

    // MARK: Top

    private var header: some View {
        HStack(spacing: 12) {
            Text(isCreate ? "New routine" : "Add exercises")
                .font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text).lineLimit(1)
            Spacer()
            Button("Cancel") { dismiss() }
                .font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
    }

    /// Above the lists, never inside one: a field in a List row loses the keyboard when rows change.
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Name").padding(.leading, 4)
            TextField("Name", text: $name)
                .focused($nameFocused)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .onSubmit { toExercises() }
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(p.text)
                .padding(.horizontal, 14).frame(height: 48)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            if nameTaken {
                Text("You already have \(name.trimmingCharacters(in: .whitespaces))")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(p.danger)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    /// After the name: back to it, and the one thing to do here, in big letters.
    private var chooseHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { named = false } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                    .frame(width: 44, height: 44)
                    .background(p.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to the name")
            Text("Choose your exercises")
                .font(.system(size: 28, weight: .heavy)).foregroundStyle(p.text)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            Chip(text: "Routines", on: tab == .routines) { nameFocused = false; tab = .routines }
            Chip(text: "Exercises", on: tab == .exercises) { nameFocused = false; tab = .exercises }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    /// Back, a title, and an optional button on the right, for an opened routine or exercise.
    private func drillHeader<Right: View>(_ title: String, back: @escaping () -> Void, @ViewBuilder right: () -> Right) -> some View {
        HStack(spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                    .frame(width: 44, height: 44)
                    .background(p.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Text(title).font(.system(size: 20, weight: .heavy)).foregroundStyle(p.text).lineLimit(1)
            Spacer(minLength: 8)
            right()
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    // MARK: Routines

    private var routineList: some View {
        List {
            Text("Choose exercises from existing routines")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 6, trailing: 20))
            if routines.isEmpty {
                Text("No routines with exercises yet.")
                    .font(.system(size: 15)).foregroundStyle(p.muted)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(routines) { r in
                Button { nameFocused = false; openRoutine = r.id } label: { routineCard(r) }
                    .buttonStyle(.plain)
                    .pickRow(p)
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
    }

    private func routineCard(_ r: Routine) -> some View {
        let n = picks.filter { if case let .routine(pk) = $0 { return pk.routineId == r.id }; return false }.count
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(r.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text).lineLimit(1)
                Text(r.items.compactMap { store.version($0.versionId).map { store.baseName($0) } }.joined(separator: " - "))
                    .font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(2)
            }
            Spacer(minLength: 8)
            addedLabel(n)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func insideRoutine(_ r: Routine) -> some View {
        let mine = r.items.indices.map { BuilderPick.routine(RoutinePick(routineId: r.id, index: $0)) }
        let every = mine.allSatisfy { picks.contains($0) }
        return VStack(spacing: 0) {
            drillHeader(r.name, back: { openRoutine = nil }) {
                Button(every ? "Remove all" : "Add all") {
                    if every { picks.removeAll { mine.contains($0) } } else { picks.append(contentsOf: mine.filter { !picks.contains($0) }) }
                }
                .font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
                .frame(minHeight: 44)
                .fixedSize()
            }
            List {
                ForEach(r.items.indices, id: \.self) { i in routineRow(r, i) }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
        }
    }

    private func routineRow(_ r: Routine, _ i: Int) -> some View {
        let pick = BuilderPick.routine(RoutinePick(routineId: r.id, index: i))
        let on = picks.contains(pick)
        let item = r.items[i]
        let v = store.version(item.versionId)
        let members = item.groupId.map { gid in r.items.indices.filter { r.items[$0].groupId == gid } } ?? []
        let badge = members.count > 1 ? members.firstIndex(of: i).map { groupLabels(count: members.count)[$0] } : nil
        return Button { toggle(pick) } label: {
            pickLabel(on: on, badge: badge, name: v.map { store.baseName($0) } ?? "Missing exercise", v: v,
                      style: store.style(item.styleId)?.label,
                      note: v.map { useNote($0) })
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .pickRow(p)
    }

    // MARK: Exercises (like Plan › Exercises)

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var exerciseList: some View {
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
                    let grouped = basesByMuscle(bases, mineOnly: !all, muscle: muscle)
                    ForEach(grouped) { g in
                        SectionLabel(g.muscle.label)
                            .padding(.leading, 12).padding(.top, 8)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 2, trailing: 16))
                        ForEach(g.bases) { b in baseRow(b) }
                    }
                    if grouped.isEmpty {
                        Text(all ? "Nothing here." : "Nothing yet. Tap All.")
                            .font(.system(size: 14)).foregroundStyle(p.muted)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                } else {
                    let results = searchBases(bases, query: trimmed, muscle: muscle)
                    ForEach(results) { b in baseRow(b) }
                    if !results.contains(where: { $0.exercise.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                        Button { setup = .newBase(trimmed) } label: {
                            HStack {
                                Text("New: \(trimmed)").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.accent)
                                Spacer()
                                Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(p.accent)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pickRow(p)
                    }
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
        }
    }

    /// Name and how many workouts had it; on the right what is ticked from it, else your variation count.
    private func baseRow(_ b: BaseUse) -> some View {
        let n = picks.filter { versionId(of: $0).flatMap { store.version($0)?.exerciseId } == b.id }.count
        return Button { openBase = b.id } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(b.exercise.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                    if b.workouts > 0 {
                        Text(workoutsText(b.workouts)).font(.system(size: 12, weight: .semibold)).foregroundStyle(p.muted)
                    }
                }
                Spacer(minLength: 8)
                if n > 0 { addedLabel(n) }
                else if b.mine { Text("\(b.variations.count)").font(.system(size: 14, weight: .heavy)).foregroundStyle(p.accent) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pickRow(p)
    }

    /// Your variations of the exercise, most workouts first, then Add variation for the full setup.
    private func insideBase(_ b: BaseUse) -> some View {
        VStack(spacing: 0) {
            drillHeader(b.exercise.name, back: { openBase = nil }) { EmptyView() }
            List {
                if b.variations.isEmpty {
                    Text("No variations yet.")
                        .font(.system(size: 15)).foregroundStyle(p.muted)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                ForEach(b.variations) { u in variationRow(u) }
                PillButton(title: "Add variation", icon: "plus", full: true) { setup = .variation(b.exercise) }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
        }
    }

    /// Ticked when the variation is in the new routine, from either tab. Unticking takes every one out.
    private func variationRow(_ u: VariationUse) -> some View {
        let on = picks.contains { versionId(of: $0) == u.id }
        return Button {
            if on { picks.removeAll { versionId(of: $0) == u.id } }
            else { picks.append(.variation(versionId: u.id, styleId: lastStyleId(u.id, workouts: store.workouts))) }
        } label: {
            pickLabel(on: on, badge: nil, name: nil, v: u.version, style: nil, note: u.note)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .pickRow(p)
    }

    // MARK: Pieces

    /// Every row has the same shape, so the list reads as one column: the name with its nickname
    /// beside it, then the chip on its own line, then a quiet line with the style and how often
    /// it was done ("Barbell - 3 Workouts"). A group member's numbered chip sits above the name,
    /// as on its Workout card ("Triset 1").
    private func pickLabel(on: Bool, badge: String?, name: String?, v: Version?, style: String?, note: String?) -> some View {
        let nickname = v.flatMap { store.nickname($0) }
        let tags = v.map { store.variationChips($0) } ?? []
        let quiet = [style, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - ")
        return HStack(spacing: 12) {
            RectCheck(on: on, size: 26)
            VStack(alignment: .leading, spacing: 5) {
                if let badge { Chip(text: badge, on: true, small: true).padding(.bottom, 1) }
                if let name {
                    nameLine(name, nickname: nickname)
                } else if let nickname {
                    NicknameTag(text: nickname, size: .small)
                }
                if !tags.isEmpty { VariationPill(parts: tags, size: .small) }
                if !quiet.isEmpty {
                    Text(quiet).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(p.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    /// The name with its nickname tag on the same line; the tag drops under it only when both don't fit.
    @ViewBuilder
    private func nameLine(_ name: String, nickname: String?) -> some View {
        let title = Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
        if let nickname {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { title.lineLimit(1).fixedSize(); NicknameTag(text: nickname, size: .small) }
                VStack(alignment: .leading, spacing: 5) { title.lineLimit(2); NicknameTag(text: nickname, size: .small) }
            }
        } else {
            title.lineLimit(2)
        }
    }

    @ViewBuilder
    private func addedLabel(_ n: Int) -> some View {
        if n > 0 {
            Text("\(n) added").font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent).fixedSize()
        }
    }

    private func useNote(_ v: Version) -> String {
        bases.first { $0.id == v.exerciseId }?.variations.first { $0.id == v.id }?.note ?? "Not done yet"
    }

    private func versionId(of pick: BuilderPick) -> String? {
        switch pick {
        case let .variation(v, _): return v
        case let .routine(pk):
            guard let r = store.routine(pk.routineId), r.items.indices.contains(pk.index) else { return nil }
            return r.items[pk.index].versionId
        }
    }

    private func toggle(_ pick: BuilderPick) {
        if let i = picks.firstIndex(of: pick) { picks.remove(at: i) } else { picks.append(pick) }
    }

    /// A variation set up from inside the builder is ticked, and its exercise opens to show it.
    private func added(_ v: Version, _ st: Style?) {
        picks.append(.variation(versionId: v.id, styleId: st?.id))
        reload()
        tab = .exercises
        openBase = v.exerciseId
    }

    private func reload() {
        bases = baseUses(exercises: store.exercises, versions: store.versions, workouts: store.workouts)
    }

    #if DEBUG
    /// -routineDemo build | buildOpen | buildExercises | buildBase: a name and a few ticks, for screenshots.
    private func demo() -> Bool {
        guard RoutineDemo.once("builder", for: ["build", "buildOpen", "buildExercises", "buildBase"]) else { return false }
        name = "Chest and Shoulders"
        named = true
        for r in routines.prefix(2) {
            for i in r.items.indices.prefix(2) { picks.append(.routine(RoutinePick(routineId: r.id, index: i))) }
        }
        switch RoutineDemo.step {
        case "buildOpen": openRoutine = routines.first?.id
        case "buildExercises": tab = .exercises
        case "buildBase":
            tab = .exercises
            if let b = bases.first(where: { $0.variations.count > 1 }) ?? bases.first {
                openBase = b.id
                if let u = b.variations.last { picks.append(.variation(versionId: u.id, styleId: nil)) }
            }
        default: break
        }
        return true
    }
    #endif

    /// Back to the lists from an opened routine or exercise; first asks about any group of that
    /// routine with two or more ticked.
    private func addToRoutine() {
        if let r = openedRoutine, ask(tickedGroups(picks, routines: store.routines).filter { $0.key.routineId == r.id }, then: .back) { return }
        openRoutine = nil
        openBase = nil
    }

    /// Puts the question up for the groups not asked about yet; false when there are none.
    private func ask(_ groups: [TickedGroup], then: GroupOffer.Then) -> Bool {
        let fresh = groups.filter { !asked.contains($0.key) }
        guard !fresh.isEmpty else { return false }
        offer = GroupOffer(groups: fresh.map { g in
            let r = store.routine(g.key.routineId)
            let names = g.indices.compactMap { r?.items[$0].versionId }.compactMap { store.version($0) }.map { store.workoutName($0) }
            return GroupOffer.Line(group: g, names: names, routine: r?.name ?? "")
        }, then: then)
        return true
    }

    private func answer(_ o: GroupOffer, copy: Bool) {
        for line in o.groups {
            asked.insert(line.group.key)
            if copy { keep.insert(line.group.key) } else { keep.remove(line.group.key) }
        }
        switch o.then {
        case .back: openRoutine = nil; openBase = nil
        case .finish: finish()
        }
    }

    private func toExercises() {
        guard nameReady else { return }
        nameFocused = false
        named = true
    }

    private func finish() {
        guard canFinish else { return }
        nameFocused = false
        if ask(tickedGroups(picks, routines: store.routines), then: .finish) { return }
        onDone(newRoutineName(name, taken: store.routines.map(\.name)), builtExercises(picks, routines: store.routines, keep: keep))
        dismiss()
    }
}

private extension View {
    /// A row on the sheet: its own rounded card, a little apart from the next.
    func pickRow(_ p: Palette) -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.elevated)
                .padding(.horizontal, 16).padding(.vertical, 3)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: 28, bottom: 3, trailing: 28))
    }
}

/// "Copy as a superset?" for one group, or "Copy the groups?" for several, when the ticks hold
/// two or more members of a group from a routine.
struct GroupOffer: Identifiable {
    enum Then { case back, finish }
    struct Line {
        var group: TickedGroup
        /// The ticked members, as their Workout cards call them.
        var names: [String]
        var routine: String
    }
    let id = UUID()
    var groups: [Line]
    var then: Then

    var title: String { groups.count == 1 ? "Copy as a \(groups[0].group.copyType.rawValue)?" : "Copy the groups?" }
    var copyTitle: String { groups.count == 1 ? "Copy as a \(groups[0].group.copyType.rawValue)" : "Copy the groups" }
    /// "Wrist Curl and Reverse Wrist Curl are a superset in Arms."
    var message: String {
        groups.map { l in
            let what = l.group.whole ? "are a \(l.group.type.rawValue)" : "are part of a \(l.group.type.rawValue)"
            let place = l.routine.isEmpty ? "" : " in \(l.routine)"
            return "\(listed(l.names)) \(what)\(place)."
        }
        .joined(separator: "\n")
    }

    private func listed(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
}
