import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var segment = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenTitle("History") {
                    Text(Date().formatted(.dateTime.month(.wide))).font(.system(size: 14)).foregroundStyle(p.muted)
                }
                HStack(spacing: 8) {
                    Chip(text: "Workouts", on: segment == 0) { segment = 0 }
                    Chip(text: "Exercises", on: segment == 1) { segment = 1 }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
                if segment == 0 { WorkoutsHistoryList() } else { ExercisesHistoryList() }
            }
            .screen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Workout.self) { w in WorkoutDetailView(workoutId: w.id) }
            .navigationDestination(for: Version.self) { v in ExerciseProgressView(versionId: v.id) }
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
        let down = workout.items.filter { i in store.version(i.versionId).map { verdict(i.sets, $0) == .down } ?? false }.count
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

struct ExercisesHistoryList: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var query = ""

    private struct Entry: Identifiable { var id: String { version.id }; var version: Version; var count: Int; var last: String? }

    private var list: [Entry] {
        let q = query.lowercased()
        return store.versions.compactMap { v -> Entry? in
            if !q.isEmpty && !v.name.lowercased().contains(q) { return nil }
            let sessions = store.finishedWorkouts.filter { w in w.items.contains { $0.versionId == v.id && $0.sets.contains { $0.hasData } } }
            guard !sessions.isEmpty else { return nil }
            return Entry(version: v, count: sessions.count, last: sessions.first?.date)
        }
        .sorted { ($0.last ?? "") > ($1.last ?? "") }
    }

    var body: some View {
        List {
            TextField("Search", text: $query)
                .padding(12)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .foregroundStyle(p.text)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
            ForEach(list) { e in
                let v = e.version
                NavigationLink(value: v) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                            Text("\(e.count) sessions · last \(e.last.map { monthDay($0) } ?? "–")").font(.system(size: 12)).foregroundStyle(p.muted)
                        }
                        Spacer()
                        if let t = lastSession(versionId: v.id, workouts: store.workouts, versions: store.versions).flatMap({ topSet($0.item) }) {
                            Text(t.formatted).font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(p.secondary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .rowCard(p)
            }
        }
        .cardList()
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
                                if pane.count > 1, let gid = pane.first?.groupId, let g = w.groups.first(where: { $0.id == gid }) {
                                    Text(g.type.label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.accent)
                                }
                                ForEach(pane) { item in
                                    if let v = store.version(item.versionId) {
                                        NavigationLink { ExerciseProgressView(versionId: v.id) } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(v.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                                                    Spacer()
                                                    switch verdict(item.sets, v) {
                                                    case .up: Badge(text: "up", kind: .up)
                                                    case .down: Badge(text: "down", kind: .down)
                                                    case .none: Chevron()
                                                    }
                                                }
                                                Text(item.sets.filter { $0.hasData }.map { ($0.kind == .warmup ? "W " : "") + $0.formatted }.joined(separator: " · "))
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
