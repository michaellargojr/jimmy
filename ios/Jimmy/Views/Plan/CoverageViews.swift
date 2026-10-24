import SwiftUI

// Goals and coverage on a split. The coverage card is text first: what the split does right,
// then suggestions. The same card sits inside each routine, tagged with the split name,
// because coverage is always judged on the whole split.

/// The goals row on the split screen: tapped goals as lime chips and the first words of the text.
struct GoalsRow: View {
    @Environment(\.palette) private var p
    let goals: SplitGoals
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { SectionLabel("Goals"); Spacer(); Chevron() }
            if goals.isEmpty {
                Text("What do you want to look like?").font(.system(size: 15)).foregroundStyle(p.muted)
            } else {
                FlowLayout(spacing: 7) {
                    ForEach(goals.picks.compactMap(suggestedGoal)) { g in Chip(text: g.label, on: true, small: true) }
                    if !goals.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("“\(firstWords(goals.text))”").font(.system(size: 14)).foregroundStyle(p.muted).frame(height: 32)
                    }
                }
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
    private func firstWords(_ s: String) -> String {
        let words = s.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let head = words.prefix(5).joined(separator: " ")
        return words.count > 5 ? head + "…" : head
    }
}

/// The sheet: one free-text field and the suggested goals to tap. Saves as you go.
struct GoalsSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let splitId: String
    @State private var goals = SplitGoals()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Goals").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                Spacer()
                Button("Done") { save(); dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
            }
            TextField("Be as descriptive as possible. What shape do you want to look like?", text: $goals.text, axis: .vertical)
                .lineLimit(3...8)
                .focused($focused)
                .padding(12)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .foregroundStyle(p.text)
                .onChange(of: goals.text) { _, _ in save() }
            FlowLayout(spacing: 8) {
                ForEach(SUGGESTED_GOALS) { g in
                    Chip(text: g.label, on: goals.picks.contains(g.id)) {
                        if let i = goals.picks.firstIndex(of: g.id) { goals.picks.remove(at: i) } else { goals.picks.append(g.id) }
                        save()
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(p.card)
        .onAppear { goals = store.splits.first { $0.id == splitId }?.goals ?? SplitGoals() }
    }

    private func save() {
        guard var s = store.splits.first(where: { $0.id == splitId }) else { return }
        let g = SplitGoals(text: goals.text, picks: goals.picks)
        if s.goals != g { s.goals = g.isEmpty ? nil : g; store.put(s) }
    }
}

/// What the split does right, then suggestions. `routineId` marks the day the card sits on,
/// so suggestions it can fix come first and say "here".
struct CoverageCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let splitId: String
    var routineId: String? = nil
    @State private var adding: AddTarget? = nil

    struct AddTarget: Identifiable { let exercise: Exercise; let routineId: String; var id: String { exercise.id + routineId } }

    private var split: Split? { store.splits.first { $0.id == splitId } }

    var body: some View {
        if let s = split {
            let report = s.coverage ?? rulesReport(split: s, store: store)
            let o = ordered(report.suggestions)
            let shown = o.0, hidden = o.1
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink { CoverageDetailView(splitId: splitId) } label: {
                    HStack {
                        SectionLabel("Coverage")
                        if routineId != nil { Badge(text: s.name) }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                if !report.right.isEmpty {
                    SectionLabel("Doing right")
                    ForEach(report.right.prefix(routineId == nil ? 2 : 1)) { f in line(f, button: false) }
                }
                if !shown.isEmpty {
                    SectionLabel("Suggestions").padding(.top, 2)
                    ForEach(shown) { f in line(f, button: true) }
                }
                if hidden > 0 {
                    NavigationLink { CoverageDetailView(splitId: splitId) } label: {
                        Text("\(hidden) more").font(.system(size: 13, weight: .semibold)).foregroundStyle(p.muted).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .task(id: coverageFingerprint(s, store: store)) { CoverageAssistant.shared.refresh(splitId, store: store) }
            .sheet(item: $adding) { t in
                AddExerciseSheet(base: t.exercise) { v, st in
                    guard var r = store.routine(t.routineId) else { return }
                    r.items.append(RoutineItem(versionId: v.id, styleId: st?.id)); store.put(r)
                }
                .presentationDetents([.large])
                .presentationBackground(p.card)
            }
        }
    }

    /// On a routine, the suggestions this day can fix first; the rest fold behind "n more".
    private func ordered(_ all: [Finding]) -> ([Finding], Int) {
        guard let routineId else { return (all, 0) }
        let here = all.filter { $0.routineId == routineId }
        let rest = all.filter { $0.routineId != routineId }
        let shown = Array((here + rest).prefix(max(here.count, 2)))
        return (shown, all.count - shown.count)
    }

    private func line(_ f: Finding, button: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Mark(mark: f.mark)
            VStack(alignment: .leading, spacing: 6) {
                Text(f.text).font(.system(size: 15)).foregroundStyle(p.text).fixedSize(horizontal: false, vertical: true)
                if button, let base = f.addBase, let target = f.routineId.flatMap({ store.routine($0) }) {
                    Button {
                        if let e = store.exercise(named: base) { adding = AddTarget(exercise: e, routineId: target.id) }
                    } label: {
                        Text(target.id == routineId ? "Add \(base) here" : "Add \(base) to \(target.name)")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent)
                            .frame(height: 30).padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(p.accent, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// The mark beside a finding: lime touches a goal, dim is low, hollow is untrained.
struct Mark: View {
    @Environment(\.palette) private var p
    let mark: FindingMark
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(mark == .none ? p.muted : .clear, lineWidth: 1.5))
            .frame(width: 8, height: 18)
            .padding(.top, 1)
    }
    private var fill: Color {
        switch mark {
        case .goal, .good: return p.accent
        case .low: return p.accent.opacity(0.42)
        case .none: return .clear
        }
    }
}

/// Every muscle with its sets a week. Where a beginner learns the names.
struct CoverageDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let splitId: String

    var body: some View {
        if let s = store.splits.first(where: { $0.id == splitId }) {
            let volume = splitVolume(s, store: store)
            let goals = goalRegions(s.goals ?? SplitGoals())
            let top = Swift.max(volume.map(\.total).max() ?? 1, COVERAGE_HEAVY)
            let report = s.coverage ?? rulesReport(split: s, store: store)
            List {
                if !report.suggestions.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(report.suggestions) { f in
                                HStack(alignment: .top, spacing: 10) { Mark(mark: f.mark); Text(f.text).font(.system(size: 15)).foregroundStyle(p.text) }
                            }
                        }
                        .padding(16).rowCard(p, radius: Radius.card)
                    }
                }
                Section {
                    VStack(spacing: 8) {
                        ForEach(volume.sorted { $0.total > $1.total }) { v in
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Text(regionName(v.region).name).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.text).lineLimit(1)
                                    if goals[v.region] != nil { RoundedRectangle(cornerRadius: 2).fill(p.accent).frame(width: 6, height: 6) }
                                }
                                .frame(width: 128, alignment: .leading)
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(p.elevated)
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(v.total >= COVERAGE_GOOD ? p.accent : p.accent.opacity(0.42))
                                            .frame(width: Swift.max(0, g.size.width * v.total / top))
                                    }
                                }
                                .frame(height: 10)
                                Text("\(v.rounded)").font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(p.muted).frame(width: 26, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16).rowCard(p, radius: Radius.card)
                } header: {
                    SectionLabel("Sets a week").padding(.leading, 16)
                }
            }
            .cardList()
            .navigationTitle("Coverage")
            .toolbarBackground(p.bg, for: .navigationBar)
        }
    }
}

/// Wraps its children into rows. iOS 17 has no built-in flow layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = Swift.max(rowH, sz.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing; rowH = Swift.max(rowH, sz.height)
        }
    }
}

extension AppStore {
    /// A base by name, created from the library when the person has not used it yet.
    func exercise(named name: String) -> Exercise? {
        if let e = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return e }
        guard let lb = libraryBase(named: name) else { return nil }
        let e = lb.exercise
        put(e)
        return e
    }
}
