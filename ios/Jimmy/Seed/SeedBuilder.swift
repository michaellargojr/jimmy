import Foundation

struct SeedResult {
    var gyms: [Gym]; var exercises: [Exercise]; var versions: [Version]; var styles: [Style]
    var workouts: [Workout]; var routines: [Routine]; var splits: [Split]
}

func buildSeed() -> SeedResult {
    let gyms = SEED_GYMS.map { Gym(id: uid(), name: $0) }
    let gymByName = Dictionary(uniqueKeysWithValues: gyms.map { ($0.name, $0.id) })

    // Every encyclopedia base exists from day one, so search and browsing find it.
    var exercises: [Exercise] = LIBRARY.map { $0.exercise }
    func base(named name: String, group: MuscleGroup) -> Exercise {
        if let e = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return e }
        let e = Exercise(name: name, muscleGroup: group, custom: true)
        exercises.append(e)
        return e
    }

    var versions: [Version] = []
    var styles: [Style] = []
    var pick: [String: (version: String, style: String?)] = [:]   // logged name -> ids
    for s in SEED_EXERCISES {
        let b = base(named: s.base, group: s.group)
        let v: Version
        if let i = versions.firstIndex(where: { $0.exerciseId == b.id && $0.key == s.variation.key }) {
            if let n = s.notes, !(versions[i].notes ?? "").contains(n) {
                versions[i].notes = [versions[i].notes, n].compactMap { $0 }.joined(separator: " ")
            }
            v = versions[i]
        } else {
            v = Version(exerciseId: b.id, name: b.name + " · " + variationLabel(s.variation, legs: b.isLegs),
                        equipment: s.variation.family.equipment, arms: s.variation.arms, position: s.variation.position,
                        tag: s.variation.tag, repMin: s.repMin, repMax: s.repMax, defaultWarmup: true, defaultSets: 2, notes: s.notes)
            versions.append(v)
        }
        var styleId: String?
        if !s.style.isEmpty {
            if let st = styles.first(where: { $0.versionId == v.id && $0.key == s.style.key }) { styleId = st.id }
            else { let st = s.style.style(for: v.id); styles.append(st); styleId = st.id }
        }
        pick[s.name] = (v.id, styleId)
    }

    let routines: [Routine] = SEED_ROUTINES.map { r in
        var groups: [ExerciseGroup] = []
        var gid: [String: String] = [:]
        for (k, type) in r.groups.sorted(by: { $0.key < $1.key }) { let id = uid(); gid[k] = id; groups.append(ExerciseGroup(id: id, type: type)) }
        let items = r.items.compactMap { i -> RoutineItem? in
            guard let p = pick[i.ex] else { return nil }
            return RoutineItem(versionId: p.version, styleId: p.style, groupId: i.group.flatMap { gid[$0] })
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
            guard let p = pick[e.ex] else { return nil }
            return WorkoutItem(versionId: p.version, styleId: p.style, groupId: e.group.flatMap { gid[$0] }, sets: e.sets.map { parseSetLine($0) }, note: e.note)
        }
        return Workout(name: w.name, date: w.date, gymId: w.gym.flatMap { gymByName[$0] }, routineId: w.routine.flatMap { routineByName[$0] },
                       startedAt: started, endedAt: started + 60 * 60 * 1000, notes: w.notes, items: items, groups: groups)
    }

    let split = Split(name: SEED_SPLIT_NAME, routineIds: SEED_SPLIT_ROUTINES.compactMap { routineByName[$0] })
    return SeedResult(gyms: gyms, exercises: exercises, versions: versions, styles: styles, workouts: workouts, routines: routines, splits: [split])
}
