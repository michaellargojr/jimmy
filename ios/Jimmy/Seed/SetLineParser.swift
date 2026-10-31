import Foundation

/// Parse one compact set line: "[W] [L|R] [EZ] <weight|-> x <reps|->[+] [pN] [# note]"
func parseSetLine(_ input: String, unit: WeightUnit = .kg) -> SetEntry {
    var line = input
    var note: String?
    if let hash = line.firstIndex(of: "#") {
        note = line[line.index(after: hash)...].trimmingCharacters(in: .whitespaces)
        line = String(line[..<hash])
    }
    var kind: SetKind = .working
    var side: Side?
    var bar: Bar?
    var partials: Int?
    var weight: Double?
    var reps: Int?
    var plus = false
    for t in line.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
        if t == "W" { kind = .warmup }
        else if t == "L" || t == "R" { side = Side(rawValue: t) }
        else if t == "EZ" { bar = .ez }
        else if t.hasPrefix("p"), let n = Int(t.dropFirst()) { partials = n }
        else if t.contains("x") {
            let parts = t.split(separator: "x", omittingEmptySubsequences: false).map(String.init)
            let w = parts[0], r = parts.count > 1 ? parts[1] : ""
            if w != "-" && !w.isEmpty { weight = Double(w) }
            if !r.isEmpty && r != "-" {
                plus = r.hasSuffix("+")
                reps = Int(r.replacingOccurrences(of: "+", with: ""))
            }
        }
    }
    return SetEntry(kind: kind, unit: unit, weight: weight, reps: reps, plus: plus, partials: partials, side: side, bar: bar, note: note)
}
