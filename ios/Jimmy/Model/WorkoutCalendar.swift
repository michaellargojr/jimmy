import Foundation

// History > Calendar. Days are the app's "yyyy-MM-dd" strings and weeks start on Monday,
// like Home's This week. Only finished workouts light a day.

enum CalendarMode: String, CaseIterable, Identifiable {
    case month, week
    var id: String { rawValue }
    var label: String { self == .month ? "Month" : "Week" }
}

private var mondayCalendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.firstWeekday = 2
    return c
}

/// Days from Monday: Monday 0 ... Sunday 6.
private func mondayOffset(_ d: Date) -> Int { (mondayCalendar.component(.weekday, from: d) + 5) % 7 }

private func adding(_ days: Int, to day: String) -> String {
    dayString(mondayCalendar.date(byAdding: .day, value: days, to: dayDate(day))!)
}

/// The Monday on or before `day`.
func weekStart(_ day: String) -> String { adding(-mondayOffset(dayDate(day)), to: day) }

/// Monday to Sunday of the week holding `day`.
func weekDays(_ day: String) -> [String] {
    let start = weekStart(day)
    return (0..<7).map { adding($0, to: start) }
}

/// The 1st of the month holding `day`.
func monthStart(_ day: String) -> String { String(day.prefix(8)) + "01" }

/// The month holding `day` in Monday-first rows of seven; nil pads the first and last rows.
func monthGrid(_ day: String) -> [String?] {
    let first = monthStart(day)
    let count = mondayCalendar.range(of: .day, in: .month, for: dayDate(first))?.count ?? 30
    var cells: [String?] = Array(repeating: nil, count: mondayOffset(dayDate(first)))
    for k in 0..<count { cells.append(adding(k, to: first)) }
    while cells.count % 7 != 0 { cells.append(nil) }
    return cells
}

/// The start of the month or week `steps` away from the one holding `day`.
func calendarStep(_ day: String, _ mode: CalendarMode, by steps: Int) -> String {
    switch mode {
    case .month: return dayString(mondayCalendar.date(byAdding: .month, value: steps, to: dayDate(monthStart(day)))!)
    case .week: return adding(7 * steps, to: weekStart(day))
    }
}

/// The start of the month or week holding `day`.
func periodStart(_ day: String, _ mode: CalendarMode) -> String { mode == .month ? monthStart(day) : weekStart(day) }

/// Finished workouts by day, newest first within a day.
func workoutsByDay(_ workouts: [Workout]) -> [String: [Workout]] {
    Dictionary(grouping: sortedNewestFirst(workouts.filter { $0.isFinished }), by: { $0.date })
}

/// How far back and forward the calendar pages: from the oldest finished workout to today.
func calendarBounds(_ days: some Collection<String>, _ mode: CalendarMode, today t: String = today()) -> ClosedRange<String> {
    let last = periodStart(t, mode)
    let first = days.min().map { min(periodStart($0, mode), last) } ?? last
    return first...last
}

/// "October" and "2026" for the month holding `day`.
func monthTitle(_ day: String) -> (month: String, year: String) {
    let d = dayDate(day)
    let m = DateFormatter(); m.dateFormat = "LLLL"
    let y = DateFormatter(); y.dateFormat = "yyyy"
    return (m.string(from: d), y.string(from: d))
}

/// "Oct 19 - 25", "Oct 26 - Nov 1", or "Dec 28 - Jan 3" for the week holding `day`.
func weekTitle(_ day: String) -> String {
    let days = weekDays(day)
    let a = dayDate(days[0]), b = dayDate(days[6])
    let f = DateFormatter(); f.dateFormat = "MMM d"
    let sameMonth = days[0].prefix(7) == days[6].prefix(7)
    let end = sameMonth ? String(mondayCalendar.component(.day, from: b)) : f.string(from: b)
    return "\(f.string(from: a)) - \(end)"
}

/// Where the calendar lands after a Month | Week switch. Into weeks: this week for the current
/// month, else the week of that month's last workout, else its first week.
func anchorAfterSwitch(_ anchor: String, to mode: CalendarMode, days: some Collection<String>, today t: String = today()) -> String {
    guard mode == .week else { return anchor }
    if monthStart(anchor) == monthStart(t) { return t }
    return days.filter { monthStart($0) == monthStart(anchor) }.max() ?? monthStart(anchor)
}

/// The exercises a summary lists: the ones with anything logged, in workout order.
func summaryItems(_ w: Workout) -> [WorkoutItem] { w.items.filter { $0.sets.contains { $0.hasData } } }

/// Done sets (warm-ups never count), the same count as the Workouts list.
func doneSetCount(_ w: Workout) -> Int { w.items.flatMap { $0.sets }.filter { $0.isDone }.count }
