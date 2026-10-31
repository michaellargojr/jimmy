import SwiftUI
import Charts

struct ProgressPoint: Identifiable {
    var id: String { date }
    var date: String
    var weight: Double
    var reps: Int
    var verdict: Verdict
    var sets: [SetEntry]
}

/// Top-set weight per finished session, oldest first.
func progressPoints(versionId: String, workouts: [Workout], version: Version? = nil) -> [ProgressPoint] {
    var out: [ProgressPoint] = []
    for w in sortedNewestFirst(workouts).reversed() where w.isFinished {
        guard let item = w.items.first(where: { $0.versionId == versionId }), let t = topSet(item) else { continue }
        let v = version.map { verdict(item.sets, $0) } ?? Verdict.none
        out.append(ProgressPoint(date: w.date, weight: t.weight!, reps: t.reps!, verdict: v, sets: item.sets.filter { $0.kind == .working && $0.hasData }))
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

struct ExerciseProgressView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let versionId: String
    @State private var range: Int = 90 // days; 0 = all

    var body: some View {
        if let v = store.version(versionId) {
            let all = progressPoints(versionId: v.id, workouts: store.workouts, version: v)
            let cutoff = range == 0 ? "" : dayString(Calendar.current.date(byAdding: .day, value: -range, to: Date())!)
            let pts = all.filter { $0.date >= cutoff }
            let unit = pts.last?.sets.first?.unit.label ?? store.settings.unit.label
            let best = all.max { a, b in a.weight != b.weight ? a.weight < b.weight : a.reps < b.reps }
            let routineName = store.routines.first { $0.items.contains { $0.versionId == v.id } }?.name
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.baseName(v)).font(.system(size: 26, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
                        Text(store.variationText(v)).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
                        Text([routineName, "\(v.repRange) reps"].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    HStack(spacing: 8) {
                        Chip(text: "1 month", on: range == 30, small: true) { range = 30 }
                        Chip(text: "3 months", on: range == 90, small: true) { range = 90 }
                        Chip(text: "All", on: range == 0, small: true) { range = 0 }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                SectionLabel("Top set weight")
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
                    SectionLabel("Last sessions").padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(Array(all.reversed().prefix(8).enumerated()), id: \.element.id) { i, pt in
                            HStack(spacing: 10) {
                                Text(monthDay(pt.date)).font(.system(size: 14)).foregroundStyle(p.muted).frame(width: 64, alignment: .leading)
                                Text("\(fmtWeight(pt.weight)) \(unit) · " + pt.sets.map { "\($0.reps.map(String.init) ?? "–")\($0.plus ? "+" : "")" }.joined(separator: ", "))
                                    .font(.system(size: 16, weight: .semibold)).monospacedDigit().foregroundStyle(p.text).lineLimit(1)
                                Spacer()
                                switch pt.verdict {
                                case .up: Badge(text: "up", kind: .up)
                                case .down: Badge(text: "down", kind: .down)
                                case .none: Badge(text: "held")
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            if i < min(all.count, 8) - 1 { Divider1() }
                        }
                    }
                    .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
            .historyTools(versionId: v.id)
        }
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
