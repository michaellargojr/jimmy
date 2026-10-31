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
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(hits) { h in
                        Button { open(h.base) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.base.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(h.mine ? p.accent : p.text)
                                    Text(h.mine ? variationsLine(h.base) : h.base.muscleGroup.label).font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(1)
                                }
                                Spacer()
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
        if let v = vs.first { variation = VariationSpec(family: v.family, arms: v.arms, position: v.position, tag: v.tag) }
        else if let s = lib?.variations.first { variation = s }
        else { variation = VariationSpec(family: .dumbbell) }
        style = StyleSpec()
    }

    /// From Plan: start on a common variation you don't have yet, so Add makes something new.
    private func startSetup(_ b: Exercise) {
        let mine = store.variations(of: b.id)
        let lib = libraryBase(named: b.name)
        if let s = lib?.variations.first(where: { s in !mine.contains { $0.key == s.key } }) { variation = s }
        else if let v = mine.first { variation = VariationSpec(family: v.family, arms: v.arms, position: v.position, tag: v.tag) }
        else { variation = VariationSpec(family: .dumbbell) }
        style = StyleSpec()
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
        let suggested = (libraryBase(named: b.name)?.variations ?? []).filter { s in !mine.contains { $0.key == s.key } }
        let verdict = store.addVerdict(base: b, variation: variation, style: style)
        return ScrollView {
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
                if base == nil, !suggested.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(suggested, id: \.self) { s in
                            Button { let v = store.makeVariation(base: b, spec: s); finish(v, nil) } label: {
                                HStack {
                                    Text(variationLabel(s, legs: b.isLegs)).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                                    if let n = s.nick { Text(n).font(.system(size: 12)).foregroundStyle(p.muted) }
                                    Spacer()
                                    Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
                                }
                                .padding(.horizontal, 14).frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(p.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Card(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Variation")
                        VariationFields(legs: b.isLegs, spec: $variation)
                    }
                }
                Card(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Style")
                        StyleFields(family: variation.family, position: variation.position, spec: $style)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(verdictText(verdict, base: b)).font(.system(size: 14, weight: .semibold)).foregroundStyle(verdictColor(verdict))
                    let have = base != nil && verdict.isExisting
                    PillButton(title: "Add", style: .primary, full: true) {
                        let (v, s) = store.resolve(base: b, variation: variation, style: style)
                        finish(v, s)
                    }
                    .disabled(have).opacity(have ? 0.4 : 1)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func variationRow(_ v: Version) -> some View {
        let styles = store.styles(of: v.id)
        let last = lastSession(versionId: v.id, workouts: store.workouts, versions: store.versions)
        return VStack(alignment: .leading, spacing: 6) {
            Button { finish(v, lastStyle(v)) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.variationText(v)).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        if let last {
                            Text("\(last.daysAgo == 0 ? "today" : "\(last.daysAgo)d ago") · " + last.item.sets.filter { $0.isDone }.prefix(3).map { $0.formatted }.joined(separator: ", "))
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
