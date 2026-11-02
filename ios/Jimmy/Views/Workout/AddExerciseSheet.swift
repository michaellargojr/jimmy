import SwiftUI

/// Type the base, tap a variation you have, or set up a new variation and style.
/// Opened from an exercise page in Plan (`base` set), it is just the setup: variation, style, Add.
struct AddExerciseSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    var base: Exercise? = nil
    /// Overrides the heading, as in "Copy to" from the history page.
    var title: String? = nil
    let onPick: (Version, Style?) -> Void

    @State private var query = ""
    @State private var chosen: Exercise? = nil
    @State private var newBaseName: String? = nil
    @State private var newBaseGroup: MuscleGroup? = nil
    @State private var variation = VariationSpec(family: .dumbbell)
    @State private var style = StyleSpec()
    @State private var started = false
    /// Naming a machine in the Machine block, and the name typed there.
    @State private var naming: MachineNaming? = nil
    @State private var machineText = ""
    /// You switched the app's pick for a machine name (variation or style).
    @State private var flipped = false
    /// The Nickname field: the app's suggestion (or the matching variation's nickname) until you type in it.
    @State private var nick = ""
    @State private var nickTyped = false
    @FocusState private var focused: Bool

    init(base: Exercise? = nil, title: String? = nil, onPick: @escaping (Version, Style?) -> Void) {
        self.base = base; self.title = title; self.onPick = onPick
        _chosen = State(initialValue: base)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title ?? (base == nil ? "Add exercise" : "Add variation")).font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                Spacer()
                Button("Close") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
            }
            if let b = chosen { basePage(b) }
            else if let n = newBaseName { groupPage(n) }
            else { searchPage }
        }
        .padding(16)
        .onAppear {
            guard !started, let b = base else { return }
            started = true; startSetup(b)
        }
        .task {
            guard chosen == nil else { return }
            // Focus once the sheet has settled, or the keyboard never attaches.
            try? await Task.sleep(nanoseconds: 450_000_000)
            focused = true
        }
    }

    // MARK: Search

    private struct Hit: Identifiable { var id: String { base.id }; var base: Exercise; var mine: Bool }

    /// Yours first, then the library when typing; within each, best match first (see searchRank).
    private var hits: [Hit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let used = store.usedExerciseIds
        func rank(_ e: Exercise) -> Int? {
            if let r = searchRank(e, q) { return r }
            let nick = libraryBase(named: e.name)?.variations.contains { $0.nick?.lowercased().contains(q) == true } ?? false
            return nick ? 2 : nil
        }
        let ranked: [(hit: Hit, rank: Int)] = store.exercises.compactMap { e in
            rank(e).map { (Hit(base: e, mine: used.contains(e.id)), $0) }
        }
        let order: ((hit: Hit, rank: Int), (hit: Hit, rank: Int)) -> Bool = { a, b in
            a.rank != b.rank ? a.rank < b.rank : a.hit.base.name < b.hit.base.name
        }
        let mine = ranked.filter { $0.hit.mine }.sorted(by: order).map { $0.hit }
        let rest = q.isEmpty ? [] : ranked.filter { !$0.hit.mine }.sorted(by: order).map { $0.hit }
        return mine + rest
    }

    private var searchPage: some View {
        VStack(spacing: 10) {
            TextField("Exercise", text: $query)
                .focused($focused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(12)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .foregroundStyle(p.text)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(hits) { h in
                        Button { open(h.base) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.base.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                                    Text(h.mine ? variationsLine(h.base) : h.base.muscleGroup.label).font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(1)
                                }
                                Spacer()
                                if h.mine {
                                    Text("\(store.variations(of: h.base.id).count)").font(.system(size: 14, weight: .heavy)).foregroundStyle(p.accent)
                                }
                                Chevron()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    let q = query.trimmingCharacters(in: .whitespaces)
                    if !q.isEmpty, !hits.contains(where: { $0.base.name.caseInsensitiveCompare(q) == .orderedSame }) {
                        Button { newBaseName = q; focused = false } label: {
                            HStack {
                                Text("New: \(q)").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.accent)
                                Spacer()
                                Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(p.accent)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func variationsLine(_ b: Exercise) -> String {
        let vs = store.variations(of: b.id)
        return vs.map { store.variationText($0) }.joined(separator: ", ")
    }

    private func open(_ b: Exercise) {
        focused = false
        chosen = b
        let vs = store.variations(of: b.id)
        let lib = libraryBase(named: b.name)
        if let v = vs.first { variation = VariationSpec(v) }
        else if let s = lib?.variations.first { variation = s }
        else { variation = VariationSpec(family: .dumbbell) }
        style = StyleSpec()
        naming = nil; machineText = ""; flipped = false
        nick = ""; nickTyped = false
    }

    /// From Plan: start on a common variation you don't have yet, so Add makes something new.
    private func startSetup(_ b: Exercise) {
        let mine = store.variations(of: b.id)
        let lib = libraryBase(named: b.name)
        if let s = lib?.variations.first(where: { s in !mine.contains { $0.key == s.key } }) { variation = s }
        else if let v = mine.first { variation = VariationSpec(v) }
        else { variation = VariationSpec(family: .dumbbell) }
        style = StyleSpec()
        naming = nil; machineText = ""; flipped = false
        nick = ""; nickTyped = false
    }

    // MARK: New base: pick the muscle group

    private func groupPage(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name).font(.system(size: 24, weight: .heavy)).foregroundStyle(p.text)
                Spacer()
                Button("Back") { newBaseName = nil } .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.muted)
            }
            SectionLabel("Muscle")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(MuscleGroup.chipOrder, id: \.self) { g in
                    Button {
                        chosen = store.addBase(name: name, group: g)
                        variation = VariationSpec(family: .dumbbell); style = StyleSpec()
                        nick = ""; nickTyped = false
                    } label: {
                        Text(g.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
    }

    // MARK: Base page: your variations, or set up a new one

    private func basePage(_ b: Exercise) -> some View {
        let mine = store.variations(of: b.id)
        let verdict = store.addVerdict(base: b, variation: variation, style: style)
        let showMachines = variation.family == .machine
        let needsName = naming != nil && machineName(machineText) == nil
        let call = variationCall(b, verdict: verdict)
        let asVariation = call.map { flipped ? !$0.appPicksVariation : $0.appPicksVariation }
        let autoNick = autoNickname(b, verdict: verdict, call: call, asVariation: asVariation)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(b.name).font(.system(size: 26, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
                    Spacer()
                    if base == nil {
                        Button("Change") { chosen = nil; style = StyleSpec() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.muted)
                    }
                }
                if base == nil, !mine.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(mine) { v in variationRow(v) }
                    }
                }
                Card(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Variation")
                        VariationFields(legs: b.isLegs, armRow: b.hasArmPosition, spec: $variation)
                        Rectangle().fill(p.line).frame(height: 1).padding(.vertical, 2)
                        SectionLabel("Nickname")
                        NicknameField(text: Binding(get: { nickTyped ? nick : (autoNick ?? "") },
                                                    set: { nick = $0; nickTyped = true }))
                    }
                }
                if showMachines {
                    Card(padding: 14) {
                        MachineBlock(base: b, spec: $variation, naming: $naming, name: $machineText)
                    }
                }
                Card(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Style")
                        StyleFields(family: variation.family, position: variation.position, armPosition: variation.armPosition, spec: $style, showsMachineName: naming == nil)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    if !needsName {
                        FlowRow(spacing: 10, lineSpacing: 6) {
                            if let call, let asVariation {
                                Text(asVariation ? "New variation" : "New style").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.accent)
                                    .fixedSize().frame(minHeight: 24)
                                if asVariation { specPill(call.variation, base: b) }
                            } else {
                                Text(verdictText(verdict, base: b)).font(.system(size: 14, weight: .semibold)).foregroundStyle(verdictColor(verdict))
                                    .fixedSize().frame(minHeight: 24)
                                if variation.family == .machine, verdict == .newVariation { specPill(variation, base: b) }
                            }
                        }
                        .frame(minHeight: 24)
                        if let asVariation {
                            VariationOrStyle(asVariation: asVariation) { v in
                                if let call { flipped = v != call.appPicksVariation }
                            }
                        }
                    }
                    let have = base != nil && verdict.isExisting && call == nil
                    PillButton(title: "Add", style: .primary, full: true) { add(b, call: call, asVariation: asVariation ?? false, autoNick: autoNick) }
                        .disabled(have || needsName).opacity(have || needsName ? 0.4 : 1)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: variation.family) { _, f in
            if f != .machine { naming = nil; machineText = ""; variation.machine = nil; variation.loading = nil }
        }
        .onChange(of: naming) { _, n in
            flipped = false
            if n != nil { style.machine = nil }
        }
    }

    // MARK: Machines

    /// A call the app made that you can switch: a second machine you named (its own variation,
    /// or a style of yours), or a new style (a style, or its own variation).
    private struct VariationCall {
        /// The variation you have that a style would go on.
        var target: Version
        /// The variation it makes as its own.
        var variation: VariationSpec
        /// What stays a style on it (a grip beside a machine name).
        var rest: StyleSpec
        var appPicksVariation: Bool
    }

    private func variationCall(_ b: Exercise, verdict: AppStore.AddVerdict) -> VariationCall? {
        let types = machineTypes(forBase: b.name)
        if variation.family == .machine, case .another(let n)? = naming, verdict == .newVariation, machineName(machineText) != nil,
           let t = types.first(where: { $0.name == n }),
           let target = store.machines(of: t, baseId: b.id, arms: variation.arms, position: variation.position, arm: variation.armPosition,
                                       loading: variation.loading).first {
            return VariationCall(target: target, variation: variation, rest: style, appPicksVariation: true)
        }
        if naming == nil, case .newStyle(let v) = verdict, let own = ownVariation(of: style, beside: v, types: types) {
            return VariationCall(target: v, variation: own.spec, rest: own.rest,
                                 appPicksVariation: styleNameIsOwnVariation(style.machine, beside: v, types: types))
        }
        return nil
    }

    private func add(_ b: Exercise, call: VariationCall?, asVariation: Bool, autoNick: String?) {
        let had = Set(store.versions.map(\.id))
        let done: (Version, Style?) -> Void = { v, s in
            // A new variation takes what the field shows; one you have changes only if you typed.
            if !had.contains(v.id) || nickTyped { store.setNickname(v.id, nickTyped ? nick : autoNick) }
            finish(store.version(v.id) ?? v, s)
        }
        if let call {
            if asVariation {
                let v = store.makeVariation(base: b, spec: call.variation, like: call.target)
                done(v, store.makeStyle(for: v, spec: call.rest))
            } else {
                var st = style
                if naming != nil { st.machine = machineName(machineText) }
                done(call.target, store.makeStyle(for: call.target, spec: st))
            }
        } else if variation.family == .machine {
            let v = store.makeVariation(base: b, spec: variation, like: nil)
            done(v, store.makeStyle(for: v, spec: style))
        } else {
            let (v, s) = store.resolve(base: b, variation: variation, style: style)
            done(v, s)
        }
    }

    /// What the Nickname field shows until you type: a variation you have keeps its own
    /// nickname (or none); a new one gets the app's suggestion when every block matches.
    private func autoNickname(_ b: Exercise, verdict: AppStore.AddVerdict, call: VariationCall?, asVariation: Bool?) -> String? {
        if let call, let asVariation {
            guard asVariation else { return store.nickname(call.target) }
            return suggestNickname(base: b.name, family: call.variation.family, position: call.variation.position,
                                   armPosition: call.variation.armPosition,
                                   tag: call.variation.tag, styleMachines: [call.rest.machine].compactMap { $0 })
        }
        switch verdict {
        case .existing(let v, _), .newStyle(let v):
            return store.nickname(v)
        case .newVariation:
            let named = naming != nil ? machineName(machineText) : nil
            return suggestNickname(base: b.name, family: variation.family, position: variation.position,
                                   armPosition: variation.armPosition,
                                   tag: variation.tag, styleMachines: [style.machine, named].compactMap { $0 })
        }
    }

    /// The variation a pick makes, as its chip: "Machine | Iso-lateral | D Stars | One arm".
    private func specPill(_ s: VariationSpec, base b: Exercise) -> some View {
        VariationPill(parts: variationChipWords(s, legs: b.isLegs), size: .small)
    }

    private func variationRow(_ v: Version) -> some View {
        let styles = store.styles(of: v.id)
        let last = lastSession(versionId: v.id, workouts: store.workouts, versions: store.versions)
        return VStack(alignment: .leading, spacing: 6) {
            Button { finish(v, lastStyle(v)) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        VariationChips(tags: store.variationChips(v), nickname: store.nickname(v))
                        if let last {
                            Text("\(last.daysAgo == 0 ? "today" : "\(last.daysAgo)d ago") - " + last.item.sets.filter { $0.isDone }.prefix(3).map { $0.formatted }.joined(separator: ", "))
                                .font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(p.accent)
                }
            }
            .buttonStyle(.plain)
            if !styles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(styles) { s in Chip(text: s.label, on: lastStyle(v)?.id == s.id, small: true) { finish(v, s) } }
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }

    /// The style used the last time this variation was logged.
    private func lastStyle(_ v: Version) -> Style? {
        for w in sortedNewestFirst(store.workouts) {
            if let it = w.items.first(where: { $0.versionId == v.id && $0.styleId != nil }) { return store.style(it.styleId) }
        }
        return nil
    }

    private func verdictText(_ v: AppStore.AddVerdict, base b: Exercise) -> String {
        switch v {
        case .existing: return "Matches a variation you have"
        case .newStyle: return "New style"
        case .newVariation: return "New variation"
        }
    }
    private func verdictColor(_ v: AppStore.AddVerdict) -> Color {
        if case .existing = v { return p.muted }
        return p.accent
    }

    private func finish(_ v: Version, _ s: Style?) {
        onPick(v, s)
        dismiss()
    }
}
