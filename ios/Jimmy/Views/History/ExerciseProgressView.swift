import SwiftUI
import Charts

struct ProgressPoint: Identifiable {
    var id: String { date }
    var date: String
    var weight: Double
    var reps: Int
    var verdict: Verdict
    var sets: [SetEntry]
    /// The rep range it was done at; nil for sessions from before rep range templates.
    var range: RepRange? = nil
}

/// Top-set weight per finished session, oldest first.
func progressPoints(versionId: String, workouts: [Workout], version: Version? = nil) -> [ProgressPoint] {
    var out: [ProgressPoint] = []
    for w in sortedNewestFirst(workouts).reversed() where w.isFinished {
        guard let item = w.items.first(where: { $0.versionId == versionId }), let t = topSet(item) else { continue }
        let v = version.map { verdict(item.sets, item.doneRange($0)) } ?? Verdict.none
        out.append(ProgressPoint(date: w.date, weight: t.weight!, reps: t.reps!, verdict: v, sets: item.sets.filter { $0.kind != .warmup && $0.hasData }, range: item.savedRepRange))
    }
    return out
}

struct ProgressChart: View {
    @Environment(\.palette) private var p
    let points: [ProgressPoint]
    var height: CGFloat = 150

    var body: some View {
        if points.count < 2 {
            Text(points.isEmpty ? "No sessions yet." : "One session so far. The line appears after the second.")
                .font(.system(size: 13)).foregroundStyle(p.muted).frame(height: height)
        } else {
            Chart(points) { pt in
                LineMark(x: .value("Date", dayDate(pt.date)), y: .value("Weight", pt.weight))
                    .foregroundStyle(p.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", dayDate(pt.date)), y: .value("Weight", pt.weight))
                    .symbol(.square)
                    .symbolSize(pt.date == points.last?.date ? 90 : 40)
                    .foregroundStyle(p.accent)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(p.muted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(p.line)
                    AxisValueLabel().foregroundStyle(p.muted)
                }
            }
            .frame(height: height)
        }
    }
}

/// A variation's full history: its progression, every session, then the other variations of
/// the same exercise. Opened from History, Home, the library, and "See full history" on a Workout card.
struct ExerciseProgressView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let versionId: String
    @State private var range: Int = 0 // days; 0 = all

