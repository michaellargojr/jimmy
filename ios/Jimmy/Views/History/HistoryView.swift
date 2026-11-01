import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    /// 0 Calendar (first, opens by default), 1 Workouts, 2 Exercises.
    @State private var segment = 0
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScreenTitle("History") {
                    if segment == 0 {
                        CalendarModeSwitch()
                    } else {
                        Text(Date().formatted(.dateTime.month(.wide))).font(.system(size: 14)).foregroundStyle(p.muted)
                    }
                }
                HStack(spacing: 8) {
                    Chip(text: "Calendar", on: segment == 0) { segment = 0 }
                    Chip(text: "Workouts", on: segment == 1) { segment = 1 }
                    Chip(text: "Exercises", on: segment == 2) { segment = 2 }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
                switch segment {
                case 0: CalendarHistoryView { w in path.append(w) }
                case 1: WorkoutsHistoryList()
                default: ExercisesHistoryList()
                }
            }
            .screen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Workout.self) { w in WorkoutDetailView(workoutId: w.id) }
            .navigationDestination(for: Version.self) { v in ExerciseProgressView(versionId: v.id) }
            .navigationDestination(for: BaseHistoryRoute.self) { r in BaseHistoryView(exerciseId: r.exerciseId) }
        }
    }
}

struct WorkoutsHistoryList: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p

    private struct HistorySection: Identifiable { var id: String { title }; var title: String; var list: [Workout] }

    private var sections: [HistorySection] {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let monday = cal.date(byAdding: .day, value: -((weekday + 5) % 7), to: cal.startOfDay(for: now))!
        let lastMonday = cal.date(byAdding: .day, value: -7, to: monday)!
        var out: [HistorySection] = []
        var byKey: [String: [Workout]] = [:]
        var order: [String] = []
        for w in store.finishedWorkouts {
            let d = dayDate(w.date)
            let key: String
            if d >= monday { key = "This week" }
            else if d >= lastMonday { key = "Last week" }
            else { key = d.formatted(.dateTime.month(.wide).year()) }
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(w)
        }
        for k in order { out.append(HistorySection(title: k, list: byKey[k]!)) }
        return out
    }

    var body: some View {
        List {
            ForEach(sections) { sec in
                Section {
                    ForEach(sec.list) { w in
                        NavigationLink(value: w) { WorkoutRow(workout: w) }
                            .rowCard(p)
                            .swipeActions { Button(role: .destructive) { store.deleteWorkout(w.id) } label: { Label("Delete", systemImage: "trash") } }
                    }
                } header: {
                    SectionLabel(sec.title).padding(.leading, 16)
                }
            }
            if store.finishedWorkouts.isEmpty {
                Text("No workouts yet.").font(.system(size: 14)).foregroundStyle(p.muted).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
        }
        .cardList()
    }
}

struct WorkoutRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let workout: Workout

    var body: some View {
        let up = setsUp(in: workout, workouts: store.workouts, versions: store.versions)
        let down = workout.items.filter { i in store.version(i.versionId).map { verdict(i.sets, i.doneRange($0)) == .down } ?? false }.count
        let sets = workout.items.flatMap { $0.sets }.filter { $0.isDone }.count
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(weekdayShort(workout.date)).font(.system(size: 11, weight: .bold)).foregroundStyle(p.muted)
                Text(dayNumber(workout.date)).font(.system(size: 18, weight: .heavy)).foregroundStyle(p.text)
            }
            .frame(width: 52, height: 48)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                Text([workout.durationMinutes.map { "\($0) min" }, "\(workout.items.count) exercises", "\(sets) sets"].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13)).foregroundStyle(p.muted)
            }
            Spacer()
            if up > 0 { Badge(text: "\(up) up", kind: .up) }
            else if down > 0 { Badge(text: "\(down) down", kind: .down) }
            else { Badge(text: "held") }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

