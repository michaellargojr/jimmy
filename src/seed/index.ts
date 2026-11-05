/**
 * Turns the hand-written Notion export (./notion.ts) and the general library
 * (./library.ts) into store records. Runs once on a fresh install (store.load)
 * and is dynamically imported there so it never ships in the main bundle.
 *
 * Any exercise name referenced by a routine or workout entry must exist in
 * EXERCISES, otherwise buildSeed throws with the offending name. src/seed/seed.test.ts
 * runs buildSeed so a typo fails CI instead of blanking the app on first launch.
 */
import type { Arms, Equipment, Exercise, Group, GroupType, Gym, MuscleGroup, Routine, Version, Workout } from '../model'
import { uid } from '../model'
import { EXERCISES, GYMS, ROUTINES, WORKOUTS } from './notion'
import { LIBRARY } from './library'
import { parseSetLine } from './parse'

export interface SeedResult { gyms: Gym[]; exercises: Exercise[]; versions: Version[]; workouts: Workout[]; routines: Routine[] }

function groupsFrom(spec: Record<string, GroupType> | undefined): { groups: Group[]; gid: Record<string, string> } {
  const groups: Group[] = []
  const gid: Record<string, string> = {}
  for (const [k, type] of Object.entries(spec ?? {})) { const id = uid(); gid[k] = id; groups.push({ id, type }) }
  return { groups, gid }
}

export function buildSeed(): SeedResult {
  const gyms: Gym[] = GYMS.map(name => ({ id: uid(), name }))
  const gymByName = new Map(gyms.map(g => [g.name, g.id]))

  const exercises: Exercise[] = []
  const exByName = new Map<string, Exercise>()
  const ensureExercise = (name: string, muscle: string, aliases: string[] = []): Exercise => {
    let e = exByName.get(name)
    if (!e) {
      e = { id: uid(), name, muscleGroup: muscle as MuscleGroup, aliases }
      exercises.push(e); exByName.set(name, e)
    }
    return e
  }

  const versions: Version[] = []
  const verByName = new Map<string, Version>()
  for (const s of EXERCISES) {
    const base = ensureExercise(s.base ?? s.name, s.muscle, s.aliases ?? [])
    const v: Version = {
      id: uid(), exerciseId: base.id, name: s.name, equipment: s.equipment as Equipment, arms: s.arms as Arms,
      machine: s.machine, repMin: s.repMin ?? 5, repMax: s.repMax ?? 8, defaultWarmup: true, defaultSets: 2,
      notes: s.notes, gymNotes: {}, media: [], changes: [],
    }
    versions.push(v); verByName.set(v.name, v)
  }
  const version = (name: string, where: string): Version => {
    const v = verByName.get(name)
    if (!v) throw new Error(`seed: "${name}" (${where}) is not in EXERCISES`)
    return v
  }
  // Library base exercises (no versions until used)
  for (const l of LIBRARY) ensureExercise(l.name, l.muscle)

  const routines: Routine[] = ROUTINES.map(r => {
    const { groups, gid } = groupsFrom(r.groups)
    return {
      id: uid(), name: r.name, groups,
      items: r.items.map(i => ({ id: uid(), versionId: version(i.ex, `routine ${r.name}`).id, groupId: i.group ? gid[i.group] : undefined })),
    }
  })
  const routineByName = new Map(routines.map(r => [r.name, r.id]))

  const workouts: Workout[] = WORKOUTS.map(w => {
    const { groups, gid } = groupsFrom(w.groups)
    const started = new Date(w.date + 'T09:00:00').getTime()
    return {
      id: uid(), name: w.name, date: w.date, gymId: w.gym ? gymByName.get(w.gym) : undefined,
      routineId: w.routine ? routineByName.get(w.routine) : undefined,
      startedAt: started, endedAt: started + 60 * 60 * 1000, notes: w.notes, groups,
      items: w.entries.map(e => ({
        id: uid(), versionId: version(e.ex, `workout ${w.date}`).id, groupId: e.group ? gid[e.group] : undefined,
        sets: e.sets.map(l => parseSetLine(l)), note: e.note,
      })),
    }
  })

  return { gyms, exercises, versions, workouts, routines }
}
