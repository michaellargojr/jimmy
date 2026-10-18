// General exercise library so search finds anything added on the fly.
// Format: "Muscle: Name|Name@equipment|..." (default equipment inferred from name; @ overrides)
const RAW = `
Back: Lat Pulldown@cable|Pull-Up@bodyweight|Chin-Up@bodyweight|Seated Cable Row@cable|Bent-Over Barbell Row@barbell|Dumbbell Row@dumbbell|T-Bar Row@machine|Chest-Supported Row@machine|Machine Row@machine|Straight-Arm Pulldown@cable|Face Pull@cable|Shrug@dumbbell|Cable Shrug@cable|Barbell Shrug@barbell|Deadlift@barbell|Rack Pull@barbell|Meadows Row@barbell|Inverted Row@bodyweight|Pendlay Row@barbell
Chest: Bench Press@barbell|Incline Bench Press@barbell|Dumbbell Bench Press@dumbbell|Incline Dumbbell Press@dumbbell|Chest Press Machine@machine|Pec Deck@machine|Cable Fly@cable|Low-to-High Cable Fly@cable|High-to-Low Cable Fly@cable|Dumbbell Fly@dumbbell|Push-Up@bodyweight|Dip@bodyweight|Machine Dip@machine|Smith Machine Bench Press@smith|Decline Press@machine
Shoulders: Shoulder Press@dumbbell|Overhead Press@barbell|Machine Shoulder Press@machine|Lateral Raise@dumbbell|Cable Lateral Raise@cable|Machine Lateral Raise@machine|Front Raise@dumbbell|Rope Cable Front Raise@cable|Rear Delt Fly@machine|Reverse Pec Deck@machine|Cable Rear Delt Fly@cable|Upright Row@ezbar|Arnold Press@dumbbell|Y Raise@dumbbell|Face Pull@cable
Triceps: Tricep Pushdown@cable|Rope Pushdown@cable|Overhead Tricep Extension@cable|Skull Crusher@ezbar|Close-Grip Bench Press@barbell|Dumbbell Kickback@dumbbell|Cable Kickback@cable|Tricep Dip@bodyweight|Machine Tricep Extension@machine|One-Arm Cable Extension@cable|JM Press@barbell
Biceps: Barbell Curl@barbell|EZ Bar Curl@ezbar|Dumbbell Curl@dumbbell|Hammer Curl@dumbbell|Cable Hammer Curl@cable|Cable Curl@cable|Bayesian Curl@cable|Preacher Curl@ezbar|Machine Preacher Curl@machine|Incline Dumbbell Curl@dumbbell|Spider Curl@dumbbell|Concentration Curl@dumbbell|Reverse Curl@ezbar|Drag Curl@barbell
Forearms: Wrist Curl@dumbbell|Cable Wrist Curl@cable|Reverse Wrist Curl@dumbbell|Reverse Cable Wrist Curl@cable|Behind-the-Back Wrist Curl@barbell|Farmer Carry@dumbbell|Plate Pinch@bodyweight|Dead Hang@bodyweight|Wrist Roller@machine
Abs: Cable Crunch@cable|Kneeling Cable Crunch@cable|Standing Cable Crunch@cable|Hanging Leg Raise@bodyweight|Captain's Chair Leg Raise@bodyweight|Ab Wheel Rollout@bodyweight|Machine Crunch@machine|Decline Sit-Up@bodyweight|Plank@bodyweight|Cable Woodchop@cable|Russian Twist@bodyweight|Reverse Crunch@bodyweight
Calves: Standing Calf Raise@machine|Seated Calf Raise@machine|Smith Machine Calf Raise@smith|Leg Press Calf Raise@machine|Donkey Calf Raise@machine|Single-Leg Calf Raise@bodyweight
Legs: Squat@barbell|Front Squat@barbell|Hack Squat@machine|Leg Press@machine|Leg Extension@machine|Leg Curl@machine|Seated Leg Curl@machine|Romanian Deadlift@barbell|Bulgarian Split Squat@dumbbell|Walking Lunge@dumbbell|Goblet Squat@dumbbell|Smith Machine Squat@smith|Sissy Squat@bodyweight|Nordic Curl@bodyweight|Adductor Machine@machine|Abductor Machine@machine
Glutes: Hip Thrust@barbell|Machine Hip Thrust@machine|Glute Bridge@bodyweight|Cable Kickback@cable|Glute Kickback Machine@machine|Step-Up@dumbbell|Sumo Deadlift@barbell|Good Morning@barbell
`

export interface LibraryEntry { name: string; muscle: string; equipment: string }

export const LIBRARY: LibraryEntry[] = RAW.trim().split('\n').flatMap(line => {
  const [muscle, rest] = line.split(':')
  return rest.split('|').map(tok => {
    const [name, eq] = tok.trim().split('@')
    return { name: name.trim(), muscle: muscle.trim(), equipment: eq ?? 'machine' }
  })
})
