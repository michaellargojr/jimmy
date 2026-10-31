import SwiftUI
import Charts

/// Opens a base's page from History > Exercises, sorted by muscle group.
struct BaseHistoryRoute: Hashable { var exerciseId: String }

/// One exercise's history: only its variations that have sessions, most recent first.
/// Tap one for its full history; back to pick another.
struct BaseHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let exerciseId: String

    var body: some View {
        let list = variationHistories(versions: store.variations(of: exerciseId), workouts: store.workouts)
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(list) { h in
                    NavigationLink(value: h.version) { VariationHistoryCard(version: h.version) }
                        .buttonStyle(.plain)
                }
                if list.isEmpty {
                    Text("No sessions yet.").font(.system(size: 14)).foregroundStyle(p.muted)
                }
            }
            .padding(16)
        }
        .screen()
        .navigationTitle(store.exercise(exerciseId)?.name ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(p.bg, for: .navigationBar)
    }
}

/// A variation with history, as a card: its chip, when it was last done and how many sessions,
/// the last sets, and a small line of the top set over time. Used on the History base page and
/// under Other variations on a variation's history.
struct VariationHistoryCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let version: Version

    var body: some View {
        let finished = store.finishedWorkouts
        let history = variationHistories(versions: [version], workouts: finished).first
        let lastSets = lastSession(versionId: version.id, workouts: finished, versions: store.versions)?
            .item.sets.filter { $0.kind != .warmup && $0.hasData } ?? []
        let points = progressPoints(versionId: version.id, workouts: finished, version: version)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                VariationPill(parts: store.variationChips(version))
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let history {
                            Text("\(monthDay(history.last)) - \(sessionsText(history.sessions))")
                                .font(.system(size: 13)).foregroundStyle(p.muted)
                        }
                        if !lastSets.isEmpty {
                            FlowRow(spacing: 12, lineSpacing: 2) {
                                ForEach(lastSets.prefix(3)) { s in
                                    Text(s.valueText).font(.system(size: 16, weight: .bold)).monospacedDigit().foregroundStyle(p.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if points.count > 1 { sparkline(points) }
                }
            }
            Chevron()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .contentShape(Rectangle())
    }

    private func sparkline(_ points: [ProgressPoint]) -> some View {
        Chart(points) { pt in
            LineMark(x: .value("Date", dayDate(pt.date)), y: .value("Weight", pt.weight))
                .foregroundStyle(p.secondary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            PointMark(x: .value("Date", dayDate(pt.date)), y: .value("Weight", pt.weight))
                .symbol(.square).symbolSize(24).foregroundStyle(p.secondary)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .frame(width: 80, height: 40)
    }
}
