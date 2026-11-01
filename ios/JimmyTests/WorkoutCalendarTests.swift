import Foundation
import Testing
@testable import Jimmy

// History > Calendar: Monday-first weeks, month grids, paging bounds, and which days light up.

private func entry(_ kind: SetKind = .working, _ weight: Double? = 40, _ reps: Int? = 8) -> SetEntry {
    SetEntry(kind: kind, unit: .kg, weight: weight, reps: reps)
}
private func finished(_ date: String, _ name: String = "W", startedAt: Double = 0, items: [WorkoutItem] = []) -> Workout {
    Workout(name: name, date: date, startedAt: startedAt, endedAt: startedAt + 3_600_000, items: items)
}

@Suite struct CalendarWeekTests {
    @Test func weeksStartOnMonday() {
        #expect(weekStart("2026-11-01") == "2026-10-26")   // a Sunday belongs to the week before
        #expect(weekStart("2026-10-26") == "2026-10-26")
        #expect(weekStart("2026-10-23") == "2026-10-19")
    }

    @Test func weekDaysRunMondayToSunday() {
        #expect(weekDays("2026-10-23") == ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25"])
        #expect(weekDays("2026-12-30").last == "2027-01-03")
    }

    @Test func weekTitles() {
        #expect(weekTitle("2026-10-21") == "Oct 19 - 25")
        #expect(weekTitle("2026-11-01") == "Oct 26 - Nov 1")
        #expect(weekTitle("2026-12-30") == "Dec 28 - Jan 3")
    }
}

@Suite struct CalendarMonthTests {
    @Test func octoberStartsOnThursday() {
        let g = monthGrid("2026-10-15")
        #expect(g.count == 35)
        #expect(g.prefix(3).allSatisfy { $0 == nil })
        #expect(g[3] == "2026-10-01")
        #expect(g[33] == "2026-10-31")
        #expect(g[34] == nil)
    }

    @Test func novemberNeedsSixRows() {
        let g = monthGrid("2026-11-01")
        #expect(g.count == 42)
        #expect(g[6] == "2026-11-01")
        #expect(g.compactMap { $0 }.count == 30)
    }

    @Test func februaryThatStartsOnMondayHasNoPadding() {
        let g = monthGrid("2027-02-10")
        #expect(g.count == 28)
        #expect(g.first == "2027-02-01")
        #expect(g.last == "2027-02-28")
    }

    @Test func steppingMonthsAndWeeks() {
        #expect(calendarStep("2026-10-23", .month, by: -1) == "2026-09-01")
        #expect(calendarStep("2026-10-23", .month, by: 1) == "2026-11-01")
        #expect(calendarStep("2026-01-15", .month, by: -1) == "2025-12-01")
        #expect(calendarStep("2026-10-23", .week, by: 1) == "2026-10-26")
        #expect(calendarStep("2026-10-23", .week, by: -1) == "2026-10-12")
    }
}

@Suite struct CalendarBoundsTests {
    @Test func pagesFromTheOldestWorkoutToToday() {
        let days = ["2026-10-23", "2026-08-03"]
        #expect(calendarBounds(days, .month, today: "2026-11-01") == "2026-08-01"..."2026-11-01")
        #expect(calendarBounds(days, .week, today: "2026-11-01") == "2026-08-03"..."2026-10-26")
    }

    @Test func noWorkoutsMeansOnlyToday() {
        #expect(calendarBounds([String](), .month, today: "2026-11-01") == "2026-11-01"..."2026-11-01")
    }

    @Test func weekViewListsEveryWeekOldestFirst() {
        let s = weekStarts(from: "2026-10-01", to: "2026-11-01")
        #expect(s == ["2026-09-28", "2026-10-05", "2026-10-12", "2026-10-19", "2026-10-26"])
        #expect(weekStarts(from: "2026-11-01", to: "2026-11-01") == ["2026-10-26"])
    }

