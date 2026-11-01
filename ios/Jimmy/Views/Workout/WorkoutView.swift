import SwiftUI

/// The live workout: one full-screen pane per exercise (or per group), paged vertically.
struct WorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let workoutId: String

    @State private var current: Int? = 0
    @State private var showOverview = false
    @State private var showSettings = false
    @State private var adding: AddTarget? = nil
    /// Set by the Overview sheet; presented only after Overview has finished closing,
    /// because two sheets changing at once leaves the new one unable to take the keyboard.
    @State private var pendingAdd: AddTarget? = nil
    /// Done asks Finish, Discard or Keep going, then Finish and Discard each ask again,
    /// so a tap from a pocket can never end the workout.
    @State private var askEnd = false
    @State private var sureFinish = false
    @State private var sureDiscard = false
    @State private var restEndsAt: Date? = nil
    /// Each pane's height and the screen's, measured, so a swipe knows where every exercise starts.
    @State private var paneHeights: [Int: CGFloat] = [:]
    @State private var pageHeight: CGFloat = 0

    struct AddTarget: Identifiable { var id = UUID(); var afterItemId: String?; var swapItemId: String? }

    private var workout: Workout? { store.workout(workoutId) }

    var body: some View {
        if let w = workout {
            let ps = panes(w.items)
            VStack(spacing: 0) {
                header(w, finished: ps.map { paneFinished($0, versions: store.versions) })
                // One scroll for the whole workout. Each pane used to be a scroll of its own inside
                // this one, and the two fought over every up and down swipe. See PaneSnap.
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(Array(ps.enumerated()), id: \.offset) { idx, pane in
                            ZStack(alignment: .top) {
                                // A pane is never shorter than the screen; a longer one simply runs on.
                                Color.clear
                                    .containerRelativeFrame(.vertical)
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
                                paneView(w, pane: pane, index: idx)
                            }
                            // Exactly the screen's width. Without it the widest line of Last time
                            // could stretch the whole page past the edge of a smaller phone.
                            .containerRelativeFrame(.horizontal)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { paneHeights[idx] = $0 }
                            // Room under each pane, so the next exercise doesn't show through the tab bar.
                            .padding(.bottom, PaneSnap.gap)
                            .id(idx)
                        }
                        if ps.isEmpty { emptyPane.containerRelativeFrame([.horizontal, .vertical]).id(0) }
                    }
                    .scrollTargetLayout()
                }
                // One exercise per swipe, with a light touch, landing on its title.
                .scrollTargetBehavior(PaneSnapBehavior(heights: ps.indices.map { paneHeights[$0] ?? 0 }, page: pageHeight))
                .scrollPosition(id: $current, anchor: .top)
                .scrollIndicators(.hidden)
                if let end = restEndsAt, store.settings.restTimer { restBar(end) }
            }
            // The whole page, header included, is held to the screen's width too, whatever the
            // tab bar around it offers, so nothing can lay it out wider than the phone.
            .containerRelativeFrame(.horizontal)
            .background(p.bg.ignoresSafeArea())
            .sheet(isPresented: $showOverview, onDismiss: {
                if let t = pendingAdd { pendingAdd = nil; adding = t }
            }) {
                // Full height, so every exercise shows at once.
                OverviewSheet(workoutId: workoutId, current: $current, adding: $pendingAdd)
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .sheet(isPresented: $showSettings) {
                WorkoutRepRangesSheet(workoutId: workoutId)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(p.card)
            }
            .sheet(item: $adding) { t in
                AddExerciseSheet { v, st in addVersion(v, style: st, target: t) }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .alert("End workout?", isPresented: $askEnd) {
                Button("Finish") { sureFinish = true }
                Button("Discard", role: .destructive) { sureDiscard = true }
                Button("Keep going", role: .cancel) {}
            }
            .alert("Are you sure?", isPresented: $sureFinish) {
                Button("Finish") { store.finishWorkout(workoutId) }
                Button("Keep going", role: .cancel) {}
            } message: {
                // Counted the same way Finish drops them, so a logged warm-up keeps its exercise.
                let n = store.unlogged(w).count
                Text(n == 0 ? "This saves to history." : n == 1 ? "1 exercise has no sets logged. It will be dropped." : "\(n) exercises have no sets logged. They will be dropped.")
            }
            .alert("Are you sure?", isPresented: $sureDiscard) {
                Button("Discard", role: .destructive) { store.deleteWorkout(workoutId) }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("This workout won't be saved.")
            }
            .onPreferenceChange(SetLoggedKey.self) { stamp in
                if stamp > 0, store.settings.restTimer { restEndsAt = Date().addingTimeInterval(Double(store.settings.restSeconds)) }
            }
        } else {
            WorkoutStartView()
        }
    }

    /// One row that stays put: Start, then Done, alone on the left, where a stray thumb is least
    /// likely to land, the time big in the middle to keep the pace up, then Overview and the gear.
    /// Under it a block per exercise fills in once that exercise is done; tap one to go there.
    private func header(_ w: Workout, finished: [Bool]) -> some View {
        VStack(spacing: 1) {
            ZStack {
                HStack(spacing: 8) {
                    // Picking a workout doesn't start the clock; Start does, and then Done takes its place.
                    if w.startedAt == nil {
                        PillButton(title: "Start", style: .primary) { store.startClock(workoutId) }
                    } else {
                        PillButton(title: "Done", style: .primary) { askEnd = true }
                    }
                    Spacer()
                    iconButton("checklist", label: "Overview") { showOverview = true }
                    iconButton("gearshape", label: "Workout settings") { showSettings = true }
                }
                if let started = w.startedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        clock(elapsedString(ms: ctx.date.timeIntervalSince1970 * 1000 - started), running: true)
                    }
                } else {
                    clock("0:00", running: false)
                }
            }
            if !finished.isEmpty { progressStrip(finished) }
        }
        // The strip's taller tap row makes its own room underneath.
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, finished.isEmpty ? 8 : 0)
    }

    /// The time, big. Grey at 0:00 until Start.
    private func clock(_ text: String, running: Bool) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .heavy)).tracking(-0.5).monospacedDigit().foregroundStyle(running ? p.text : p.muted)
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: 140)
    }

    /// One block per exercise (a superset is one), filled when all its sets are checked. The one
    /// on screen is white. Tapping a block jumps straight to that exercise, for when a swipe won't do.
    private func progressStrip(_ finished: [Bool]) -> some View {
        let here = min(max(current ?? 0, 0), finished.count - 1)
        return HStack(spacing: 4) {
            ForEach(finished.indices, id: \.self) { i in
                Button { withAnimation(.snappy) { current = i } } label: {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(i == here ? p.text : finished[i] ? p.accent : p.elevated)
                        .frame(height: 10)
                        // The block is thin; the tap reaches well above and below it.
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exercise \(i + 1) of \(finished.count)\(finished[i] ? ", done" : "")")
                .accessibilityAddTraits(i == here ? .isSelected : [])
            }
        }
        .animation(.snappy, value: finished)
        .animation(.snappy, value: here)
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                .frame(width: 44, height: 44)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func paneView(_ w: Workout, pane: [WorkoutItem], index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // The workout's name lives at the top of the first page and scrolls away with it.
            if index == 0 {
                Text(w.name).font(.system(size: 30, weight: .heavy)).tracking(-0.5).foregroundStyle(p.accent)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .padding(.bottom, 4)
            }
            if pane.count > 1, pane.first?.groupId != nil {
                HStack {
                    Chip(text: GroupType.forCount(pane.count).label, on: true, small: true)
                    Text("\(pane.count) exercises, rotate through them").font(.system(size: 13)).foregroundStyle(p.muted)
                }
            }
            ForEach(pane) { item in
                ExerciseCardView(workoutId: workoutId, itemId: item.id, compact: pane.count > 1,
                                 onSwap: { adding = AddTarget(swapItemId: item.id) },
                                 onAddAfter: { adding = AddTarget(afterItemId: item.id) })
            }
            footer(index: index, panesOf: w)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    /// Only for the odd extra exercise, so it stays quiet: plain text, no accent.
    private func footer(index: Int, panesOf w: Workout) -> some View {
        HStack {
            Spacer()
            Button { adding = AddTarget(afterItemId: panes(w.items)[index].last?.id) } label: {
                Label("Add exercise", systemImage: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(p.text)
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

/// Where a swipe on the Workout page lands, worked out by PaneSnap from the measured panes.
struct PaneSnapBehavior: ScrollTargetBehavior {
    var heights: [CGFloat]
    var page: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let page = self.page > 0 ? self.page : context.containerSize.height
        target.rect.origin.y = PaneSnap.rest(start: context.originalTarget.rect.minY, coast: target.rect.minY,
                                             heights: heights, page: page, gap: PaneSnap.gap)
    }
}

/// Bubbles "a set was just logged" up from a card so the workout can start a rest timer.
struct SetLoggedKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) { value = max(value, nextValue()) }
}

/// Always ready to edit: tick boxes to group or ungroup, hold a row and drag to reorder, hold for
/// Swap or Delete, swipe left to delete. Tapping a name jumps to that exercise; Add sits under the last one.
struct OverviewSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let workoutId: String
    @Binding var current: Int?
    @Binding var adding: WorkoutView.AddTarget?
    /// Starts empty every time Overview opens, so nothing half-grouped is left over.
    @State private var selected: Set<String> = []
    @State private var deleting: WorkoutItem? = nil

    var body: some View {
        if let w = store.workout(workoutId) {
            let ps = panes(w.items)
            NavigationStack {
                List {
                    ForEach(Array(w.items.enumerated()), id: \.element.id) { i, item in
                        row(w, index: i, item: item, paneIndex: ps.firstIndex { $0.contains { $0.id == item.id } } ?? 0)
                    }
                    .onMove { from, to in store.put(moveItem(w, from: from, to: to)) }
                    // Under the last exercise, never floating over the list.
                    Button { adding = WorkoutView.AddTarget(); dismiss() } label: {
                        Label("Add exercise", systemImage: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(p.text)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .padding(.leading, 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
                .cardList()
                .navigationTitle("Overview")
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) { bottomBar(w) }
                .alert("Are you sure?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { item in
                    Button("Delete", role: .destructive) { remove(w, item) }
                    Button("Keep", role: .cancel) {}
                } message: { _ in
                    Text("Its logged sets will be lost.")
                }
            }
        }
    }

    /// Ticking loose exercises offers to group them; ticking a grouped one offers to ungroup.
    /// The bar shows only then, docked under the list.
    @ViewBuilder
    private func bottomBar(_ w: Workout) -> some View {
        let ticked = w.items.filter { selected.contains($0.id) }
        if ticked.contains(where: { $0.groupId != nil }) {
            actionButton("Ungroup") { store.put(ungroup(w, ids: selected)); selected = [] }
        } else if ticked.count >= 2 {
            actionButton("Make a \(GroupType.forCount(ticked.count).rawValue)") { store.put(makeGroup(w, ids: selected)); selected = [] }
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation { action() } } label: {
            Text(title).font(.system(size: 18, weight: .heavy)).foregroundStyle(p.onAccent)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(p.accent, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(p.bg)
    }

    private func row(_ w: Workout, index i: Int, item: WorkoutItem, paneIndex: Int) -> some View {
        let v = store.version(item.versionId)
        let gid = item.groupId
        let first = gid == nil || i == 0 || w.items[i - 1].groupId != gid
        let last = gid == nil || i == w.items.count - 1 || w.items[i + 1].groupId != gid
        let sets = item.sets.filter { $0.isDone }.map { $0.kind.prefix + $0.formatted }.joined(separator: " - ")
        return HStack(spacing: 14) {
            // Its own button, so a tick never jumps away or closes Overview.
            Button {
                if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
            } label: {
                RectCheck(on: selected.contains(item.id), size: 26).frame(width: 40, height: 44).contentShape(Rectangle())
            }
            Button { current = paneIndex; dismiss() } label: {
                VStack(alignment: .leading, spacing: 2) {
                    if let gid, first {
                        Text(GroupType.forCount(w.items.filter { $0.groupId == gid }.count).label.uppercased())
                            .font(.system(size: 12, weight: .heavy)).tracking(0.6).foregroundStyle(p.accent)
                            .padding(.bottom, 2)
                    }
                    HStack(spacing: 7) {
                        Text(v.map { store.workoutName($0) } ?? "?").font(.system(size: 17, weight: .bold)).foregroundStyle(p.text).lineLimit(1)
                        if let n = v.flatMap({ store.nickname($0) }) { NicknameTag(text: n, size: .small) }
                        if item.isDone && item.skipped != true {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(p.accent)
                        }
                    }
                    if let v {
                        VariationChips(tags: store.variationTags(v), size: .small, note: store.style(item.styleId).map { dashed($0.label) })
                            .padding(.vertical, 2)
                    }
                    if !sets.isEmpty { Text(sets).font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(1) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            if item.skipped == true { Badge(text: "skipped") }
            Image(systemName: "line.3.horizontal").font(.system(size: 17, weight: .semibold)).foregroundStyle(p.muted)
        }
        .buttonStyle(.plain)
        .padding(.leading, 6).padding(.trailing, 16).padding(.vertical, 8)
        .contextMenu {
            Button { adding = WorkoutView.AddTarget(swapItemId: item.id); dismiss() } label: { Label("Swap for another", systemImage: "arrow.left.arrow.right") }
            Button(role: .destructive) { askRemove(w, item) } label: { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { askRemove(w, item) } label: { Label("Delete", systemImage: "trash") }.tint(p.danger)
        }
        .overviewCard(p, grouped: gid != nil, first: first, last: last)
    }

    /// Only an exercise with something logged asks first.
    private func askRemove(_ w: Workout, _ item: WorkoutItem) {
        if item.sets.contains(where: { $0.hasData }) { deleting = item } else { remove(w, item) }
    }

    private func remove(_ w: Workout, _ item: WorkoutItem) {
        var ww = store.workout(w.id) ?? w
        ww.items.removeAll { $0.id == item.id }
        selected.remove(item.id)
        withAnimation { store.put(tidyGroups(ww)) }
    }
}

private extension View {
    /// A group's members share one card with an accent edge; loose exercises get a card each.
    func overviewCard(_ p: Palette, grouped: Bool, first: Bool, last: Bool) -> some View {
        let r = Radius.row
        let shape = UnevenRoundedRectangle(topLeadingRadius: first ? r : 0, bottomLeadingRadius: last ? r : 0,
                                           bottomTrailingRadius: last ? r : 0, topTrailingRadius: first ? r : 0, style: .continuous)
        return self.listRowBackground(
            shape.fill(p.card)
                .overlay(alignment: .leading) { if grouped { Rectangle().fill(p.accent).frame(width: 3) } }
                .clipShape(shape)
                .padding(.horizontal, 16).padding(.top, first ? 5 : 0).padding(.bottom, last ? 5 : 0)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: first ? 5 : 0, leading: 16, bottom: last ? 5 : 0, trailing: 16))
    }
}
