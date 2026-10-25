import SwiftUI

/// The live workout: one full-screen pane per exercise (or per group), paged vertically.
struct WorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let workoutId: String

    @State private var current: Int? = 0
    @State private var showOverview = false
    @State private var adding: AddTarget? = nil
    /// Set by the Overview sheet; presented only after Overview has finished closing,
    /// because two sheets changing at once leaves the new one unable to take the keyboard.
    @State private var pendingAdd: AddTarget? = nil
    @State private var confirmFinish = false
    @State private var restEndsAt: Date? = nil

    struct AddTarget: Identifiable { var id = UUID(); var afterItemId: String?; var swapItemId: String? }

    private var workout: Workout? { store.workout(workoutId) }

    var body: some View {
        if let w = workout {
            let ps = panes(w.items)
            VStack(spacing: 0) {
                header(w, paneCount: ps.count)
                ScrollView(.vertical) {
                    // Not lazy: every pane is laid out, so jumping from Overview lands exactly on a pane.
                    VStack(spacing: 0) {
                        ForEach(Array(ps.enumerated()), id: \.offset) { idx, pane in
                            paneView(w, pane: pane, index: idx, total: ps.count)
                                .containerRelativeFrame(.vertical)
                                .id(idx)
                        }
                        if ps.isEmpty { emptyPane.containerRelativeFrame(.vertical).id(0) }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $current, anchor: .top)
                .scrollIndicators(.hidden)
                if let end = restEndsAt, store.settings.restTimer { restBar(end) }
            }
            .background(p.bg.ignoresSafeArea())
            .sheet(isPresented: $showOverview, onDismiss: {
                if let t = pendingAdd { pendingAdd = nil; adding = t }
            }) {
                OverviewSheet(workoutId: workoutId, current: $current, adding: $pendingAdd)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(p.card)
            }
            .sheet(item: $adding) { t in
                AddExerciseSheet { v, st in addVersion(v, style: st, target: t) }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .alert("Finish workout?", isPresented: $confirmFinish) {
                Button("Finish") { store.finishWorkout(workoutId) }
                Button("Keep going", role: .cancel) {}
            } message: {
                let undone = w.items.filter { !$0.isDone }.count
                Text(undone > 0 ? "\(undone) exercises have no sets logged. They will be dropped." : "Nice. This saves to history.")
            }
            .onPreferenceChange(SetLoggedKey.self) { stamp in
                if stamp > 0, store.settings.restTimer { restEndsAt = Date().addingTimeInterval(Double(store.settings.restSeconds)) }
            }
        } else {
            WorkoutStartView()
        }
    }

    private func header(_ w: Workout, paneCount: Int) -> some View {
        HStack(spacing: 10) {
            PillButton(title: "Overview") { showOverview = true }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let ms = ctx.date.timeIntervalSince1970 * 1000 - (w.startedAt ?? nowMs())
                Text("\(w.name) · \(min((current ?? 0) + 1, max(paneCount, 1))) of \(paneCount) · \(elapsedString(ms: ms))")
                    .font(.system(size: 13)).monospacedDigit().foregroundStyle(p.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            PillButton(title: "Done", style: .primary) { confirmFinish = true }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
    }

    @ViewBuilder
    private func paneView(_ w: Workout, pane: [WorkoutItem], index: Int, total: Int) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if pane.count > 1, let gid = pane.first?.groupId, let g = w.groups.first(where: { $0.id == gid }) {
                    HStack {
                        Chip(text: g.type.label, on: true, small: true)
                        Text("\(pane.count) exercises, rotate through them").font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                }
                ForEach(pane) { item in
                    ExerciseCardView(workoutId: workoutId, itemId: item.id, compact: pane.count > 1,
                                     onSwap: { adding = AddTarget(swapItemId: item.id) },
                                     onAddAfter: { adding = AddTarget(afterItemId: item.id) })
                }
                footer(index: index, total: total, panesOf: w)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func footer(index: Int, total: Int, panesOf w: Workout) -> some View {
        HStack {
            if index + 1 < total, let next = panes(w.items)[index + 1].first, let v = store.version(next.versionId) {
                Text("Swipe up for \(store.workoutName(v))").font(.system(size: 13)).foregroundStyle(p.muted)
            } else {
                Text("Last one. Tap Done when you finish.").font(.system(size: 13)).foregroundStyle(p.muted)
            }
            Spacer()
            Button { adding = AddTarget(afterItemId: panes(w.items)[index].last?.id) } label: {
                Label("Add exercise", systemImage: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent)
            }
        }
        .padding(.top, 4)
    }

    private var emptyPane: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Empty workout").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
            Text("Add an exercise to start logging.").font(.system(size: 14)).foregroundStyle(p.muted)
            PillButton(title: "Add exercise", style: .primary, icon: "plus") { adding = AddTarget() }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func restBar(_ end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let left = max(0, Int(end.timeIntervalSince(ctx.date).rounded()))
            HStack {
                Text("Rest").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.secondary)
                Spacer()
                Text(String(format: "%d:%02d", left / 60, left % 60)).font(.system(size: 20, weight: .bold)).monospacedDigit().foregroundStyle(left == 0 ? p.accent : p.text)
                Spacer()
                Button("Skip") { restEndsAt = nil }.font(.system(size: 14, weight: .semibold)).foregroundStyle(p.accent)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(p.elevated)
            .sensoryFeedback(.success, trigger: left == 0) { _, done in done }
        }
    }

    private func addVersion(_ v: Version, style: Style?, target: AddTarget) {
        guard var w = workout else { return }
        let item = newItem(for: v, style: style, unit: store.settings.unit, workouts: store.workouts)
        if let swapId = target.swapItemId, let i = w.items.firstIndex(where: { $0.id == swapId }) {
            var it = item; it.groupId = w.items[i].groupId
            w.items[i] = it
            store.put(w)
            return
        }
        if let afterId = target.afterItemId, let i = w.items.firstIndex(where: { $0.id == afterId }) {
            w.items.insert(item, at: i + 1)
        } else {
            w.items.append(item)
        }
        store.put(w)
        let ps = panes(w.items)
        if let idx = ps.firstIndex(where: { $0.contains { $0.id == item.id } }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation { current = idx } }
        }
    }
}

/// Bubbles "a set was just logged" up from a card so the workout can start a rest timer.
struct SetLoggedKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) { value = max(value, nextValue()) }
}

