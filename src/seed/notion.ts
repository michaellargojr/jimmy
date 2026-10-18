// One-time import of Michael's Notion workout history (Aug 3 to Oct 15, 2026).
// Compact set grammar per line:  [W] [L|R] [EZ] <weight|-> x <reps|->[+] [pN] [# note]
// W = warm-up. "-" = not recorded. "+" = at least this many. pN = N partials.

export interface SeedExercise {
  name: string; muscle: string; equipment: string; arms: 'one' | 'two'
  base?: string; aliases?: string[]; notes?: string; repMin?: number; repMax?: number; machine?: string
}
export interface SeedEntry { ex: string; group?: string; sets: string[]; note?: string }
export interface SeedWorkout { date: string; name: string; routine?: string; gym?: string; notes?: string; groups?: Record<string, 'superset' | 'triset' | 'circuit'>; entries: SeedEntry[] }
export interface SeedRoutine { name: string; items: { ex: string; group?: string }[]; groups?: Record<string, 'superset' | 'triset' | 'circuit'> }

export const GYMS = ['Ultradynamic Fitness - Catalunan Grande', 'Ultradynamic Fitness - Bangkal']

const HI = { repMin: 10, repMax: 15 }

export const EXERCISES: SeedExercise[] = [
  // Abs
  { name: 'Kneeling Cable Crunch', muscle: 'Abs', equipment: 'cable', arms: 'two', ...HI },
  { name: 'Standing Cable Crunch', muscle: 'Abs', equipment: 'cable', arms: 'two', ...HI },
  // Back
  { name: 'Cable Pulldown (Extended)', muscle: 'Back', equipment: 'cable', arms: 'one', notes: 'Added mid-workout Sep 21. Rename if the machine name is different.' },
  { name: 'Cable Seated Row', muscle: 'Back', equipment: 'cable', arms: 'two' },
  { name: 'Cable Shrug', muscle: 'Back', equipment: 'cable', arms: 'two', base: 'Shrug', ...HI },
  { name: 'Chest-Supported Row', muscle: 'Back', equipment: 'machine', arms: 'two' },
  { name: 'Face Pull', muscle: 'Back', equipment: 'cable', arms: 'two' },
  { name: 'High-to-Low Pulldown Machine', muscle: 'Back', equipment: 'machine', arms: 'two', notes: 'Double or single arm. Sep 21: left shoulder pain on eccentric, consider abandoning.' },
  { name: 'Lat Pulldown (Two-Arm)', muscle: 'Back', equipment: 'cable', arms: 'two', base: 'Lat Pulldown' },
  { name: 'One-Arm Lat Pulldown', muscle: 'Back', equipment: 'cable', arms: 'one', base: 'Lat Pulldown' },
  { name: 'Seated Unilateral Cable Row', muscle: 'Back', equipment: 'cable', arms: 'one', aliases: ['Seated extended unilateral cable rows'] },
  { name: 'Standing Cable Row', muscle: 'Back', equipment: 'cable', arms: 'two' },
  // Biceps
  { name: 'Hammer Curl', muscle: 'Biceps', equipment: 'cable', arms: 'two', notes: 'Part of the bicep triset.' },
  { name: 'Incline Dumbbell Curl', muscle: 'Biceps', equipment: 'dumbbell', arms: 'two' },
  { name: 'Single-Arm Bayesian Curl', muscle: 'Biceps', equipment: 'cable', arms: 'one', notes: 'Part of the bicep triset.' },
  { name: 'Single-Arm Cable Curl', muscle: 'Biceps', equipment: 'cable', arms: 'one', aliases: ['Single arm curls'], notes: 'Part of the bicep triset.' },
  { name: 'Spider Curl', muscle: 'Biceps', equipment: 'dumbbell', arms: 'two' },
  { name: 'Standing Barbell Curl', muscle: 'Biceps', equipment: 'barbell', arms: 'two', base: 'Barbell Curl' },
  // Calves
  { name: 'Standing Calf Raise Machine', muscle: 'Calves', equipment: 'machine', arms: 'two', base: 'Standing Calf Raise', ...HI },
  { name: 'Standing Calf Raise (D Stars)', muscle: 'Calves', equipment: 'machine', arms: 'two', base: 'Standing Calf Raise', machine: 'D Stars', notes: 'Weight is plates added.', ...HI },
  { name: 'Smith Machine Calf Raise', muscle: 'Calves', equipment: 'smith', arms: 'two', notes: 'Weight is total on the bar.', ...HI },
  // Chest
  { name: 'Chest Fly', muscle: 'Chest', equipment: 'machine', arms: 'one', notes: 'Aug 7 tracked left/right separately.' },
  { name: 'Incline Chest Fly Machine', muscle: 'Chest', equipment: 'machine', arms: 'two', notes: 'Weight recorded as each side.' },
  { name: 'Low-to-High Chest Fly', muscle: 'Chest', equipment: 'cable', arms: 'one' },
  { name: 'Machine Dip', muscle: 'Chest', equipment: 'machine', arms: 'two' },
  { name: 'Pec Deck', muscle: 'Chest', equipment: 'machine', arms: 'two' },
  { name: 'Incline Bench Press', muscle: 'Chest', equipment: 'barbell', arms: 'two', base: 'Bench Press' },
  // Forearms
  { name: 'Cable Wrist Curl', muscle: 'Forearms', equipment: 'cable', arms: 'one', aliases: ['Single cable wrist curl'], ...HI },
  { name: 'Reverse Cable Wrist Curl', muscle: 'Forearms', equipment: 'cable', arms: 'two', ...HI },
  // Shoulders
  { name: 'Cable Lateral Raise', muscle: 'Shoulders', equipment: 'cable', arms: 'one', aliases: ['Side cable lateral raise'] },
  { name: 'Dumbbell Shoulder Press', muscle: 'Shoulders', equipment: 'dumbbell', arms: 'two', base: 'Shoulder Press' },
  { name: 'Front Raise', muscle: 'Shoulders', equipment: 'dumbbell', arms: 'one' },
  { name: 'Lateral Raise', muscle: 'Shoulders', equipment: 'dumbbell', arms: 'two' },
  { name: 'Reverse Rear Delt Fly', muscle: 'Shoulders', equipment: 'machine', arms: 'two' },
  { name: 'Rope Cable Front Raise', muscle: 'Shoulders', equipment: 'cable', arms: 'two' },
  { name: 'Shoulder Lateral Machine Press', muscle: 'Shoulders', equipment: 'machine', arms: 'two', base: 'Shoulder Press' },
  { name: 'Upright Row', muscle: 'Shoulders', equipment: 'ezbar', arms: 'two' },
  // Triceps
  { name: 'One-Arm Cuffed Tricep Extension', muscle: 'Triceps', equipment: 'cable', arms: 'one' },
  { name: 'Standing Cable Tricep Extension', muscle: 'Triceps', equipment: 'cable', arms: 'two' },
  { name: 'Tricep Pushdown', muscle: 'Triceps', equipment: 'cable', arms: 'one', aliases: ['Tricep pull downs'] },
]

