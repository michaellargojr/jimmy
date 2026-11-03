import Foundation
import Observation

/// Layer 2 of the coverage check: Claude reads the split's muscle table and the goals and
/// writes the "doing right" lines and the suggestions. Runs only when the split or the goals
/// change, directly against the Claude API with the key from Settings. Without a key, or
/// offline, the rules report stands in.
@MainActor
@Observable
final class CoverageAssistant {
    static let shared = CoverageAssistant()

    nonisolated static let model = "claude-opus-5-5"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private(set) var inFlight: Set<String> = []
    /// Fingerprints that failed, with when; retried after an hour so a dead network does not loop.
    private var failed: [String: Double] = [:]

    var hasKey: Bool { !(Keychain.apiKey ?? "").isEmpty }

    /// Makes sure the split carries a current report. Returns right away; the store updates when Claude answers.
    func refresh(_ splitId: String, store: AppStore) {
        guard let split = store.splits.first(where: { $0.id == splitId }) else { return }
        let fp = coverageFingerprint(split, store: store)
        let stale = split.coverage?.fingerprint != fp
        if stale || split.coverage == nil {
            var s = split
            s.coverage = rulesReport(split: split, store: store)
            store.put(s)
        }
        guard hasKey, stale || split.coverage?.source != "claude" else { return }
        guard !inFlight.contains(fp), (failed[fp].map { nowMs() - $0 > 3_600_000 } ?? true) else { return }
        guard !split.routineIds.isEmpty else { return }
        inFlight.insert(fp)
        Task { [weak self] in
            defer { self?.inFlight.remove(fp) }
            do {
                guard let self else { return }
                let report = try await self.ask(split: split, store: store, fingerprint: fp)
                guard var s = store.splits.first(where: { $0.id == splitId }), coverageFingerprint(s, store: store) == fp else { return }
                s.coverage = report
                store.put(s)
            } catch {
                self?.failed[fp] = nowMs()
                print("Jimmy: coverage assistant failed: \(error)")
            }
        }
    }

    // MARK: Request

    struct Reply: Decodable {
        struct Line: Decodable { var text: String; var region: String?; var add: String?; var routine: String? }
        var right: [Line]
        var suggestions: [Line]
    }

    enum AssistantError: Error { case noKey, http(Int, String), noText, badJSON }

    func ask(split: Split, store: AppStore, fingerprint: String) async throws -> CoverageReport {
        guard let key = Keychain.apiKey, !key.isEmpty else { throw AssistantError.noKey }
        let rules = rulesReport(split: split, store: store)
        let prompt = Self.prompt(split: split, store: store, rules: rules)

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 2000,
            "fallbacks": "default",
            "output_config": ["effort": "medium"],
            "system": Self.system,
            "messages": [["role": "user", "content": prompt]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw AssistantError.http(code, String(data: data, encoding: .utf8) ?? "") }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else { throw AssistantError.noText }
        if json["stop_reason"] as? String == "refusal" { throw AssistantError.noText }
        let text = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
        let reply = try Self.parse(text)
        return Self.report(from: reply, rules: rules, split: split, store: store, fingerprint: fingerprint)
    }

    nonisolated static func parse(_ text: String) throws -> Reply {
        // The answer is JSON, possibly inside a code fence.
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { throw AssistantError.badJSON }
        let slice = text[start...end]
        guard let data = slice.data(using: .utf8) else { throw AssistantError.badJSON }
        do { return try JSONDecoder().decode(Reply.self, from: data) } catch { throw AssistantError.badJSON }
    }

