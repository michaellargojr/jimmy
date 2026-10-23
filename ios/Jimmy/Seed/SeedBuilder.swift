import Foundation

struct SeedResult {
    var gyms: [Gym]; var exercises: [Exercise]; var versions: [Version]
    var workouts: [Workout]; var routines: [Routine]; var splits: [Split]
}

func buildSeed() -> SeedResult {
    let gyms = SEED_GYMS.map { Gym(id: uid(), name: $0) }
    let gymByName = Dictionary(uniqueKeysWithValues: gyms.map { ($0.name, $0.id) })

    var exercises: [Exercise] = []
    var exByName: [String: Exercise] = [:]
    func ensureExercise(_ name: String, _ muscle: MuscleGroup, _ aliases: [String] = []) -> Exercise {
        if let e = exByName[name] { return e }
        let e = Exercise(name: name, muscleGroup: muscle, aliases: aliases)
        exercises.append(e); exByName[name] = e
        return e
    }

    var versions: [Version] = []
    var verByName: [String: Version] = [:]
    for s in SEED_EXERCISES {
        let base = ensureExercise(s.base ?? s.name, s.muscle, s.aliases)
        let v = Version(exerciseId: base.id, name: s.name, equipment: s.equipment, arms: s.arms, machine: s.machine,
                        repMin: s.repMin, repMax: s.repMax, defaultWarmup: true, defaultSets: 2, notes: s.notes)
        versions.append(v); verByName[v.name] = v
    }
    for l in LIBRARY { _ = ensureExercise(l.name, l.muscle) }

    let routines: [Routine] = SEED_ROUTINES.map { r in
        var groups: [ExerciseGroup] = []
        var gid: [String: String] = [:]
        for (k, type) in r.groups.sorted(by: { $0.key < $1.key }) { let id = uid(); gid[k] = id; groups.append(ExerciseGroup(id: id, type: type)) }
        let items = r.items.compactMap { i -> RoutineItem? in
            guard let v = verByName[i.ex] else { return nil }
            return RoutineItem(versionId: v.id, groupId: i.group.flatMap { gid[$0] })
        }
        return Routine(name: r.name, items: items, groups: groups)
    }
    let routineByName = Dictionary(uniqueKeysWithValues: routines.map { ($0.name, $0.id) })

    let workouts: [Workout] = SEED_WORKOUTS.map { w in
        var groups: [ExerciseGroup] = []
        var gid: [String: String] = [:]
        for (k, type) in w.groups.sorted(by: { $0.key < $1.key }) { let id = uid(); gid[k] = id; groups.append(ExerciseGroup(id: id, type: type)) }
        let started = dayDate(w.date).addingTimeInterval(9 * 3600).timeIntervalSince1970 * 1000
        let items = w.entries.compactMap { e -> WorkoutItem? in
            guard let v = verByName[e.ex] else { return nil }
            return WorkoutItem(versionId: v.id, groupId: e.group.flatMap { gid[$0] }, sets: e.sets.map { parseSetLine($0) }, note: e.note)
        }
        return Workout(name: w.name, date: w.date, gymId: w.gym.flatMap { gymByName[$0] }, routineId: w.routine.flatMap { routineByName[$0] },
                       startedAt: started, endedAt: started + 60 * 60 * 1000, notes: w.notes, items: items, groups: groups)
    }

    let split = Split(name: SEED_SPLIT_NAME, routineIds: SEED_SPLIT_ROUTINES.compactMap { routineByName[$0] })
    return SeedResult(gyms: gyms, exercises: exercises, versions: versions, workouts: workouts, routines: routines, splits: [split])
}
