import SwiftUI

/// Help me choose: one plain question at a time, big answers, tap to move on, Not sure to skip.
/// Ends on the machine it most likely is (Use this, or Not it) or, when two are alike, both to pick
/// from. How you add weight is asked last and sets Plates or Stack.
struct HelpMeChooseView: View {
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let base: Exercise
    let arms: Arms
    let types: [MachineType]
    /// The machine picked, and how it's loaded (nil: the way it usually comes).
    let onPick: (MachineType, Loading?) -> Void

    /// Answers in the order given, so Back undoes the last one.
    @State private var answers: [(question: String, answer: String)] = []
    /// Plates or Stack, once asked ("?" for Not sure).
    @State private var loadingAnswer: String? = nil

    private var given: [String: String] { Dictionary(answers.map { ($0.question, $0.answer) }, uniquingKeysWith: { _, b in b }) }
    private var candidates: [MachineType] { chooseCandidates(types, base: base.name, answers: given) }
    private var question: ChooseQuestion? { nextChooseQuestion(candidates, base: base.name, asked: Set(given.keys)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                topBar
                if let q = question {
                    questionPage(q, answers: chooseAnswers(q, candidates: candidates, base: base.name)) { a in
                        answers.append((q.id, a))
                    }
                } else if loadingAnswer == nil {
                    questionPage(LOADING_QUESTION, answers: LOADING_QUESTION.answers) { a in loadingAnswer = a }
                } else if candidates.count == 1, let t = candidates.first {
                    result(t)
                } else {
                    pickOne(candidates)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
    }

    private var loading: Loading? { loadingAnswer.flatMap { Loading(rawValue: $0) } }

    private var topBar: some View {
        HStack {
            Button { back() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
                    Text("Back").font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(p.accent)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Help me choose").font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
            Spacer()
            Button("Close") { dismiss() }.font(.system(size: 16, weight: .semibold)).foregroundStyle(p.accent)
        }
        .frame(height: 32)
    }

    private func back() {
        if loadingAnswer != nil { loadingAnswer = nil }
        else if !answers.isEmpty { answers.removeLast() }
        else { dismiss() }
    }

    private func questionPage(_ q: ChooseQuestion, answers offered: [ChooseAnswer], onAnswer: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.title).font(.system(size: 28, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14).padding(.bottom, 6)
            ForEach(offered) { a in
                Button { onAnswer(a.id) } label: {
                    HStack(spacing: 12) {
                        Text(a.text).font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Chevron()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Button { onAnswer(NOT_SURE) } label: {
                Text("Not sure").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.secondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func result(_ t: MachineType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Most likely").padding(.top, 18)
            Text(t.name).font(.system(size: 34, weight: .heavy)).tracking(-0.6).foregroundStyle(p.text)
            VariationPill(parts: variationParts(family: .machine, arms: arms, position: t.position, tag: t.tag,
                                                loading: loading ?? t.loading, legs: base.isLegs)
                .map { capitalized($0) })
            PillButton(title: "Use this", style: .primary, full: true) { onPick(t, loading); dismiss() }
                .padding(.top, 18)
            PillButton(title: "Not it", style: .secondary, full: true) { dismiss() }
        }
    }

    private func pickOne(_ ts: [MachineType]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("One of these").padding(.top, 18)
            ForEach(ts) { t in
                Button { onPick(t, loading); dismiss() } label: {
                    Text(t.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            PillButton(title: "Back to the list", style: .secondary, full: true) { dismiss() }
                .padding(.top, 8)
        }
    }
}