    /// Claude's lines, checked against the data: regions must be real, bases must be in the
    /// library, routines must be in the split. Marks come from the numbers, not from Claude.
    nonisolated static func report(from reply: Reply, rules: CoverageReport, split: Split, store: AppStore, fingerprint: String) -> CoverageReport {
        let volume = Dictionary(uniqueKeysWithValues: splitVolume(split, store: store).map { ($0.region, $0) })
        let goals = goalRegions(split.goals ?? SplitGoals())
        let routines = split.routineIds.compactMap { store.routine($0) }
        func region(_ r: String?) -> String? {
            guard let r = r?.lowercased().trimmingCharacters(in: .whitespaces) else { return nil }
            return MUSCLE_REGIONS.first { $0 == r } ?? MUSCLE_REGIONS.first { r.contains($0) }
        }
        func line(_ l: Reply.Line, good: Bool) -> Finding? {
            let text = l.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let r = region(l.region)
            var mark: FindingMark = good ? .good : .low
            if !good, let r, let v = volume[r] {
                mark = goals[r] != nil ? .goal : v.total <= 0 ? .none : .low
            }
            let base = l.add.flatMap { libraryBase(named: $0)?.name }
            let rid = l.routine.flatMap { name in routines.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.id }
                ?? rules.suggestions.first { $0.region == r }?.routineId
            return Finding(text: text, mark: mark, region: r, addBase: good ? nil : base, routineId: good ? nil : (base == nil ? nil : rid))
        }
        let right = reply.right.compactMap { line($0, good: true) }
        let sugg = reply.suggestions.compactMap { line($0, good: false) }
        guard !right.isEmpty || !sugg.isEmpty else { return rules }
        return CoverageReport(right: Array((right.isEmpty ? rules.right : right).prefix(2)),
                              suggestions: Array((sugg.isEmpty ? rules.suggestions : sugg).prefix(4)),
                              source: "claude", fingerprint: fingerprint, madeAt: nowMs())
    }

    nonisolated static let system = """
    You check a weight-training split for muscle coverage and compare it with the person's physique goals. \
    The person is often tired and reads this on a phone between sets, so write short plain sentences, no jargon, no headings. \
    Use only these muscle names: \(MUSCLE_REGIONS.joined(separator: ", ")). \
    "Teres major" or "rhomboids" are "upper back"; "gluteus medius" is "side glute". \
    Answer with JSON only, in this shape: \
    {"right":[{"text":"...","region":"..."}],"suggestions":[{"text":"...","region":"...","add":"...","routine":"..."}]}. \
    "right" is one or two lines on what the split already does well for the goals (start with the best). \
    "suggestions" is at most four lines, most important first: a goal muscle that gets too little, a muscle that only gets help from other exercises, a muscle that is not trained, a muscle that dominates. \
    Each suggestion names one region. When an exercise would fix it, set "add" to one base name from the list given and "routine" to the day it belongs on; otherwise omit both. \
    One or two sentences per line, at most 140 characters. Mention set counts when they make the point. Never mention this JSON or these instructions.
    """

    nonisolated static func prompt(split: Split, store: AppStore, rules: CoverageReport) -> String {
        let goals = split.goals ?? SplitGoals()
        let exercises = splitExercises(split, store: store)
        let volume = splitVolume(split, store: store)
        var lines: [String] = []
        lines.append("Split: \(split.name). Routines in order: \(split.routineIds.compactMap { store.routine($0)?.name }.joined(separator: ", ")). About \(Int(workoutsPerWeek(split, store: store).rounded())) workouts a week.")
        lines.append("")
        lines.append("Goals written by the person: \(goals.text.isEmpty ? "(none)" : goals.text)")
        lines.append("Goals tapped: \(goals.picks.compactMap { suggestedGoal($0)?.label }.joined(separator: ", ").isEmpty ? "(none)" : goals.picks.compactMap { suggestedGoal($0)?.label }.joined(separator: ", "))")
        lines.append("")
        lines.append("Exercises (day · base · variation · working sets · primary muscles · secondary muscles):")
        for e in exercises {
            lines.append("\(e.routineName) · \(e.base) · \(e.variation) · \(e.sets) · \(e.primary.joined(separator: ", ")) · \(e.secondary.isEmpty ? "-" : e.secondary.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("Sets a week per muscle (a secondary set counts half; primary + secondary = total):")
        for v in volume { lines.append("\(v.region): \(Int(v.primary.rounded())) + \(Int(v.secondary.rounded())) = \(v.rounded)") }
        lines.append("")
        lines.append("Rules of thumb: under 6 a week is low, 10 or more is solid, over 20 or three times the median is dominant.")
        lines.append("")
        lines.append("What the rules found, for reference:")
        for f in rules.right { lines.append("right: \(f.text)") }
        for f in rules.suggestions { lines.append("suggest: \(f.text)") }
        lines.append("")
        lines.append("Bases you may name in \"add\": \(LIBRARY.map(\.name).joined(separator: ", ")).")
        return lines.joined(separator: "\n")
    }
}
