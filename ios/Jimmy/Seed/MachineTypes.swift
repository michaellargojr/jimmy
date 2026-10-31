import Foundation

// The machine list: the kinds of machine each exercise is done on. Each kind needs its own
// weights, so the first time you pick one it becomes a variation with its own history. Two
// machines of one kind (say, at two gyms) are told apart by a name ("D Stars").
// Line grammar: Base|Name=variation;Name=variation, the variation in VariationSpec grammar
// without arms, and "/plates" when the kind usually takes plates (else a weight stack). The plain
// machine (no tag) is the kind most gyms have. How a kind is loaded is a guess you can switch.
// "@seated,lying" lists the positions the kind is used in, so picking a position drops the kinds
// that never come that way. A kind that fixes its position is used only in that one.

/// One kind of machine for a base: "Iso-lateral pulldown" is a machine variation tagged "iso-lateral".
struct MachineType: Hashable, Identifiable {
    let name: String
    /// The variation's tag, nil for the plain machine.
    let tag: String?
    /// Set when the kind fixes the position (a seated calf raise).
    let position: Position?
    /// How this kind usually comes: the app's pick, which you can switch.
    let loading: Loading
    /// The positions it's used in. Empty: any.
    let positions: Set<Position>
    var id: String { name }

    /// It comes in this position (any kind does when no position is picked).
    func allows(_ p: Position?) -> Bool {
        guard let p else { return true }
        if let position { return position == p }
        return positions.isEmpty || positions.contains(p)
    }

    /// A variation's tag and position fit this kind.
    func fits(tag t: String?, position p: Position?) -> Bool {
        (t ?? "").lowercased() == (tag ?? "").lowercased() && (position == nil || position == p)
    }
    func fits(_ v: Version) -> Bool { v.family == .machine && fits(tag: v.tag, position: v.position) }
}

private let RAW_MACHINES = """
Chest Press|Chest press=machine@seated,lying;Iso-lateral chest press=machine iso-lateral/plates@seated,lying;Converging chest press=machine converging@seated;Wide chest press=machine wide/plates@seated,lying
Incline Press|Incline chest press=machine@seated;Iso-lateral incline press=machine iso-lateral/plates@seated
Chest Fly|Fly machine=machine@seated;Pec deck=machine pec deck@seated
Incline Fly|Incline fly machine=machine@seated
Dip|Seated dip=machine@seated;Assisted dip=machine assisted@kneeling,standing
Pullover|Pullover machine=machine@seated
Pulldown|Lat pulldown=machine@seated;Iso-lateral pulldown=machine iso-lateral/plates@seated,chest-supported;High row=machine high row/plates@seated,chest-supported;Wide pulldown=machine wide/plates@seated
Pull-Up|Assisted pull-up=machine assisted@kneeling,standing
Row|Seated row=machine chest-supported;Iso-lateral row=machine iso-lateral/plates@seated,chest-supported;T-bar row=machine T-bar/plates@chest-supported,standing;Low row=machine low row/plates@seated
Rear Delt Row|Rear delt row machine=machine@seated,chest-supported
Shrug|Shrug machine=machine/plates@standing,seated
Back Extension|Back extension machine=machine@seated
Shoulder Press|Shoulder press=machine@seated;Iso-lateral shoulder press=machine iso-lateral/plates@seated;Converging shoulder press=machine converging@seated
Lateral Raise|Lateral raise machine=machine@seated;Standing lateral raise machine=machine standing
Rear Delt Fly|Reverse pec deck=machine@seated,chest-supported
Curl|Preacher curl machine=machine arm-on-pad;Iso-lateral curl=machine iso-lateral/plates@arm-on-pad,seated
Tricep Extension|Tricep extension machine=machine@seated,arm-on-pad;Overhead tricep machine=machine overhead@seated
Tricep Pushdown|Tricep press machine=machine@seated
Wrist Roller|Wrist roller=machine@standing,seated
Squat|Hack squat=machine hack/plates@standing;Pendulum squat=machine pendulum/plates@standing;Belt squat=machine belt/plates@standing;V-squat=machine V-squat/plates@standing
Leg Press|45° leg press=machine/plates@seated,lying;Seated leg press=machine seated;Vertical leg press=machine vertical/plates@lying;Iso-lateral leg press=machine iso-lateral/plates@seated,lying
Leg Extension|Leg extension=machine@seated;Iso-lateral leg extension=machine iso-lateral/plates@seated
Leg Curl|Seated leg curl=machine seated;Lying leg curl=machine lying;Standing leg curl=machine standing;Kneeling leg curl=machine kneeling
Hip Thrust|Hip thrust machine=machine/plates@seated,lying
Glute Kickback|Kickback machine=machine@standing,kneeling
Hip Abduction|Abductor machine=machine@seated,standing
Hip Adduction|Adductor machine=machine@seated,standing
Calf Raise|Standing calf raise=machine standing;Seated calf raise=machine seated/plates;Donkey calf raise=machine donkey/plates@standing;Leg press calf raise=machine leg press/plates@seated,lying
Tibialis Raise|Tib raise machine=machine/plates@seated,standing
Crunch|Ab crunch machine=machine@seated,kneeling
"""

private let MACHINE_TYPES: [String: [MachineType]] = {
    var out: [String: [MachineType]] = [:]
    for line in RAW_MACHINES.split(separator: "\n") {
        let c = line.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard c.count == 2 else { continue }
        out[c[0].lowercased()] = c[1].split(separator: ";").compactMap { entry -> MachineType? in
            let kv = entry.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2 else { return nil }
            let at = kv[1].split(separator: "@", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            let sl = at[0].split(separator: "/", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let spec = VariationSpec(sl[0]), spec.family == .machine else { return nil }
            let loading = sl.count == 2 ? (Loading(rawValue: sl[1]) ?? .stack) : .stack
            let positions = at.count == 2 ? Set(at[1].split(separator: ",").compactMap { Position(rawValue: $0.trimmingCharacters(in: .whitespaces)) }) : []
            return MachineType(name: kv[0], tag: spec.tag, position: spec.position, loading: loading, positions: positions)
        }
    }
    return out
}()

/// The kinds of machine for a base, in list order. Bases you made yourself have none.
func machineTypes(forBase name: String) -> [MachineType] { MACHINE_TYPES[name.lowercased()] ?? [] }

/// Every base that has a machine list, for the tests.
var machineTypeBases: [String] { Array(MACHINE_TYPES.keys) }
