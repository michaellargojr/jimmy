import Foundation

// The machine list: the kinds of machine each exercise is done on. Each kind needs its own
// weights, so the first time you pick one it becomes a variation with its own history. Two
// machines of one kind (say, at two gyms) are told apart by a name ("D Stars").
// Line grammar: Base|Name=variation;Name=variation, the variation in VariationSpec grammar
// without arms, and "/plates" when the kind usually takes plates (else a weight stack). The plain
// machine (no tag) is the kind most gyms have. How a kind is loaded is a guess you can switch.

/// One kind of machine for a base: "Iso-lateral pulldown" is a machine variation tagged "iso-lateral".
struct MachineType: Hashable, Identifiable {
    let name: String
    /// The variation's tag, nil for the plain machine.
    let tag: String?
    /// Set when the kind fixes the position (a seated calf raise).
    let position: Position?
    /// How this kind usually comes: the app's pick, which you can switch.
    let loading: Loading
    var id: String { name }

    /// A variation's tag and position fit this kind.
    func fits(tag t: String?, position p: Position?) -> Bool {
        (t ?? "").lowercased() == (tag ?? "").lowercased() && (position == nil || position == p)
    }
    func fits(_ v: Version) -> Bool { v.family == .machine && fits(tag: v.tag, position: v.position) }
}

private let RAW_MACHINES = """
Chest Press|Chest press=machine;Iso-lateral chest press=machine iso-lateral/plates;Converging chest press=machine converging;Wide chest press=machine wide/plates
Incline Press|Incline chest press=machine;Iso-lateral incline press=machine iso-lateral/plates
Chest Fly|Fly machine=machine;Pec deck=machine pec deck
Incline Fly|Incline fly machine=machine
Dip|Seated dip=machine;Assisted dip=machine assisted
Pullover|Pullover machine=machine
Pulldown|Lat pulldown=machine;Iso-lateral pulldown=machine iso-lateral/plates;High row=machine high row/plates;Wide pulldown=machine wide/plates
Pull-Up|Assisted pull-up=machine assisted
Row|Seated row=machine chest-supported;Iso-lateral row=machine iso-lateral/plates;T-bar row=machine T-bar/plates;Low row=machine low row/plates
Rear Delt Row|Rear delt row machine=machine
Shrug|Shrug machine=machine/plates
Back Extension|Back extension machine=machine
Shoulder Press|Shoulder press=machine;Iso-lateral shoulder press=machine iso-lateral/plates;Converging shoulder press=machine converging
Lateral Raise|Lateral raise machine=machine;Standing lateral raise machine=machine standing
Rear Delt Fly|Reverse pec deck=machine
Curl|Preacher curl machine=machine arm-on-pad;Iso-lateral curl=machine iso-lateral/plates
Tricep Extension|Tricep extension machine=machine;Overhead tricep machine=machine overhead
Tricep Pushdown|Tricep press machine=machine
Wrist Roller|Wrist roller=machine
Squat|Hack squat=machine hack/plates;Pendulum squat=machine pendulum/plates;Belt squat=machine belt/plates;V-squat=machine V-squat/plates
Leg Press|45° leg press=machine/plates;Seated leg press=machine seated;Vertical leg press=machine vertical/plates;Iso-lateral leg press=machine iso-lateral/plates
Leg Extension|Leg extension=machine;Iso-lateral leg extension=machine iso-lateral/plates
Leg Curl|Seated leg curl=machine seated;Lying leg curl=machine lying;Standing leg curl=machine standing;Kneeling leg curl=machine kneeling
Hip Thrust|Hip thrust machine=machine/plates
Glute Kickback|Kickback machine=machine
Hip Abduction|Abductor machine=machine
Hip Adduction|Adductor machine=machine
Calf Raise|Standing calf raise=machine standing;Seated calf raise=machine seated/plates;Donkey calf raise=machine donkey/plates;Leg press calf raise=machine leg press/plates
Tibialis Raise|Tib raise machine=machine/plates
Crunch|Ab crunch machine=machine
"""

private let MACHINE_TYPES: [String: [MachineType]] = {
    var out: [String: [MachineType]] = [:]
    for line in RAW_MACHINES.split(separator: "\n") {
        let c = line.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard c.count == 2 else { continue }
        out[c[0].lowercased()] = c[1].split(separator: ";").compactMap { entry -> MachineType? in
            let kv = entry.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2 else { return nil }
            let sl = kv[1].split(separator: "/", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let spec = VariationSpec(sl[0]), spec.family == .machine else { return nil }
            let loading = sl.count == 2 ? (Loading(rawValue: sl[1]) ?? .stack) : .stack
            return MachineType(name: kv[0], tag: spec.tag, position: spec.position, loading: loading)
        }
    }
    return out
}()

/// The kinds of machine for a base, in list order. Bases you made yourself have none.
func machineTypes(forBase name: String) -> [MachineType] { MACHINE_TYPES[name.lowercased()] ?? [] }

/// Every base that has a machine list, for the tests.
var machineTypeBases: [String] { Array(MACHINE_TYPES.keys) }
