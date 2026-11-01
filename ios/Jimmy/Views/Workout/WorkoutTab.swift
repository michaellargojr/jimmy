import SwiftUI

/// The Workout tab: the live workout when one is running, otherwise a start screen.
struct WorkoutTab: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if let w = store.activeWorkout {
            WorkoutView(workoutId: w.id)
        } else {
            WorkoutStartView()
        }
    }
}

struct WorkoutStartView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p

    private var ordered: [Routine] {
        if let s = store.activeSplit, !s.routineIds.isEmpty {
            let inSplit = s.routineIds.compactMap { store.routine($0) }
            let rest = store.routines.filter { r in !s.routineIds.contains(r.id) }
            return inSplit + rest
        }
        return store.routines.sorted { (routineLast($0, workouts: store.workouts)?.date ?? "0") < (routineLast($1, workouts: store.workouts)?.date ?? "0") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScreenTitle("Workout")
                    // The app noticed a style that needs its own weights. Here, after you finish, not mid-set.
                    if let offer = store.splitOffers.first {
                        SplitOfferCard(offer: offer).padding(.horizontal, 16)
                    }
                    if let next = store.upNextRoutine {
                        SectionLabel("Up next").padding(.horizontal, 16)
                        routineRow(next, highlight: true).padding(.horizontal, 16)
                    }
                    SectionLabel("Routines").padding(.horizontal, 16).padding(.top, 4)
                    ForEach(ordered.filter { $0.id != store.upNextRoutine?.id }) { r in
                        routineRow(r, highlight: false).padding(.horizontal, 16)
                    }
                    PillButton(title: "Quick workout", icon: "plus", full: true) { store.startQuickWorkout() }
                        .padding(.horizontal, 16).padding(.top, 8)
                    Text("A quick workout starts empty. Add exercises as you go.")
                        .font(.system(size: 13)).foregroundStyle(p.muted).padding(.horizontal, 18)
                }
                .padding(.bottom, 24)
            }
            .screen()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func routineRow(_ r: Routine, highlight: Bool) -> some View {
        Button { store.startWorkout(from: r) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.name).font(.system(size: 18, weight: .bold)).foregroundStyle(highlight ? p.onAccent : p.text)
                    Text("\(r.items.count) exercises · " + (routineLast(r, workouts: store.workouts).map { relativeDays($0.date) } ?? "never"))
                        .font(.system(size: 13)).foregroundStyle(highlight ? p.onAccent.opacity(0.75) : p.muted)
                }
                Spacer()
                Text("Start")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(highlight ? p.accent : p.onAccent)
                    .frame(height: 36).padding(.horizontal, 14)
                    .background(highlight ? p.accentPill : p.accent, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(highlight ? p.accent : p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