const G = GYMS

export const WORKOUTS: SeedWorkout[] = [
  {
    date: '2026-08-03', name: 'Biceps', routine: 'Biceps, Forearms, Abs',
    notes: 'From Apple Note "Gym". Units were not written; assumed kg.',
    groups: { A: 'triset' },
    entries: [
      { ex: 'Single-Arm Bayesian Curl', group: 'A', sets: ['14x15+', '18x6', '14x6'] },
      { ex: 'Single-Arm Cable Curl', group: 'A', sets: ['14x12+', '14x7', '14x6'] },
      { ex: 'Hammer Curl', group: 'A', sets: ['27x8', '27x5', '23x6'] },
    ],
  },
  {
    date: '2026-08-07', name: 'Triceps, Chest, Shoulders',
    notes: 'First exercise in the note had no name (25kg warm-up x15, 55kg x16, 60kg x8), not imported.',
    entries: [
      { ex: 'Tricep Pushdown', sets: ['45x14', 'L 50x8', 'R 50x10', 'L 50x6', 'R 50x8'] },
      { ex: 'Chest Fly', sets: ['W 10x-', '20x10', 'L 20x10', 'R 20x13 # right stronger'] },
      { ex: 'Low-to-High Chest Fly', sets: ['W 10x10', 'R 20x9', 'L 20x8', 'L 20x8', 'R 20x8'] },
      { ex: 'Lateral Raise', sets: ['15x5 # right bad form', '15x8 # drop set to 10kg'] },
      { ex: 'Front Raise', sets: ['R 10x11 # right stronger', 'L 10x9', '10x-'] },
    ],
  },
  {
    date: '2026-08-20', name: 'Back and Abs', routine: 'Back and Abs',
    entries: [
      { ex: 'Face Pull', sets: ['W 25x-', '40x11', '40x-'] },
      { ex: 'Standing Cable Row', sets: ['60x12+', '65x11', '65x10'] },
      { ex: 'One-Arm Lat Pulldown', sets: ['R 40x10', 'L 40x13 # L stronger', '40x7', '40x8'] },
      { ex: 'Seated Unilateral Cable Row', sets: ['R 30x15 # R stronger', 'L 30x12', 'L 35x12', 'R 35x10'] },
      { ex: 'Cable Shrug', sets: ['65x17+', '70x15'] },
      { ex: 'Standing Cable Crunch', sets: ['70x10', '70x9'] },
      { ex: 'Kneeling Cable Crunch', sets: ['65x7'] },
    ],
  },
  {
    date: '2026-08-29', name: 'Triceps and Chest', routine: 'Triceps and Chest',
    entries: [
      { ex: 'Standing Cable Tricep Extension', sets: ['W -x-', '60x12+', '65x9 # wrists hurt, heavy'] },
      { ex: 'One-Arm Cuffed Tricep Extension', sets: ['50x12+', '50x10+'] },
      { ex: 'Pec Deck', sets: ['W 35x-', '50x8+', '50x-'] },
      { ex: 'Incline Chest Fly Machine', sets: ['5x8 # 5kg each side', '5x5'] },
      { ex: 'Machine Dip', sets: ['W 30x-', '50x10+', '50x7', '50x6'] },
    ],
  },
  {
    date: '2026-09-09', name: 'Shoulders', routine: 'Shoulders',
    entries: [
      { ex: 'Dumbbell Shoulder Press', sets: ['W 12.5x11+', '15x10', '15x8'] },
      { ex: 'Shoulder Lateral Machine Press', sets: ['W 15x10+', '30x8+', '30x6+'] },
      { ex: 'Reverse Rear Delt Fly', sets: ['30x7 # was tired off previous exercise', '30x12+'] },
      { ex: 'Rope Cable Front Raise', sets: ['W 10x13+', '15x4', '10x7'] },
      { ex: 'Cable Lateral Raise', sets: ['5x10+', '5x8+'] },
      { ex: 'Upright Row', sets: ['EZ 15x12+', '20x10+', '20x-'] },
    ],
  },
  {
    date: '2026-09-14', name: 'Biceps, Forearms, Calves', routine: 'Biceps, Forearms, Abs',
    groups: { A: 'triset', B: 'superset' },
    entries: [
      { ex: 'Single-Arm Bayesian Curl', group: 'A', sets: ['30x13', '30x5'] },
      { ex: 'Single-Arm Cable Curl', group: 'A', sets: ['20x6', '15x5'] },
      { ex: 'Hammer Curl', group: 'A', sets: ['30x6', '30x4'] },
      { ex: 'Incline Dumbbell Curl', sets: ['10x10+', '10x7'] },
      { ex: 'Spider Curl', sets: ['10x5', '7.5x10+'] },
      { ex: 'Cable Wrist Curl', group: 'B', sets: ['30x12+', '30x11+'] },
      { ex: 'Reverse Cable Wrist Curl', group: 'B', sets: ['35x10+', '35x-'] },
      { ex: 'Standing Calf Raise Machine', sets: ['80x20+', '100x-', '80x-'] },
    ],
  },
  {
    date: '2026-09-21', name: 'Back and Abs', routine: 'Back and Abs', gym: G[0],
    entries: [
      { ex: 'High-to-Low Pulldown Machine', sets: ['R 25x10+ p2 # underhand grip', 'L 25x7+ p1 # shoulder discomfort, arm twisting', '15x7+ # overhand grip, left shoulder pain on eccentric, probably abandon'] },
      { ex: 'Lat Pulldown (Two-Arm)', sets: ['50x9 p3 # good mind-muscle connection', '50x7 p5'] },
      { ex: 'Chest-Supported Row', sets: ['15x9 p2 # stopped partway, switched to unilateral', 'R 15x8 p2 # side grip', 'L 15x-'] },
      { ex: 'Cable Pulldown (Extended)', sets: ['W L 30x15+ p5', 'W R 30x10+ p5', 'L 40x12 p3', 'R 40x9 p2', 'R 40x6', 'L 40x10'] },
      { ex: 'Cable Seated Row', sets: ['55x6+', '50x7+ p2', '40x12 p2'] },
      { ex: 'Cable Shrug', sets: ['70x10+ p2', '70x9 p3', '70x9 p10'] },
      { ex: 'Standing Cable Crunch', sets: [] },
      { ex: 'Kneeling Cable Crunch', sets: [] },
    ],
  },
  {
    date: '2026-10-01', name: 'Triceps and Chest', routine: 'Triceps and Chest', gym: G[0],
    entries: [
      { ex: 'Standing Cable Tricep Extension', sets: ['W -x-', '65x11', '65x7'] },
      { ex: 'One-Arm Cuffed Tricep Extension', sets: ['R 50x6 p2', 'L 50x10 p2', 'R 50x8 p2', 'L 50x9 p2', 'R 50x5 p1', 'L 50x6 p1'] },
      { ex: 'Pec Deck', sets: ['50x12+ p2'] },
      { ex: 'Incline Chest Fly Machine', sets: ['W 0x-', '10x4 p3', '5x7+ p3'] },
      { ex: 'Machine Dip', sets: ['W 30x-', '50x7 p2', '50x7 p2'] },
      { ex: 'Incline Bench Press', sets: ['60x5 p1 # no warmup', '50x8'], note: 'Added on the fly (was a text note under the page).' },
    ],
  },
  {
    date: '2026-10-10', name: 'Shoulders', routine: 'Shoulders', gym: G[1],
    entries: [
      { ex: 'Dumbbell Shoulder Press', sets: ['W 7.5x12', '15x15', '17.5x8 p1'] },
      { ex: 'Shoulder Lateral Machine Press', sets: ['W 15x12+', '30x6 p5', '30x7+ p4'] },
      { ex: 'Reverse Rear Delt Fly', sets: ['W 20x13+', '35x9 p1', '35x10+'] },
      { ex: 'Rope Cable Front Raise', sets: ['10x12 p3', '10x7 p4', '10x7 p3'] },
      { ex: 'Cable Lateral Raise', sets: ['L 5x8 p3', 'R 5x6 p3', 'L 5x8 p3', 'R 5x10 p2', 'L 5x6+ p3', 'R 5x7+ p3'] },
      { ex: 'Upright Row', sets: ['20x12+ p2', '25x8 p2', '25x-'] },
      { ex: 'Standing Calf Raise (D Stars)', sets: ['W 40x12+ # 40kg added, consider warmup'], note: 'Added on the fly (text under the page).' },
      { ex: 'Smith Machine Calf Raise', sets: ['70x12+ # 70kg total', '70x13+'], note: 'Added on the fly (text under the page).' },
    ],
  },
  {
    date: '2026-10-15', name: 'Biceps, Forearms, Abs', routine: 'Biceps, Forearms, Abs',
    groups: { A: 'triset', B: 'superset' },
    entries: [
      { ex: 'Standing Barbell Curl', sets: ['W 15x12+', '30x10', '30x7'] },
      { ex: 'Single-Arm Bayesian Curl', group: 'A', sets: ['R 30x4 p2', 'L 25x5 p2', 'L 25x4 p1', 'R 25x4 p1'] },
      { ex: 'Single-Arm Cable Curl', group: 'A', sets: ['R 15x7 p1', 'L 15x7 p1', 'R 15x6 p1', 'L 15x6 p1'] },
      { ex: 'Hammer Curl', group: 'A', sets: ['25x7 p1', '25x6 p1'] },
      { ex: 'Cable Wrist Curl', group: 'B', sets: ['L 30x10+', 'R 30x12+', 'R 30x11+', 'L 30x12+'] },
      { ex: 'Reverse Cable Wrist Curl', group: 'B', sets: ['35x6', '30x6'] },
      { ex: 'Standing Cable Crunch', sets: ['70x14+ p2', '75x11+'] },
      { ex: 'Kneeling Cable Crunch', sets: ['65x5+ p2', '65x6 p2'] },
    ],
  },
]