/// History > Exercises. Sort by muscle group (a tree: muscle group > exercise > variation) or by
/// most recent (every variation, newest first), from a "Sort by" line under the search. The sort is remembered.
struct ExercisesHistoryList: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var query = ""
    @AppStorage("historyExerciseSort") private var sortRaw = HistorySort.muscle.rawValue

    private var sort: HistorySort { HistorySort(rawValue: sortRaw) ?? .muscle }
    private var trimmed: String { query.trimmingCharacters(in: .whitespaces).lowercased() }

    private func matches(_ v: Version) -> Bool { trimmed.isEmpty || store.fullName(v).lowercased().contains(trimmed) }

    var body: some View {
        let list = variationHistories(versions: store.versions, workouts: store.workouts)
        VStack(spacing: 0) {
            SearchField(placeholder: "Search exercises", text: $query)
            sortLine
            List {
                switch sort {
                case .muscle: muscleRows(list)
                case .recent: recentRows(list)
                }
            }
            .cardList()
        }
        .background(p.bg.ignoresSafeArea())
    }

    /// "Sort by Muscle group" under the search. The sort that is on reads in the accent; tap it for the two choices.
    private var sortLine: some View {
        HStack(spacing: 8) {
            Text("Sort by").font(.system(size: 14)).foregroundStyle(p.muted)
            Menu {
                Picker("Sort", selection: Binding(get: { sort }, set: { sortRaw = $0.rawValue })) {
                    ForEach(HistorySort.allCases) { s in Text(s.label).tag(s) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(sort.label).font(.system(size: 14, weight: .bold))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(p.accent)
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.bottom, 2)
    }

    // MARK: Muscle group

    /// Only groups and exercises with history. An exercise with one variation opens its history
    /// straight away; with more, a page to pick the variation.
    @ViewBuilder private func muscleRows(_ list: [VariationHistory]) -> some View {
        let tree = historyByMuscle(list, exercises: store.exercises) { e, vs in
            trimmed.isEmpty || searchRank(e, trimmed) != nil || vs.contains { matches($0.version) }
        }
        ForEach(tree) { sec in
            Section {
                ForEach(sec.bases) { b in
                    Group {
                        if b.variations.count == 1 {
                            NavigationLink(value: b.variations[0].version) { baseRow(b) }
                        } else {
                            NavigationLink(value: BaseHistoryRoute(exerciseId: b.exercise.id)) { baseRow(b) }
                        }
                    }
                    .rowCard(p)
                }
            } header: {
                SectionLabel(sec.muscle.label).padding(.leading, 16)
            }
        }
        if tree.isEmpty { emptyText }
    }

    /// The name, when it was last done, and how many variations have history (accent, like Plan).
    private func baseRow(_ b: BaseHistory) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(b.exercise.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                Text("Last \(monthDay(b.last))").font(.system(size: 12.5)).foregroundStyle(p.muted)
            }
            Spacer()
            Text("\(b.variations.count)").font(.system(size: 14, weight: .heavy)).foregroundStyle(p.accent)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: Most recent

    @ViewBuilder private func recentRows(_ list: [VariationHistory]) -> some View {
        let shown = list.filter { matches($0.version) }
        ForEach(shown) { h in
            NavigationLink(value: h.version) { recentRow(h) }.rowCard(p)
        }
        if shown.isEmpty { emptyText }
    }

    private func recentRow(_ h: VariationHistory) -> some View {
        let v = h.version
        return HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.baseName(v)).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                VariationChips(tags: store.variationChips(v), size: .small, note: "\(monthDay(h.last)) - \(h.sessionsLabel)")
            }
            Spacer()
            if let t = lastSession(versionId: v.id, workouts: store.finishedWorkouts, versions: store.versions).flatMap({ topSet($0.item) }) {
                Text(t.formatted).font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(p.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var emptyText: some View {
        Text(query.isEmpty ? "Log a workout and your exercises show up here." : "Nothing matches \"\(query)\".")
            .font(.system(size: 14)).foregroundStyle(p.muted).listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
}

struct WorkoutDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let workoutId: String
    @State private var confirmDelete = false

    var body: some View {
        if let w = store.workout(workoutId) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name).font(.system(size: 28, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
                            Text([dayDate(w.date).formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), w.durationMinutes.map { "\($0) min" }, w.gymId.flatMap { id in store.gyms.first { $0.id == id }?.name }].compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 13)).foregroundStyle(p.muted)
                        }
                        Spacer()
                    }
                    if let n = w.notes, !n.isEmpty { Text(n).font(.system(size: 14)).foregroundStyle(p.secondary) }
                    ForEach(Array(panes(w.items).enumerated()), id: \.offset) { _, pane in
                        Card(padding: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                if pane.count > 1, pane.first?.groupId != nil {
                                    Text(GroupType.forCount(pane.count).label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.accent)
                                }
                                ForEach(pane) { item in
                                    if let v = store.version(item.versionId) {
                                        NavigationLink { ExerciseProgressView(versionId: v.id) } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 5) {
                                                        Text(store.baseName(v)).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                                                        VariationChips(tags: store.variationChips(v), size: .small, note: store.style(item.styleId)?.label)
                                                    }
                                                    Spacer()
                                                    switch verdict(item.sets, item.doneRange(v)) {
                                                    case .up: Badge(text: "up", kind: .up)
                                                    case .down: Badge(text: "down", kind: .down)
                                                    case .none: Chevron()
                                                    }
                                                }
                                                Text(item.sets.filter { $0.hasData }.map { $0.kind.prefix + $0.formatted }.joined(separator: " · "))
                                                    .font(.system(size: 14)).monospacedDigit().foregroundStyle(p.secondary)
                                                if let n = item.note, !n.isEmpty { Text(n).font(.system(size: 13)).foregroundStyle(p.muted) }
                                                let notes = item.sets.compactMap { $0.note }.filter { !$0.isEmpty }
                                                if !notes.isEmpty { Text(notes.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(p.muted) }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    PillButton(title: "Delete workout", style: .danger, full: true) { confirmDelete = true }.padding(.top, 8)
                }
                .padding(16)
            }
            .screen()
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete this workout?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { store.deleteWorkout(workoutId); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
