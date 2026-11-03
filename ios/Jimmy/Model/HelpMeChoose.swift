import Foundation

// Help me choose: narrows the machine list with a few plain questions (Seed/MachineTraits.swift).
// It only asks what splits the machines still left, offers only answers one of them has, and
// "Not sure" skips a question. Then it asks how you add weight, which sets Plates or Stack.

/// Answer id for "Not sure": the question is skipped.
let NOT_SURE = "?"

/// The machines that fit every answer so far. A machine that leaves a question out fits any answer.
func chooseCandidates(_ types: [MachineType], base: String, answers: [String: String]) -> [MachineType] {
    types.filter { t in
        let traits = machineTraits(base: base, machine: t.name)
        return answers.allSatisfy { q, a in a == NOT_SURE || traits[q] == nil || traits[q] == a }
    }
}

/// The question that best splits what's left (the smallest groups on average), never one already
/// asked or one they all answer the same way. Ties go to the earlier question. Nil when none splits.
func nextChooseQuestion(_ candidates: [MachineType], base: String, asked: Set<String>) -> ChooseQuestion? {
    var best: (score: Int, question: ChooseQuestion)? = nil
    for q in CHOOSE_QUESTIONS where !asked.contains(q.id) {
        var groups: [String: Int] = [:]
        var unknown = 0
        for t in candidates {
            if let a = machineTraits(base: base, machine: t.name)[q.id] { groups[a, default: 0] += 1 } else { unknown += 1 }
        }
        guard groups.count >= 2 else { continue }
        let score = groups.values.map { ($0 + unknown) * ($0 + unknown) }.reduce(0, +)
        if best == nil || score < best!.score { best = (score, q) }
    }
    return best?.question
}

/// The answers a question offers for what's left, in the question's own order.
func chooseAnswers(_ q: ChooseQuestion, candidates: [MachineType], base: String) -> [ChooseAnswer] {
    let have = Set(candidates.compactMap { machineTraits(base: base, machine: $0.name)[q.id] })
    return q.answers.filter { have.contains($0.id) }
}
