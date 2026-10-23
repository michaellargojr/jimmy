import SwiftUI
import Charts

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.palette) private var p

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScreenTitle("Home") {
                        Text(Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.system(size: 14)).foregroundStyle(p.muted)
                    }
                    ForEach(store.settings.homeBlocks.filter { $0.on }) { b in
                        block(b.block).padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .screen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Workout.self) { w in WorkoutDetailView(workoutId: w.id) }
            .navigationDestination(for: Version.self) { v in ExerciseProgressView(versionId: v.id) }
        }
    }

    @ViewBuilder
    private func block(_ b: HomeBlock) -> some View {
        switch b {
        case .quote: QuoteBlock(text: store.settings.quote)
        case .upNext: UpNextBlock()
        case .week: WeekBlock()
        case .recent: RecentBlock()
        case .allRoutines: AllRoutinesBlock()
        case .watchExercise: WatchExerciseBlock()
        }
    }
}

struct QuoteBlock: View {
    @Environment(\.palette) private var p
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 20, weight: .heavy))
            .tracking(0.2)
            .lineSpacing(2)
            .foregroundStyle(p.text)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UpNextBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.palette) private var p

    var body: some View {
        if let active = store.activeWorkout {
            card(kicker: "In progress", title: active.name,
                 sub: "\(active.items.count) exercises · \(active.items.filter { $0.isDone }.count) done",
                 button: "Continue workout") { nav.tab = .workout }
        } else if let r = store.upNextRoutine {
            let last = routineLast(r, workouts: store.workouts)
            let kicker = last.map { "Up next · \(daysBetween($0.date, today())) days since" } ?? "Up next · first time"
            card(kicker: kicker, title: r.name, sub: subtitle(for: r, last: last), button: "Start workout") {
                store.startWorkout(from: r)
                nav.tab = .workout
            }
        } else {
            card(kicker: "Up next", title: "No routines yet", sub: "Make one in Plan, or start a quick workout.", button: "Quick workout") {
                store.startQuickWorkout()
                nav.tab = .workout
            }
        }
    }

    private func subtitle(for r: Routine, last: Workout?) -> String {
        let n = "\(r.items.count) exercises"
        guard let last else { return n }
        let template = Set(r.items.map { $0.versionId })
        let added = last.items.filter { !template.contains($0.versionId) }.compactMap { store.version($0.versionId)?.name }
        if let first = added.first { return "\(n) · last time you added \(first)" }
        return n
    }

    private func card(kicker: String, title: String, sub: String, button: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kicker.uppercased()).font(.system(size: 12, weight: .bold)).tracking(0.7).opacity(0.7)
                Text(title).font(.system(size: 26, weight: .heavy)).tracking(-0.5)
                Text(sub).font(.system(size: 14)).opacity(0.8)
                Text(button)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(p.accent)
                    .frame(height: 40).padding(.horizontal, 18)
                    .background(p.isDark ? p.bg : p.text, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .padding(.top, 10)
            }
            .foregroundStyle(p.onAccent)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.accent, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WeekBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p

    private var days: [String] {
        let cal = Calendar.current
        let now = Date()
        // Week starts on Monday.
        let weekday = cal.component(.weekday, from: now) // 1 = Sunday
        let offset = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now))!
        return (0..<7).map { dayString(cal.date(byAdding: .day, value: $0, to: monday)!) }
    }

    var body: some View {
        let done = Set(store.workouts.filter { $0.isFinished }.map { $0.date })
        let t = today()
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("This week")
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { d in
                    let on = done.contains(d)
                    Text(String(weekdayShort(d).prefix(2)).capitalized)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(on ? p.onAccent : d == t ? p.text : p.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(on ? p.accent : p.card, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(d == t && !on ? p.border : .clear, lineWidth: 2))
                }
            }
        }
    }
}

struct RecentBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Recent")
                Spacer()
                Button("All history") { nav.tab = .history }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(p.accent)
            }
            ForEach(store.finishedWorkouts.prefix(2)) { w in
                NavigationLink(value: w) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                            Text(recentLine(w)).font(.system(size: 13)).foregroundStyle(p.muted)
                        }
                        Spacer()
                        Chevron()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            if store.finishedWorkouts.isEmpty {
                Text("No workouts yet.").font(.system(size: 14)).foregroundStyle(p.muted)
            }
        }
    }

    private func recentLine(_ w: Workout) -> String {
        var parts = [relativeDays(w.date)]
        if let m = w.durationMinutes { parts.append("\(m) min") }
        let up = setsUp(in: w, workouts: store.workouts, versions: store.versions)
        if up > 0 { parts.append("\(up) sets up") }
        return parts.joined(separator: " · ")
    }
}

struct AllRoutinesBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.palette) private var p

    private var list: [Routine] {
        if let s = store.activeSplit { return s.routineIds.compactMap { store.routine($0) } }
        return store.routines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("All routines")
            ForEach(list) { r in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                        Text(routineLast(r, workouts: store.workouts).map { relativeDays($0.date) } ?? "Never").font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    Spacer()
                    Chip(text: "Start", on: true, small: true) {
                        if store.activeWorkout == nil { store.startWorkout(from: r) }
                        nav.tab = .workout
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            }
        }
    }
}

struct WatchExerciseBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Exercise to watch")
            if let id = store.settings.watchVersionId, let v = store.version(id) {
                NavigationLink(value: v) {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(v.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                                Spacer()
                                Chevron()
                            }
                            ProgressChart(points: progressPoints(versionId: v.id, workouts: store.workouts), height: 90)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Card {
                    Text("Pick an exercise in Settings › Home blocks.").font(.system(size: 14)).foregroundStyle(p.muted)
                }
            }
        }
    }
}