struct OverviewSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let workoutId: String
    @Binding var current: Int?
    @Binding var adding: WorkoutView.AddTarget?
    @State private var selecting = false
    @State private var selected: Set<String> = []

    var body: some View {
        if let w = store.workout(workoutId) {
            let ps = panes(w.items)
            NavigationStack {
                List {
                    ForEach(Array(w.items.enumerated()), id: \.element.id) { i, item in
                        row(w, item: item, paneIndex: ps.firstIndex { $0.contains { $0.id == item.id } } ?? 0)
                    }
                    .onMove { from, to in
                        var ww = w
                        ww.items.move(fromOffsets: from, toOffset: to)
                        store.put(ww)
                    }
                    .onDelete { idx in
                        var ww = w
                        ww.items.remove(atOffsets: idx)
                        ww.groups.removeAll { g in !ww.items.contains { $0.groupId == g.id } }
                        store.put(ww)
                    }
                }
                .cardList()
                .navigationTitle("Overview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if selecting {
                            Menu("Group") {
                                ForEach(GroupType.allCases, id: \.self) { t in
                                    Button(t.label) { group(w, as: t) }
                                }
                                Button("Ungroup", role: .destructive) { ungroup(w) }
                            }.disabled(selected.count < 1)
                        } else {
                            Button("Group…") { selecting = true }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack {
                            Button { adding = WorkoutView.AddTarget(); dismiss() } label: { Image(systemName: "plus") }
                            if selecting { Button("Cancel") { selecting = false; selected = [] } } else { EditButton() }
                        }
                    }
                }
            }
        }
    }

    private func row(_ w: Workout, item: WorkoutItem, paneIndex: Int) -> some View {
        let v = store.version(item.versionId)
        let g = item.groupId.flatMap { gid in w.groups.first { $0.id == gid } }
        return HStack(spacing: 12) {
            if selecting {
                RectCheck(on: selected.contains(item.id), size: 26)
            } else {
                RectCheck(on: item.isDone, size: 26)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(v.map { store.workoutName($0) } ?? "?").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                HStack(spacing: 6) {
                    if let g { Text(g.type.label).font(.system(size: 12, weight: .bold)).foregroundStyle(p.accent) }
                    if let v { Text(store.subtitle(v, styleId: item.styleId)).font(.system(size: 12)).foregroundStyle(p.secondary).lineLimit(1) }
                    Text(item.sets.filter { $0.isDone }.map { $0.kind.prefix + $0.formatted }.joined(separator: " · "))
                        .font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(1)
                }
            }
            Spacer()
            if item.skipped == true { Badge(text: "skipped") }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selecting {
                if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
            } else {
                current = paneIndex
                dismiss()
            }
        }
        .rowCard(p)
    }

    private func group(_ w: Workout, as type: GroupType) {
        var ww = w
        let g = ExerciseGroup(id: uid(), type: type)
        ww.groups.append(g)
        // Pull the selected items together, in their current order, at the first selected position.
        let chosen = ww.items.filter { selected.contains($0.id) }.map { var i = $0; i.groupId = g.id; return i }
        guard let firstIdx = ww.items.firstIndex(where: { selected.contains($0.id) }) else { return }
        ww.items.removeAll { selected.contains($0.id) }
        ww.items.insert(contentsOf: chosen, at: min(firstIdx, ww.items.count))
        ww.groups.removeAll { gg in !ww.items.contains { $0.groupId == gg.id } }
        store.put(ww)
        selecting = false; selected = []
    }

    private func ungroup(_ w: Workout) {
        var ww = w
        for i in ww.items.indices where selected.contains(ww.items[i].id) { ww.items[i].groupId = nil }
        ww.groups.removeAll { gg in !ww.items.contains { $0.groupId == gg.id } }
        store.put(ww)
        selecting = false; selected = []
    }
}
