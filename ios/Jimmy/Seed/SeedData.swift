import Foundation

// One-time import of Michael's Notion workout history (Aug 3 to Oct 15, 2026).
// Ported from src/seed/notion.ts. Set grammar per line: [W] [L|R] [EZ] <weight|-> x <reps|->[+] [pN] [# note]

/// One of the 40 exercises Michael logged, mapped onto the library: the name his notes used,
/// the base it belongs to, the variation and the style. Names that land on one variation merge.
struct SeedExercise {
    var name: String
    var base: String
    var group: MuscleGroup
    var variation: VariationSpec
    var style: StyleSpec = StyleSpec()
    var aliases: [String] = []
    var notes: String? = nil
    var repMin: Int = 5; var repMax: Int = 8
}
struct SeedEntry { var ex: String; var group: String? = nil; var sets: [String]; var note: String? = nil }
struct SeedWorkout {
    var date: String; var name: String; var routine: String? = nil; var gym: String? = nil; var notes: String? = nil
    var groups: [String: GroupType] = [:]; var entries: [SeedEntry]
}
struct SeedRoutineItem { var ex: String; var group: String? = nil }
struct SeedRoutine { var name: String; var items: [SeedRoutineItem]; var groups: [String: GroupType] = [:] }

let SEED_GYMS = ["Ultradynamic Fitness - Catalunan Grande", "Ultradynamic Fitness - Bangkal"]

private func hi(_ e: SeedExercise) -> SeedExercise { var x = e; x.repMin = 10; x.repMax = 15; return x }
private func S(_ name: String, _ base: String, _ group: MuscleGroup, _ v: VariationSpec, style: StyleSpec = StyleSpec(),
               aliases: [String] = [], notes: String? = nil) -> SeedExercise {
    SeedExercise(name: name, base: base, group: group, variation: v, style: style, aliases: aliases, notes: notes)
}
private func V(_ family: EquipmentFamily, arms: Arms = .two, position: Position? = nil, tag: String? = nil) -> VariationSpec {
    VariationSpec(family: family, arms: arms, position: position, tag: tag)
}

