import SwiftUI

/// History > Calendar. Month: one month at a time, arrows or a sideways swipe to change it, with
/// workouts completed, workouts per week and minutes per workout in the accent under the grid.
/// Week: every week since the first workout, each a strip like Home's This week, with
/// This week at the bottom. A day with a finished workout is filled with the accent; today has
/// an outline. Tap a lit day for a summary that slides up, with See details opening that
/// workout's page.
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
        // A plain container (not a Group), so the sheet sits on one view whichever mode shows.
        VStack(spacing: 0) {
            switch mode {
            case .month: months(byDay)
            case .week: weeks(byDay)
            }
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

    // MARK: Month

    private func months(_ byDay: [String: [Workout]]) -> some View {
        let bounds = calendarBounds(byDay.keys, .month)
        let start = monthStart(anchor)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                monthRow(start: start, bounds: bounds)
                // A ZStack, so the old and new month overlap while they slide.
                ZStack(alignment: .topLeading) {
                    monthGridView(start, byDay)
                        .id(start)
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
    }

    /// "October 2026" with the arrows.
    private func monthRow(start: String, bounds: ClosedRange<String>) -> some View {
        let t = monthTitle(start)
        return HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(t.month).foregroundStyle(p.text)
                Text(t.year).foregroundStyle(p.muted)
            }
            .font(.system(size: 22, weight: .heavy))
            .tracking(-0.3)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            arrow("chevron.left", label: "Earlier month", enabled: start > bounds.lowerBound) { step(-1, bounds: bounds) }
            arrow("chevron.right", label: "Later month", enabled: start < bounds.upperBound) { step(1, bounds: bounds) }
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
        let next = calendarStep(anchor, .month, by: by)
        guard bounds.contains(next) else { return }
        forward = by > 0
        withAnimation(.snappy(duration: 0.28)) { anchor = next }
    }

    private func monthGridView(_ start: String, _ byDay: [String: [Workout]]) -> some View {
        let cells = monthGrid(start)
        let stats = monthStats(byDay, month: start)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(weekDays(start), id: \.self) { d in
                    Text(weekdayLetters(d))
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
                                Color.clear.frame(maxWidth: .infinity).frame(height: DayTile.Style.number.height)
                            }
                        }
                    }
                }
            }
            if stats.count > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text(completedText(stats.count))
                    Text(perWeekText(stats.perWeek))
                    if let m = stats.minutes { Text(minutesPerWorkoutText(m)) }
                }
                .font(.system(size: 14)).monospacedDigit().foregroundStyle(p.accent).padding(.top, 6)
            }
        }
    }

    // MARK: Week

    /// Every week from the first workout's to this one, oldest on top; opens at This week.
    private func weeks(_ byDay: [String: [Workout]]) -> some View {
        let t = today()
        let starts = weekStarts(from: byDay.keys.min() ?? t, to: t)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(starts, id: \.self) { s in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(weekLabel(s, today: t))
                        HStack(spacing: 8) {
                            ForEach(weekDays(s), id: \.self) { d in
                                DayTile(day: d, workouts: byDay[d] ?? [], style: .weekday) { picked = DayPick(day: d) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .defaultScrollAnchor(.bottom)
    }
}

/// "Mo", "Tu", like Home's week tiles.
func weekdayLetters(_ day: String) -> String { String(weekdayShort(day).prefix(2)).capitalized }

struct DayPick: Identifiable { let day: String; var id: String { day } }

/// One day. Filled with the accent when a workout finished that day; outlined when it is today.
struct DayTile: View {
    /// Month tiles show the date; week tiles show the weekday, like Home's This week.
    enum Style {
        case number, weekday
        var height: CGFloat { self == .number ? 46 : 52 }
    }

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
        let tile = ZStack {
            if style == .weekday {
                Text(weekdayLetters(day)).font(.system(size: 12, weight: .bold))
            } else {
                Text(dayNumber(day)).font(.system(size: lit ? 16 : 15, weight: lit ? .heavy : .semibold)).monospacedDigit()
            }
        }
        .foregroundStyle(fg)
        .frame(maxWidth: .infinity)
        .frame(height: style.height)
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