export const ROUTINES: SeedRoutine[] = [
  {
    name: 'Shoulders',
    items: ['Dumbbell Shoulder Press', 'Shoulder Lateral Machine Press', 'Reverse Rear Delt Fly', 'Rope Cable Front Raise', 'Cable Lateral Raise', 'Upright Row'].map(ex => ({ ex })),
  },
  {
    name: 'Back and Abs',
    items: ['High-to-Low Pulldown Machine', 'Lat Pulldown (Two-Arm)', 'Chest-Supported Row', 'Cable Pulldown (Extended)', 'Cable Seated Row', 'Cable Shrug', 'Standing Cable Crunch', 'Kneeling Cable Crunch'].map(ex => ({ ex })),
  },
  {
    name: 'Triceps and Chest',
    items: ['Standing Cable Tricep Extension', 'One-Arm Cuffed Tricep Extension', 'Pec Deck', 'Incline Chest Fly Machine', 'Machine Dip'].map(ex => ({ ex })),
  },
  {
    name: 'Biceps, Forearms, Abs',
    groups: { A: 'triset', B: 'superset' },
    items: [
      { ex: 'Standing Barbell Curl' },
      { ex: 'Single-Arm Bayesian Curl', group: 'A' }, { ex: 'Single-Arm Cable Curl', group: 'A' }, { ex: 'Hammer Curl', group: 'A' },
      { ex: 'Cable Wrist Curl', group: 'B' }, { ex: 'Reverse Cable Wrist Curl', group: 'B' },
      { ex: 'Standing Cable Crunch' }, { ex: 'Kneeling Cable Crunch' },
    ],
  },
]