    @Test func weekLabels() {
        #expect(weekLabel("2026-10-26", today: "2026-11-01") == "This week")
        #expect(weekLabel("2026-10-19", today: "2026-11-01") == "Last week")
        #expect(weekLabel("2026-10-12", today: "2026-11-01") == "Oct 12 - 18")
        #expect(weekLabel("2026-09-28", today: "2026-11-01") == "Sep 28 - Oct 4")
    }
}

@Suite struct CalendarDaysTests {
    @Test func onlyFinishedWorkoutsLightADay() {
        let open = Workout(name: "In progress", date: "2026-10-31")
        let byDay = workoutsByDay([finished("2026-10-23"), open])
        #expect(Set(byDay.keys) == ["2026-10-23"])
    }

    @Test func twoWorkoutsOnOneDayNewestFirst() {
        let am = finished("2026-10-23", "Morning", startedAt: 1_000)
        let pm = finished("2026-10-23", "Evening", startedAt: 50_000_000)
        #expect(workoutsByDay([am, pm])["2026-10-23"]?.map(\.name) == ["Evening", "Morning"])
    }

    @Test func summaryListsLoggedExercisesAndCountsDoneSets() {
        let logged = WorkoutItem(versionId: "a", sets: [entry(.warmup, 20, 12), entry(), entry(.working, 45, 6)])
        let warmupOnly = WorkoutItem(versionId: "b", sets: [entry(.warmup, 25, 8)])
        let untouched = WorkoutItem(versionId: "c", sets: [entry(.working, nil, nil)])
        let w = finished("2026-10-23", items: [logged, warmupOnly, untouched])
        #expect(summaryItems(w).map(\.versionId) == ["a", "b"])
        #expect(doneSetCount(w) == 2)
        #expect(topSet(logged)?.valueText == "45×6")
    }
}

@Suite struct CalendarMonthStatsTests {
    private func timed(_ date: String, minutes: Double) -> Workout {
        Workout(name: "W", date: date, startedAt: 1_000_000, endedAt: 1_000_000 + minutes * 60_000)
    }

    @Test func pastMonthAveragesOverTheWholeMonth() {
        let byDay = workoutsByDay(["2026-10-01", "2026-10-09", "2026-10-15", "2026-10-23", "2026-10-30"].map { timed($0, minutes: 60) })
        let s = monthStats(byDay, month: "2026-10-12", today: "2026-11-05")
        #expect(s.count == 5)
        #expect(perWeekText(s.perWeek) == "1.1 Workouts per Week")   // 5 over 31 days
        #expect(s.minutes == 60)
    }

    @Test func thisMonthCountsTheDaysSoFarButAtLeastAWeek() {
        let early = monthStats(workoutsByDay([timed("2026-11-01", minutes: 50)]), month: "2026-11-01", today: "2026-11-03")
        #expect(perWeekText(early.perWeek) == "1 Workout per Week")
        let mid = monthStats(workoutsByDay(["2026-11-02", "2026-11-06", "2026-11-11"].map { timed($0, minutes: 50) }), month: "2026-11-01", today: "2026-11-14")
        #expect(perWeekText(mid.perWeek) == "1.5 Workouts per Week")
    }

    @Test func averageLengthSkipsWorkoutsWithoutTimes() {
        let untimed = Workout(name: "Old", date: "2026-10-05", endedAt: 5)
        let s = monthStats(workoutsByDay([timed("2026-10-01", minutes: 60), timed("2026-10-02", minutes: 45), untimed]), month: "2026-10-01", today: "2026-11-01")
        #expect(s.count == 3)
        #expect(s.minutes == 53)   // 52.5 rounds up
        #expect(monthStats(workoutsByDay([untimed]), month: "2026-10-01", today: "2026-11-01").minutes == nil)
    }

    @Test func texts() {
        #expect(completedText(1) == "1 Workout Completed")
        #expect(completedText(5) == "5 Workouts Completed")
        #expect(perWeekText(2) == "2 Workouts per Week")
        #expect(perWeekText(0.96) == "1 Workout per Week")
        #expect(perWeekText(0.23) == "0.2 Workouts per Week")
        #expect(minutesPerWorkoutText(52) == "52 min per Workout")
    }
}
