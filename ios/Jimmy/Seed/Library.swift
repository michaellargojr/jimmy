import Foundation

// The exercise encyclopedia: 60 bases, from the list Michael approved on Oct 24, 2026.
// Columns: Name | Group | Also under | Primary regions | Secondary regions | Variations to offer | Aliases
// Variation grammar: "<family> [one|two] [position] [tag words] [(nick)]" (see VariationSpec).

struct LibraryBase {
    let name: String
    let group: MuscleGroup
    let also: [MuscleGroup]
    let primary: [String]
    let secondary: [String]
    let variations: [VariationSpec]
    let aliases: [String]

    var exercise: Exercise {
        Exercise(name: name, muscleGroup: group, aliases: aliases, alsoGroups: also, primary: primary, secondary: secondary)
    }
}

private let RAW = """
Chest Press|Chest||middle and lower chest|front delt, triceps|bar lying;dumbbell lying;machine|Bench Press, Chest Press Machine
Incline Press|Chest||upper chest|front delt, triceps|bar lying;dumbbell lying;machine|Incline Bench Press, Incline Dumbbell Press
Chest Fly|Chest||middle and lower chest|front delt|dumbbell lying;cable standing;cable one;machine|Pec Deck, Cable Fly, Dumbbell Fly
Incline Fly|Chest||upper chest|front delt|dumbbell lying;cable standing;machine|Low-to-High Cable Fly, Incline Dumbbell Fly
Push-Up|Chest||middle and lower chest|front delt, triceps, abs|body|Pushup
Dip|Chest|Triceps|middle and lower chest|triceps, front delt|body;machine|Machine Dip, Tricep Dip
Pullover|Chest|Back|middle and lower chest, lats|triceps|dumbbell lying;machine;cable|Dumbbell Pullover
Pulldown|Back||lats|biceps, upper back, rear delt|cable two;cable one;machine;machine high row|Lat Pulldown, High-to-Low Pulldown
Pull-Up|Back||lats|biceps, upper back|body;machine assisted|Chin-Up, Pullup
Straight-Arm Pulldown|Back||lats|triceps, rear delt|cable two;cable one|
Row|Back||lats, upper back|biceps, rear delt, lower back|cable seated;cable standing;cable one;machine chest-supported;machine T-bar;bar bent-over;dumbbell one;body inverted|Seated Cable Row, Chest-Supported Row, T-Bar Row, Bent-Over Row, Dumbbell Row, Inverted Row, Machine Row
Rear Delt Row|Back|Shoulders|rear delt, upper back|lats|cable;dumbbell chest-supported;machine|High Row
Face Pull|Shoulders|Back|rear delt|upper back|cable|
Shrug|Back||upper traps|forearms|dumbbell;cable;bar;machine|Cable Shrug, Barbell Shrug
Deadlift|Back|Legs|glutes, hamstrings, lower back|lats, upper traps, quads, forearms|bar;bar trap bar|Trap Bar Deadlift, Sumo Deadlift
Good Morning|Back||hamstrings, lower back|glutes|bar|
Back Extension|Back|Abs|lower back, glutes|hamstrings|body 45 degree;body horizontal;machine|Hyperextension
Shoulder Press|Shoulders||front delt|side delt, triceps, upper chest|dumbbell seated;dumbbell standing;bar seated;bar standing;machine|Overhead Press, Military Press, Arnold Press
Front Raise|Shoulders||front delt|upper chest|dumbbell two;dumbbell one;cable|
Lateral Raise|Shoulders||side delt|upper traps|dumbbell standing;dumbbell seated;cable one;machine|Side Raise
Upright Row|Shoulders||side delt, upper traps|front delt, biceps|bar;cable;dumbbell|
Rear Delt Fly|Shoulders||rear delt|upper back|machine;cable;dumbbell chest-supported;dumbbell bent-over|Reverse Pec Deck, Reverse Fly
Y Raise|Shoulders||upper back, rear delt|side delt|dumbbell chest-supported;cable|
External Rotation|Shoulders||rear delt|upper back|cable;dumbbell lying|
Curl|Biceps||biceps|forearms|bar standing;dumbbell standing;dumbbell seated;dumbbell arms-behind (incline);dumbbell arm-on-pad (preacher);bar arm-on-pad (preacher);machine arm-on-pad (preacher);dumbbell chest-supported (spider);dumbbell concentration;cable standing;cable one;cable arms-behind (Bayesian)|Bicep Curl, Barbell Curl, Dumbbell Curl, Preacher Curl, Spider Curl, Bayesian Curl, Incline Curl, Concentration Curl, Cable Curl, EZ Bar Curl
Hammer Curl|Biceps||biceps, forearms||dumbbell;cable|
Reverse Curl|Biceps|Forearms|forearms|biceps|bar;cable;dumbbell|
Tricep Extension|Triceps||triceps||cable overhead two;cable overhead one;dumbbell overhead;bar lying (skull crusher);dumbbell lying;machine|Overhead Tricep Extension, Skull Crusher, Overhead Extension
Tricep Pushdown|Triceps||triceps||cable two;cable one;machine|Pushdown, Rope Pushdown
Tricep Kickback|Triceps||triceps||dumbbell;cable|Kickback
Close-Grip Press|Triceps||triceps|middle and lower chest, front delt|bar lying|Close-Grip Bench Press
Wrist Curl|Forearms||forearms||dumbbell;cable;bar behind the back|
Reverse Wrist Curl|Forearms||forearms||dumbbell;cable;bar|
Farmer Carry|Forearms||forearms|upper traps, abs|dumbbell;bar trap bar|Farmer Walk
Dead Hang|Forearms||forearms|lats|body|
Plate Pinch|Forearms||forearms||body|
Wrist Roller|Forearms||forearms||machine|
Squat|Legs||quads, glutes|adductors, lower back, hamstrings|bar back;bar front;dumbbell goblet;machine hack;machine pendulum;body;body sissy|Back Squat, Front Squat, Goblet Squat, Hack Squat, Sissy Squat
Leg Press|Legs||quads, glutes|adductors|machine|
Split Squat|Legs||quads, glutes|adductors|dumbbell;bar;body|Bulgarian Split Squat
Lunge|Legs||quads, glutes|hamstrings|dumbbell walking;dumbbell static;bar;body|Walking Lunge
Step-Up|Glutes|Legs|glutes, quads|hamstrings|dumbbell;body|
Leg Extension|Legs||quads||machine|
Leg Curl|Legs||hamstrings|calves|machine seated;machine lying;machine one standing;body Nordic|Hamstring Curl, Nordic Curl
Romanian Deadlift|Legs||hamstrings, glutes|lower back, forearms|bar;dumbbell;dumbbell one|RDL, Stiff-Leg Deadlift
Hip Thrust|Glutes||glutes|hamstrings|bar;machine;body;body one|Glute Bridge
Glute Kickback|Glutes||glutes|hamstrings|cable;machine|Cable Kickback
Hip Abduction|Glutes||side glute||machine;cable|Abductor
Hip Adduction|Legs||adductors||machine;cable|Adductor
Calf Raise|Calves||calves||machine standing;machine seated;bar standing;machine leg press;machine donkey;body one|Standing Calf Raise, Seated Calf Raise, Smith Machine Calf Raise, Donkey Calf Raise
Tibialis Raise|Calves||shins||body;machine|Tib Raise
Crunch|Abs||abs|obliques|cable kneeling;cable standing;machine;body|Cable Crunch, Machine Crunch
Sit-Up|Abs||abs|quads|body|Situp
Leg Raise|Abs||abs|quads|body hanging;body captain's chair;body lying|Hanging Leg Raise, Knee Raise
Reverse Crunch|Abs||abs||body|
Ab Wheel Rollout|Abs||abs|lats, front delt|body|Ab Rollout
Plank|Abs||abs|front delt, glutes|body|
Side Plank|Abs||obliques|side glute|body|
Woodchop|Abs||obliques|front delt|cable|Cable Woodchop
Side Bend|Abs||obliques||dumbbell;cable|
"""

private func list(_ s: String) -> [String] {
    s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}

let LIBRARY: [LibraryBase] = RAW.split(separator: "\n").compactMap { line -> LibraryBase? in
    let c = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    guard c.count >= 6, let group = MuscleGroup(rawValue: c[1]) else { return nil }
    let also = list(c[2]).compactMap { MuscleGroup(rawValue: $0) }
    let variations = c[5].split(separator: ";").compactMap { VariationSpec(String($0)) }
    return LibraryBase(name: c[0], group: group, also: also, primary: list(c[3]), secondary: list(c[4]),
                       variations: variations, aliases: c.count > 6 ? list(c[6]) : [])
}

func libraryBase(named name: String) -> LibraryBase? {
    LIBRARY.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
}

/// Variation overrides of the muscle map, from the encyclopedia.
func regionOverrides(base: String, variation v: Version) -> (primary: [String], secondary: [String])? {
    switch base {
    case "Calf Raise" where v.position == .seated: return (["calves"], [])
    case "Pulldown" where v.tag?.lowercased() == "high row": return (["lats"], ["biceps", "upper back", "rear delt"])
    default: return nil
    }
}