let SEED_EXERCISES: [SeedExercise] = [
    // Core
    hi(S("Kneeling Cable Crunch", "Crunch", .Abs, V(.cable, position: .kneeling))),
    hi(S("Standing Cable Crunch", "Crunch", .Abs, V(.cable, position: .standing))),
    // Back
    S("Cable Pulldown (Extended)", "Pulldown", .Back, V(.cable, arms: .one), notes: "Added mid-workout Sep 21."),
    S("Cable Seated Row", "Row", .Back, V(.cable, position: .seated)),
    hi(S("Cable Shrug", "Shrug", .Back, V(.cable))),
    S("Chest-Supported Row", "Row", .Back, V(.machine, position: .chestSupported)),
    S("Face Pull", "Face Pull", .Shoulders, V(.cable)),
    S("High-to-Low Pulldown Machine", "Pulldown", .Back, V(.machine, tag: "high row"), notes: "Double or single arm. Sep 21: left shoulder pain on eccentric, consider abandoning."),
    S("Lat Pulldown (Two-Arm)", "Pulldown", .Back, V(.cable)),
    S("One-Arm Lat Pulldown", "Pulldown", .Back, V(.cable, arms: .one)),
    S("Seated Unilateral Cable Row", "Row", .Back, V(.cable, arms: .one), aliases: ["Seated extended unilateral cable rows"]),
    S("Standing Cable Row", "Row", .Back, V(.cable, position: .standing)),
    // Biceps
    S("Hammer Curl", "Hammer Curl", .Biceps, V(.cable), notes: "Part of the bicep triset."),
    S("Incline Dumbbell Curl", "Curl", .Biceps, V(.dumbbell, position: .armsBehind)),
    S("Single-Arm Bayesian Curl", "Curl", .Biceps, V(.cable, arms: .one, position: .armsBehind), notes: "Part of the bicep triset."),
    S("Single-Arm Cable Curl", "Curl", .Biceps, V(.cable, arms: .one), aliases: ["Single arm curls"], notes: "Part of the bicep triset."),
    S("Spider Curl", "Curl", .Biceps, V(.dumbbell, position: .chestSupported)),
    S("Standing Barbell Curl", "Curl", .Biceps, V(.bar, position: .standing), style: StyleSpec(barType: .barbell)),
    // Calves
    hi(S("Standing Calf Raise Machine", "Calf Raise", .Calves, V(.machine, position: .standing))),
    hi(S("Standing Calf Raise (D Stars)", "Calf Raise", .Calves, V(.machine, position: .standing, tag: "D Stars"), notes: "Own history. Weight is plates added.")),
    hi(S("Smith Machine Calf Raise", "Calf Raise", .Calves, V(.bar, position: .standing), style: StyleSpec(barType: .smith), notes: "Weight is total on the bar.")),
    // Chest
    S("Chest Fly", "Chest Fly", .Chest, V(.machine, arms: .one), notes: "Aug 7 tracked left/right separately."),
    S("Incline Chest Fly Machine", "Incline Fly", .Chest, V(.machine), notes: "Weight recorded as each side."),
    S("Low-to-High Chest Fly", "Incline Fly", .Chest, V(.cable, arms: .one, position: .standing), style: StyleSpec(cableHeight: .ankle)),
    S("Machine Dip", "Dip", .Chest, V(.machine)),
    S("Pec Deck", "Chest Fly", .Chest, V(.machine), style: StyleSpec(machine: "Pec deck")),
    S("Incline Bench Press", "Incline Press", .Chest, V(.bar, position: .lying), style: StyleSpec(barType: .barbell)),
    // Forearms
    hi(S("Cable Wrist Curl", "Wrist Curl", .Forearms, V(.cable, arms: .one), aliases: ["Single cable wrist curl"])),
    hi(S("Reverse Cable Wrist Curl", "Reverse Wrist Curl", .Forearms, V(.cable))),
    // Shoulders
    S("Cable Lateral Raise", "Lateral Raise", .Shoulders, V(.cable, arms: .one), aliases: ["Side cable lateral raise"]),
    S("Dumbbell Shoulder Press", "Shoulder Press", .Shoulders, V(.dumbbell, position: .seated)),
    S("Front Raise", "Front Raise", .Shoulders, V(.dumbbell, arms: .one)),
    S("Lateral Raise", "Lateral Raise", .Shoulders, V(.dumbbell)),
    S("Reverse Rear Delt Fly", "Rear Delt Fly", .Shoulders, V(.machine)),
    S("Rope Cable Front Raise", "Front Raise", .Shoulders, V(.cable), style: StyleSpec(attachment: "rope")),
    S("Shoulder Lateral Machine Press", "Shoulder Press", .Shoulders, V(.machine)),
    S("Upright Row", "Upright Row", .Shoulders, V(.bar), style: StyleSpec(barType: .ez)),
    // Triceps
    S("One-Arm Cuffed Tricep Extension", "Tricep Extension", .Triceps, V(.cable, arms: .one, tag: "overhead"), style: StyleSpec(attachment: "cuff")),
    S("Standing Cable Tricep Extension", "Tricep Extension", .Triceps, V(.cable, tag: "overhead")),
    S("Tricep Pushdown", "Tricep Pushdown", .Triceps, V(.cable, arms: .one), aliases: ["Tricep pull downs"]),
]

/// How an old free-form version name maps onto the library. Used by the seed and by the
/// migration of exports made before the library existed.
struct LegacyMapping { var base: String; var group: MuscleGroup; var variation: VariationSpec; var style: StyleSpec }

func legacyMapping(for name: String) -> LegacyMapping? {
    let n = name.trimmingCharacters(in: .whitespaces)
    guard let e = SEED_EXERCISES.first(where: { $0.name.caseInsensitiveCompare(n) == .orderedSame
        || $0.aliases.contains { $0.caseInsensitiveCompare(n) == .orderedSame } }) else { return nil }
    return LegacyMapping(base: e.base, group: e.group, variation: e.variation, style: e.style)
}

private let G = SEED_GYMS