    var body: some View {
        if let v = store.version(versionId) {
            let all = progressPoints(versionId: v.id, workouts: store.workouts, version: v)
            let cutoff = range == 0 ? "" : dayString(Calendar.current.date(byAdding: .day, value: -range, to: Date())!)
            let pts = all.filter { $0.date >= cutoff }
            let unit = pts.last?.sets.first?.unit.label ?? store.settings.unit.label
            let best = all.max { a, b in a.weight != b.weight ? a.weight < b.weight : a.reps < b.reps }
            let others = otherVariations(v)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.workoutName(v)).font(.system(size: 26, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
                        Text(store.armsText(v)).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
                    }
                    HStack(spacing: 8) {
                        Chip(text: "1 month", on: range == 30, small: true) { range = 30 }
                        Chip(text: "3 months", on: range == 90, small: true) { range = 90 }
                        Chip(text: "All", on: range == 0, small: true) { range = 0 }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                SectionLabel("Top set")
                                Spacer()
                                if let last = pts.last {
                                    Text(fmtWeight(last.weight)).font(.system(size: 28, weight: .heavy)).monospacedDigit().foregroundStyle(p.text)
                                    + Text(" \(unit)").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.muted)
                                }
                            }
                            ProgressChart(points: pts)
                        }
                    }
                    HStack(spacing: 10) {
                        stat("Best set", best.map { "\(fmtWeight($0.weight)) × \($0.reps)" } ?? "–")
                        stat(pts.first.map { "Since \(monthDay($0.date))" } ?? "Change", delta(pts), accent: true)
                        stat("Sessions", "\(pts.count)")
                    }
                    if !all.isEmpty {
                        SectionLabel("Every session").padding(.top, 6)
                        VStack(spacing: 0) {
                            ForEach(Array(all.reversed().enumerated()), id: \.offset) { i, pt in
                                if i > 0 { Divider1() }
                                sessionRow(pt)
                            }
                        }
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    if !others.isEmpty {
                        SectionLabel("Other variations").padding(.top, 6)
                        ForEach(others, id: \.version.id) { o in
                            NavigationLink { ExerciseProgressView(versionId: o.version.id) } label: { otherCard(o) }
                                .buttonStyle(.plain)
                        }
                    }
                    if store.settings.watchVersionId != v.id {
                        PillButton(title: "Watch on Home", icon: "eye", full: true) {
                            store.update { s in
                                s.watchVersionId = v.id
                                if let i = s.homeBlocks.firstIndex(where: { $0.block == .watchExercise }) { s.homeBlocks[i].on = true }
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(16)
            }
            .screen()
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// One session: the date with the rep range in small print, then each working and drop set.
    /// A ✅ marks a "Time to ascend" day.
    private func sessionRow(_ pt: ProgressPoint) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthDay(pt.date)).font(.system(size: 15)).foregroundStyle(p.muted)
                if let r = pt.range { Text("\(r.text) reps").font(.system(size: 12)).monospacedDigit().foregroundStyle(p.muted) }
            }
            .frame(width: 64, alignment: .leading)
            FlowRow(spacing: 14, lineSpacing: 4) {
                ForEach(pt.sets) { s in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let side = s.side { Text(side.rawValue).font(.system(size: 12, weight: .bold)).foregroundStyle(p.muted) }
                        if s.kind == .drop { Text("D").font(.system(size: 12, weight: .bold)).foregroundStyle(p.muted) }
                        Text(s.valueText).font(.system(size: 18, weight: .bold)).monospacedDigit().foregroundStyle(p.text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if pt.verdict == .up { Text("✅").font(.system(size: 16)) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private struct Other { var version: Version; var points: [ProgressPoint] }

    /// The other variations of this exercise that have finished sessions, most recent first.
    private func otherVariations(_ v: Version) -> [Other] {
        store.versions
            .filter { $0.exerciseId == v.exerciseId && $0.id != v.id }
            .map { Other(version: $0, points: progressPoints(versionId: $0.id, workouts: store.workouts, version: $0)) }
            .filter { !$0.points.isEmpty }
            .sorted { ($0.points.last?.date ?? "") > ($1.points.last?.date ?? "") }
    }

    private func otherCard(_ o: Other) -> some View {
        let last = o.points.last
        let lastText = last.map { pt in ([monthDay(pt.date)] + [pt.sets.prefix(3).map { $0.valueText }.joined(separator: ", ")]).joined(separator: " - ") } ?? ""
        let n = o.points.count
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.workoutName(o.version)).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text).multilineTextAlignment(.leading)
                Text("\(store.armsText(o.version)) - \(n) \(n == 1 ? "session" : "sessions")").font(.system(size: 13)).foregroundStyle(p.muted)
                Text(lastText).font(.system(size: 16, weight: .bold)).monospacedDigit().foregroundStyle(p.secondary).padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if o.points.count > 1 {
                Chart(o.points) { pt in
                    LineMark(x: .value("Date", dayDate(pt.date)), y: .value("Weight", pt.weight))
                        .foregroundStyle(p.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("Date", dayDate(pt.date)), y: .value("Weight", pt.weight))
                        .symbol(.square).symbolSize(24).foregroundStyle(p.secondary)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis(.hidden).chartYAxis(.hidden)
                .frame(width: 90, height: 44)
            }
            Chevron()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func stat(_ label: String, _ value: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.muted).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 20, weight: .heavy)).monospacedDigit().foregroundStyle(accent ? p.accent : p.text).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func delta(_ pts: [ProgressPoint]) -> String {
        guard let f = pts.first, let l = pts.last, pts.count > 1 else { return "–" }
        let d = l.weight - f.weight
        let unit = l.sets.first?.unit.label ?? ""
        return (d > 0 ? "+" : "") + fmtWeight(d) + " " + unit
    }
}
