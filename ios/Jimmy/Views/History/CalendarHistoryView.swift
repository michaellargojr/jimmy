import SwiftUI

/// History > Calendar: a month (or one week) of day tiles. A day with a finished workout is
/// filled with the accent, like Home's This week; today has an outline. Tap a lit day for a
/// summary that slides up, with See details opening that workout's page.
struct CalendarHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @AppStorage("historyCalendarMode") private var modeRaw = CalendarMode.month.rawValue
    @State private var anchor = today()
    @State private var forward = true
    @State private var picked: DayPick?
    @State private var pending: Workout?
    /// Pushes a workout's page onto History's stack.
    let open: (Workout) -> Void

    private var mode: CalendarMode { CalendarMode(rawValue: modeRaw) ?? .month }

    var body: some View {
        let byDay = workoutsByDay(store.workouts)
        let bounds = calendarBounds(byDay.keys, mode)
        let start = periodStart(anchor, mode)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                periodRow(start: start, bounds: bounds)
                // A ZStack, so the old and new month overlap while they slide.
                ZStack(alignment: .topLeading) {
                    Group {
                        switch mode {
                        case .month: monthView(start, byDay)
                        case .week: weekView(start, byDay)
                        }
                    }
                    .id("\(mode.rawValue)-\(start)")
                    .transition(.push(from: forward ? .trailing : .leading))
                }
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                    step(dx < 0 ? 1 : -1, bounds: bounds)
                })
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .clipped()
        }
        .background(p.bg.ignoresSafeArea())
        .sheet(item: $picked, onDismiss: {
            if let w = pending { pending = nil; open(w) }
        }) { pick in
            WorkoutDaySummary(day: pick.day) { w in pending = w; picked = nil }
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(p.card)
        }
        .onChange(of: modeRaw) { _, raw in
            anchor = anchorAfterSwitch(anchor, to: CalendarMode(rawValue: raw) ?? .month, days: byDay.keys)
        }
        #if DEBUG
        // Screenshots on a test simulator: -calendarAnchor 2026-10-15 -calendarPick 2026-10-23
        // (-historyCalendarMode week sets the switch, since it's stored in user defaults).
        .onAppear {
            let d = UserDefaults.standard
            if let a = d.string(forKey: "calendarAnchor") { anchor = a }
            if let k = d.string(forKey: "calendarPick") { picked = DayPick(day: k) }
        }
        #endif
    }

    // MARK: Month or week title, with arrows

    private func periodRow(start: String, bounds: ClosedRange<String>) -> some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if mode == .month {
                    let t = monthTitle(start)
                    Text(t.month).foregroundStyle(p.text)
                    Text(t.year).foregroundStyle(p.muted)
                } else {
                    Text(weekTitle(start)).foregroundStyle(p.text)
                }
            }
            .font(.system(size: 22, weight: .heavy))
            .tracking(-0.3)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            arrow("chevron.left", label: mode == .month ? "Earlier month" : "Earlier week", enabled: start > bounds.lowerBound) { step(-1, bounds: bounds) }
            arrow("chevron.right", label: mode == .month ? "Later month" : "Later week", enabled: start < bounds.upperBound) { step(1, bounds: bounds) }
        }
    }

    private func arrow(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold))
                .foregroundStyle(p.text)
                .frame(width: 44, height: 44)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    private func step(_ by: Int, bounds: ClosedRange<String>) {
        let next = calendarStep(anchor, mode, by: by)
        guard bounds.contains(next) else { return }
        forward = by > 0
        withAnimation(.snappy(duration: 0.28)) {
            // The current month or week keeps today as its anchor, so a switch lands on this week.
            anchor = next == periodStart(today(), mode) ? today() : next
        }
    }

    // MARK: Month

    private func monthView(_ start: String, _ byDay: [String: [Workout]]) -> some View {
        let cells = monthGrid(start)
        let count = byDay.filter { monthStart($0.key) == start }.reduce(0) { $0 + $1.value.count }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdayLetters(weekDays(start)[i]))
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(p.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(spacing: 6) {
                ForEach(0..<(cells.count / 7), id: \.self) { r in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { c in
                            if let d = cells[r * 7 + c] {
                                DayTile(day: d, workouts: byDay[d] ?? [], style: .number) { picked = DayPick(day: d) }
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: DayTile.monthHeight)
                            }
                        }
                    }
                }
            }
            if count > 0 {
                Text(count == 1 ? "1 workout" : "\(count) workouts")
                    .font(.system(size: 14)).foregroundStyle(p.muted).padding(.top, 6)
            }
        }
    }

    // MARK: Week

    private func weekView(_ start: String, _ byDay: [String: [Workout]]) -> some View {
        let days = weekDays(start)
        let list = days.reversed().flatMap { byDay[$0] ?? [] }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { d in
                    DayTile(day: d, workouts: byDay[d] ?? [], style: .weekdayAndNumber) { picked = DayPick(day: d) }
                }
            }
            VStack(spacing: 10) {
                ForEach(list) { w in
                    NavigationLink(value: w) {
                        WorkoutRow(workout: w)
                            .background(p.card, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// "Mo", "Tu", like Home's week tiles.
func weekdayLetters(_ day: String) -> String { String(weekdayShort(day).prefix(2)).capitalized }

struct DayPick: Identifiable { let day: String; var id: String { day } }

/// One day. Filled with the accent when a workout finished that day; outlined when it is today.
struct DayTile: View {
    enum Style { case number, weekdayAndNumber }
    static let monthHeight: CGFloat = 46
    static let weekHeight: CGFloat = 64

    @Environment(\.palette) private var p
    let day: String
    let workouts: [Workout]
    let style: Style
    let tap: () -> Void

    var body: some View {
        let lit = !workouts.isEmpty
        let t = today()
        let isToday = day == t
        let future = day > t
        let fg = lit ? p.onAccent : isToday ? p.text : future ? p.muted.opacity(0.45) : p.muted
        let tile = VStack(spacing: 2) {
            if style == .weekdayAndNumber {
                Text(weekdayLetters(day)).font(.system(size: 11, weight: .bold)).opacity(lit ? 0.75 : 1)
                Text(dayNumber(day)).font(.system(size: 19, weight: .heavy))
            } else {
                Text(dayNumber(day)).font(.system(size: lit ? 16 : 15, weight: lit ? .heavy : .semibold))
            }
        }
        .monospacedDigit()
        .foregroundStyle(fg)
        .frame(maxWidth: .infinity)
        .frame(height: style == .number ? Self.monthHeight : Self.weekHeight)
        .background(lit ? p.accent : p.card, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(isToday && !lit ? p.border : .clear, lineWidth: 2))

        if lit {
            Button(action: tap) { tile }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dayDate(day).formatted(.dateTime.weekday(.wide).month(.wide).day())), \(workouts.map(\.name).joined(separator: ", "))")
        } else {
            tile.accessibilityLabel(dayDate(day).formatted(.dateTime.weekday(.wide).month(.wide).day()))
        }
    }
}

/// The slide-up summary for a day: each finished workout's name, time, exercises and sets,
/// every exercise with its top set, and See details.
struct WorkoutDaySummary: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let day: String
    let details: (Workout) -> Void

    var body: some View {
        let list = workoutsByDay(store.workouts)[day] ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(list) { w in
                    VStack(alignment: .leading, spacing: 14) {
                        block(w)
                        if list.count > 1 { seeDetails(w) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            if list.count == 1, let w = list.first {
                seeDetails(w)
                    .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 8)
                    .background(p.card)
            }
        }
    }

    private func seeDetails(_ w: Workout) -> some View {
        PillButton(title: "See details", style: .primary, full: true, height: 52) { details(w) }
    }

    private func block(_ w: Workout) -> some View {
        let items = summaryItems(w)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(w.name).font(.system(size: 24, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
                Text(dayDate(w.date).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 14)).foregroundStyle(p.muted)
            }
            HStack(spacing: 8) {
                if let m = w.durationMinutes { stat("\(m)", "MIN") }
                stat("\(items.count)", "EXERCISES")
                stat("\(doneSetCount(w))", "SETS")
            }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    if let v = store.version(item.versionId) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(store.baseName(v)).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                                Spacer(minLength: 0)
                                if let t = topSet(item) {
                                    Text(t.valueText).font(.system(size: 16, weight: .bold)).monospacedDigit().foregroundStyle(p.secondary)
                                }
                            }
                            VariationChips(tags: store.variationChips(v), size: .small, note: store.style(item.styleId)?.label)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .top) { if i > 0 { Rectangle().fill(p.line).frame(height: 1) } }
                    }
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).monospacedDigit().foregroundStyle(p.text)
            Text(label).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(p.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Month | Week, at the top right of History while Calendar is open.
struct CalendarModeSwitch: View {
    @Environment(\.palette) private var p
    @AppStorage("historyCalendarMode") private var modeRaw = CalendarMode.month.rawValue

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarMode.allCases) { m in
                let on = modeRaw == m.rawValue
                Button { modeRaw = m.rawValue } label: {
                    Text(m.label)
                        .font(.system(size: 13, weight: on ? .bold : .semibold))
                        .foregroundStyle(on ? p.text : p.secondary)
                        .frame(height: 30)
                        .padding(.horizontal, 13)
                        .background(on ? p.border : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