let SEED_WORKOUTS: [SeedWorkout] = [
    SeedWorkout(date: "2026-08-03", name: "Biceps", routine: "Biceps, Forearms, Abs",
                notes: "From Apple Note \"Gym\". Units were not written; assumed kg.",
                groups: ["A": .triset],
                entries: [
                    SeedEntry(ex: "Single-Arm Bayesian Curl", group: "A", sets: ["14x15+", "18x6", "14x6"]),
                    SeedEntry(ex: "Single-Arm Cable Curl", group: "A", sets: ["14x12+", "14x7", "14x6"]),
                    SeedEntry(ex: "Hammer Curl", group: "A", sets: ["27x8", "27x5", "23x6"]),
                ]),
    SeedWorkout(date: "2026-08-07", name: "Triceps, Chest, Shoulders",
                notes: "First exercise in the note had no name (25kg warm-up x15, 55kg x16, 60kg x8), not imported.",
                entries: [
                    SeedEntry(ex: "Tricep Pushdown", sets: ["45x14", "L 50x8", "R 50x10", "L 50x6", "R 50x8"]),
                    SeedEntry(ex: "Chest Fly", sets: ["W 10x-", "20x10", "L 20x10", "R 20x13 # right stronger"]),
                    SeedEntry(ex: "Low-to-High Chest Fly", sets: ["W 10x10", "R 20x9", "L 20x8", "L 20x8", "R 20x8"]),
                    SeedEntry(ex: "Lateral Raise", sets: ["15x5 # right bad form", "15x8 # drop set to 10kg"]),
                    SeedEntry(ex: "Front Raise", sets: ["R 10x11 # right stronger", "L 10x9", "10x-"]),
                ]),
    SeedWorkout(date: "2026-08-20", name: "Back and Abs", routine: "Back and Abs",
                entries: [
                    SeedEntry(ex: "Face Pull", sets: ["W 25x-", "40x11", "40x-"]),
                    SeedEntry(ex: "Standing Cable Row", sets: ["60x12+", "65x11", "65x10"]),
                    SeedEntry(ex: "One-Arm Lat Pulldown", sets: ["R 40x10", "L 40x13 # L stronger", "40x7", "40x8"]),
                    SeedEntry(ex: "Seated Unilateral Cable Row", sets: ["R 30x15 # R stronger", "L 30x12", "L 35x12", "R 35x10"]),
                    SeedEntry(ex: "Cable Shrug", sets: ["65x17+", "70x15"]),
                    SeedEntry(ex: "Standing Cable Crunch", sets: ["70x10", "70x9"]),
                    SeedEntry(ex: "Kneeling Cable Crunch", sets: ["65x7"]),
                ]),
    SeedWorkout(date: "2026-08-29", name: "Triceps and Chest", routine: "Triceps and Chest",
                entries: [
                    SeedEntry(ex: "Standing Cable Tricep Extension", sets: ["W -x-", "60x12+", "65x9 # wrists hurt, heavy"]),
                    SeedEntry(ex: "One-Arm Cuffed Tricep Extension", sets: ["50x12+", "50x10+"]),
                    SeedEntry(ex: "Pec Deck", sets: ["W 35x-", "50x8+", "50x-"]),
                    SeedEntry(ex: "Incline Chest Fly Machine", sets: ["5x8 # 5kg each side", "5x5"]),
                    SeedEntry(ex: "Machine Dip", sets: ["W 30x-", "50x10+", "50x7", "50x6"]),
                ]),
    SeedWorkout(date: "2026-09-09", name: "Shoulders", routine: "Shoulders",
                entries: [
                    SeedEntry(ex: "Dumbbell Shoulder Press", sets: ["W 12.5x11+", "15x10", "15x8"]),
                    SeedEntry(ex: "Shoulder Lateral Machine Press", sets: ["W 15x10+", "30x8+", "30x6+"]),
                    SeedEntry(ex: "Reverse Rear Delt Fly", sets: ["30x7 # was tired off previous exercise", "30x12+"]),
                    SeedEntry(ex: "Rope Cable Front Raise", sets: ["W 10x13+", "15x4", "10x7"]),
                    SeedEntry(ex: "Cable Lateral Raise", sets: ["5x10+", "5x8+"]),
                    SeedEntry(ex: "Upright Row", sets: ["EZ 15x12+", "20x10+", "20x-"]),
                ]),
    SeedWorkout(date: "2026-09-14", name: "Biceps, Forearms, Calves", routine: "Biceps, Forearms, Abs",
                groups: ["A": .triset, "B": .superset],
                entries: [
                    SeedEntry(ex: "Single-Arm Bayesian Curl", group: "A", sets: ["30x13", "30x5"]),
                    SeedEntry(ex: "Single-Arm Cable Curl", group: "A", sets: ["20x6", "15x5"]),
                    SeedEntry(ex: "Hammer Curl", group: "A", sets: ["30x6", "30x4"]),
                    SeedEntry(ex: "Incline Dumbbell Curl", sets: ["10x10+", "10x7"]),
                    SeedEntry(ex: "Spider Curl", sets: ["10x5", "7.5x10+"]),
                    SeedEntry(ex: "Cable Wrist Curl", group: "B", sets: ["30x12+", "30x11+"]),
                    SeedEntry(ex: "Reverse Cable Wrist Curl", group: "B", sets: ["35x10+", "35x-"]),
                    SeedEntry(ex: "Standing Calf Raise Machine", sets: ["80x20+", "100x-", "80x-"]),
                ]),
    SeedWorkout(date: "2026-09-21", name: "Back and Abs", routine: "Back and Abs", gym: G[0],
                entries: [
                    SeedEntry(ex: "High-to-Low Pulldown Machine", sets: ["R 25x10+ p2 # underhand grip", "L 25x7+ p1 # shoulder discomfort, arm twisting", "15x7+ # overhand grip, left shoulder pain on eccentric, probably abandon"]),
                    SeedEntry(ex: "Lat Pulldown (Two-Arm)", sets: ["50x9 p3 # good mind-muscle connection", "50x7 p5"]),
                    SeedEntry(ex: "Chest-Supported Row", sets: ["15x9 p2 # stopped partway, switched to unilateral", "R 15x8 p2 # side grip", "L 15x-"]),
                    SeedEntry(ex: "Cable Pulldown (Extended)", sets: ["W L 30x15+ p5", "W R 30x10+ p5", "L 40x12 p3", "R 40x9 p2", "R 40x6", "L 40x10"]),
                    SeedEntry(ex: "Cable Seated Row", sets: ["55x6+", "50x7+ p2", "40x12 p2"]),
                    SeedEntry(ex: "Cable Shrug", sets: ["70x10+ p2", "70x9 p3", "70x9 p10"]),
                    SeedEntry(ex: "Standing Cable Crunch", sets: []),
                    SeedEntry(ex: "Kneeling Cable Crunch", sets: []),
                ]),
    SeedWorkout(date: "2026-10-01", name: "Triceps and Chest", routine: "Triceps and Chest", gym: G[0],
                entries: [
                    SeedEntry(ex: "Standing Cable Tricep Extension", sets: ["W -x-", "65x11", "65x7"]),
                    SeedEntry(ex: "One-Arm Cuffed Tricep Extension", sets: ["R 50x6 p2", "L 50x10 p2", "R 50x8 p2", "L 50x9 p2", "R 50x5 p1", "L 50x6 p1"]),
                    SeedEntry(ex: "Pec Deck", sets: ["50x12+ p2"]),
                    SeedEntry(ex: "Incline Chest Fly Machine", sets: ["W 0x-", "10x4 p3", "5x7+ p3"]),
                    SeedEntry(ex: "Machine Dip", sets: ["W 30x-", "50x7 p2", "50x7 p2"]),
                    SeedEntry(ex: "Incline Bench Press", sets: ["60x5 p1 # no warmup", "50x8"], note: "Added on the fly (was a text note under the page)."),
                ]),
    SeedWorkout(date: "2026-10-10", name: "Shoulders", routine: "Shoulders", gym: G[1],
                entries: [
                    SeedEntry(ex: "Dumbbell Shoulder Press", sets: ["W 7.5x12", "15x15", "17.5x8 p1"]),
                    SeedEntry(ex: "Shoulder Lateral Machine Press", sets: ["W 15x12+", "30x6 p5", "30x7+ p4"]),
                    SeedEntry(ex: "Reverse Rear Delt Fly", sets: ["W 20x13+", "35x9 p1", "35x10+"]),
                    SeedEntry(ex: "Rope Cable Front Raise", sets: ["10x12 p3", "10x7 p4", "10x7 p3"]),
                    SeedEntry(ex: "Cable Lateral Raise", sets: ["L 5x8 p3", "R 5x6 p3", "L 5x8 p3", "R 5x10 p2", "L 5x6+ p3", "R 5x7+ p3"]),
                    SeedEntry(ex: "Upright Row", sets: ["20x12+ p2", "25x8 p2", "25x-"]),
                    SeedEntry(ex: "Standing Calf Raise (D Stars)", sets: ["W 40x12+ # 40kg added, consider warmup"], note: "Added on the fly (text under the page)."),
                    SeedEntry(ex: "Smith Machine Calf Raise", sets: ["70x12+ # 70kg total", "70x13+"], note: "Added on the fly (text under the page)."),
                ]),
    SeedWorkout(date: "2026-10-15", name: "Biceps, Forearms, Abs", routine: "Biceps, Forearms, Abs",
                groups: ["A": .triset, "B": .superset],
                entries: [
                    SeedEntry(ex: "Standing Barbell Curl", sets: ["W 15x12+", "30x10", "30x7"]),
                    SeedEntry(ex: "Single-Arm Bayesian Curl", group: "A", sets: ["R 30x4 p2", "L 25x5 p2", "L 25x4 p1", "R 25x4 p1"]),
                    SeedEntry(ex: "Single-Arm Cable Curl", group: "A", sets: ["R 15x7 p1", "L 15x7 p1", "R 15x6 p1", "L 15x6 p1"]),
                    SeedEntry(ex: "Hammer Curl", group: "A", sets: ["25x7 p1", "25x6 p1"]),
                    SeedEntry(ex: "Cable Wrist Curl", group: "B", sets: ["L 30x10+", "R 30x12+", "R 30x11+", "L 30x12+"]),
                    SeedEntry(ex: "Reverse Cable Wrist Curl", group: "B", sets: ["35x6", "30x6"]),
                    SeedEntry(ex: "Standing Cable Crunch", sets: ["70x14+ p2", "75x11+"]),
                    SeedEntry(ex: "Kneeling Cable Crunch", sets: ["65x5+ p2", "65x6 p2"]),
                ]),
]

