# What's new in Jimmy

<!--
Newest version on top. The lines under a version are written for anyone using the app, so they
can be pasted as they are into the App Store's "What's New in This Version" (4000 characters max).
The note under each heading (build, PRs, install details) is ours and is never pasted.
How versions and builds move, and who writes the next entry: ios/README.md.
-->

## 2.3 - Nov 2, 2026

<!-- Build 3. The split page rework from Michael's notes after the 2.2 install (Model/SplitBuilding.swift, Views/Plan/FromRoutinesSheet.swift), on claude/awesome-allen-64bza1. -->

- New routine on a split page offers to take exercises from your other routines: open any routine, tick the exercises you want, from as many routines as you like, and they join the new routine together. A superset ticked whole stays a superset.
- From my routines is also a button on every routine's page and in the edit sheet on the split page.
- Hold any routine under Add a routine for Rename, Duplicate or Delete, the same as under In this split. A routine duplicated from the split page joins that split, with Undo.
- A new split opens its page straight away. While a split has no routines yet, Coverage sits at the bottom, under Goals, In this split, New routine and Add a routine. A split with routines keeps Coverage second.

## 2.2 - Nov 2, 2026

<!-- Build 2. PRs #24 to #28, the Workout scrolling rework (claude/project-thread-iayncu at ed8ad5e), nicknames (claude/project-thread-3v8j1k at eda86c7) and the lock screen card (claude/project-thread-0mu8do at fea0318, layout C2 draft), merged on claude/awesome-allen-64bza1. Nicknames and the lock screen card had not finished their Mac test run when merged; the GitHub Actions iOS check (.github/workflows/ios.yml) compiles and tests the merged code. Built for Michael's iPhone 12 mini. -->

- Scrolling through a workout is free, no more snapping.
- During a workout the app opens on the Workout page at your next set, glides back to it after a pause (Settings > Workout > Back to your set after), and the Workout tile tapped again takes you there.
- Pocket mode: the screen goes dark in a pocket and comes back on your set.
- Grouped exercises are labelled Superset 1, 2 (Triset, Circuit) with more space between them.
- The strip under the clock fills in your color as exercises are finished, and nothing follows your scrolling.
- A lock screen card during a workout: your set number and the clock, with the exercise and its chips. Tap it to open the app at your set.
- Nicknames like Bayesian Curl or Pec Deck show as a tag beside the exercise name. Five are filled in for you; edit or clear any in the variation's Defaults or the add sheet.
- Duplicate a routine, edit routines from the split page, and hold a routine for its options.
- Add clips to the Jimmy library straight from Settings with the + button.
- Settings shows the app's version and build at the bottom.
- Your data file is never replaced if it ever fails to open.

## 2.1 - Nov 2, 2026

<!-- Build 1. PRs #18 to #23, plus the final versions of #15, #16 and #17, merged into the iOS branch at 4190e0d. Built for Michael's iPhone 12 mini. -->

- History has a calendar. Workout days light up, switch between Month and Week, and tap a day to see that workout.
- Each exercise in History shows how many workouts and the last date, like "3 Workouts - Last Oct 23".
- In History, Workouts is now called Routines.
- Swiping between exercises responds right away. A light flick moves one exercise, and a long card scrolls to its end first.
- A Start button on each workout, so the clock starts when you do.
- The Workout page fits smaller iPhones.
- Two new colors: Crimson, a deep red, and Flamingo, the old Signal red.
- Buttons and the last row of every page stay clear of the tab bar.
- The keyboard closes when you tap away or scroll.
- Long variation names wrap onto two lines.
- New variations always go through the full setup, so every entry is recorded the same way.

## 2.0 - Nov 1, 2026

<!-- Build 1. The first install on a real iPhone (free Apple ID, Oct 31 23:00 UTC). Code: iOS branch 1375bff plus PR #15 (cfad644), #16 (7d77760) and #17 (20f67c1). The Oct 19 and Oct 23 workouts from the old web app were merged into Michael's data for this install; that was a data move, not an app change. -->

- Back up to a folder in iCloud Drive after every finished workout, or any time with Back up now. Restore any backup from Settings > Backup.
- A floating tab bar with the Workout button in the middle.
- Machines can be their own variations. Pick the machine type and Plates or Stack, or answer a few questions with Help me choose.
- Any style, like a grip or an attachment, can become its own variation, and its past sessions move with it.
- Machine screens fit smaller iPhones.

## 1.0 - Oct 23 to Oct 31, 2026

<!-- Simulator only, built from Xcode on the Mac. PR #1 (the app), #2 Mantra, #3 library, #4 goals and coverage, #5 form cues, #6 set entry, #7 icon, #8 one shared build, #9 Workout fixes and Overview, #10 history tools, #11 rep ranges, #12 white names, #13 chips, #14 History sort. Before 1.0, Jimmy was a web app. -->

- Jimmy as an iPhone app: Home, Plan, Workout, History and Settings, in dark or light with your choice of color.
- An editable Mantra card on Home.
- An exercise library with exercises, variations and styles. Each variation keeps its own history and rep range.
- Set goals for a split, see how well it covers each muscle, and get suggestions from Claude with your own API key.
- Form cues: save clips and links on each variation.
- A new set entry for weight, reps and how much you felt it, and a new exercise card.
- The flexing J app icon, in your color.
- Confirm before Finish or Discard, one-arm sets in pairs, and an Overview you can always edit.
- Hold Last time to see your last few sessions, or open the full history of an exercise.
- Copy, move or erase a variation's history.
- Rep range templates (Default, Lower, Mid, High) and a one-row Workout top bar with a progress strip.
- Exercise names in white with muscle tags.
- Variation chips everywhere, and the rep range next to Form cues.
- History sorted by muscle group or most recent.