let SEED_ROUTINES: [SeedRoutine] = [
    SeedRoutine(name: "Shoulders", items: ["Dumbbell Shoulder Press", "Shoulder Lateral Machine Press", "Reverse Rear Delt Fly", "Rope Cable Front Raise", "Cable Lateral Raise", "Upright Row"].map { SeedRoutineItem(ex: $0) }),
    SeedRoutine(name: "Back and Abs", items: ["High-to-Low Pulldown Machine", "Lat Pulldown (Two-Arm)", "Chest-Supported Row", "Cable Pulldown (Extended)", "Cable Seated Row", "Cable Shrug", "Standing Cable Crunch", "Kneeling Cable Crunch"].map { SeedRoutineItem(ex: $0) }),
    SeedRoutine(name: "Triceps and Chest", items: ["Standing Cable Tricep Extension", "One-Arm Cuffed Tricep Extension", "Pec Deck", "Incline Chest Fly Machine", "Machine Dip"].map { SeedRoutineItem(ex: $0) }),
    SeedRoutine(name: "Biceps, Forearms, Abs",
                items: [
                    SeedRoutineItem(ex: "Standing Barbell Curl"),
                    SeedRoutineItem(ex: "Single-Arm Bayesian Curl", group: "A"), SeedRoutineItem(ex: "Single-Arm Cable Curl", group: "A"), SeedRoutineItem(ex: "Hammer Curl", group: "A"),
                    SeedRoutineItem(ex: "Cable Wrist Curl", group: "B"), SeedRoutineItem(ex: "Reverse Cable Wrist Curl", group: "B"),
                    SeedRoutineItem(ex: "Standing Cable Crunch"), SeedRoutineItem(ex: "Kneeling Cable Crunch"),
                ],
                groups: ["A": .triset, "B": .superset]),
]

/// The split Michael actually cycles through, in the order the routines were done.
let SEED_SPLIT_NAME = "Four-day cycle"
let SEED_SPLIT_ROUTINES = ["Shoulders", "Back and Abs", "Triceps and Chest", "Biceps, Forearms, Abs"]
