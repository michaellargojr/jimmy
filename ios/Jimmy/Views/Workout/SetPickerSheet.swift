import SwiftUI

/// Native wheel pickers for weight and reps, with the small extras (plus, partials, side, bar, note).
struct SetPickerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let workoutId: String
    let itemId: String
    let setId: String
    @State var field: ExerciseCardView.SetField
    let onNext: (ExerciseCardView.SetEdit?) -> Void

    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var loaded = false

    private var item: WorkoutItem? { store.workout(workoutId)?.items.first { $0.id == itemId } }
    private var set: SetEntry? { item?.sets.first { $0.id == setId } }
    private var version: Version? { item.flatMap { store.version($0.versionId) } }

    var body: some View {
        if let item, let s = set, let v = version {
            let labels = setLabels(item.sets)
            let idx = item.sets.firstIndex { $0.id == setId } ?? 0
            let last = lastSession(versionId: v.id, styleId: item.styleId, workouts: store.workouts, versions: store.versions, excludeWorkoutId: workoutId)
            let ghost = last.map { matchLast(now: s, nowAll: item.sets, lastAll: $0.item.sets) } ?? nil
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set \(labels[idx]) · \(field == .weight ? "weight" : "reps")").font(.system(size: 20, weight: .heavy)).foregroundStyle(p.text)
                        Text(store.fullName(v, styleId: item.styleId) + (ghost.map { " · last \($0.formatted)" } ?? "")).font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Chip(text: "Weight", on: field == .weight, small: true) { field = .weight }
                        Chip(text: "Reps", on: field == .reps, small: true) { field = .reps }
                    }
                }
                if field == .weight {
                    Picker("Weight", selection: $weight) {
                        ForEach(weightValues(s.unit), id: \.self) { w in
                            Text("\(fmtWeight(w)) \(s.unit.label)").font(.system(size: 26, weight: .semibold)).monospacedDigit().tag(w)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 176)
                    .onChange(of: weight) { _, w in patch { $0.weight = w } }
                    HStack(spacing: 8) {
                        ForEach(s.unit == .lbs ? [-5.0, -2.5, 2.5, 5.0] : [-1.25, -0.5, 0.5, 1.25], id: \.self) { d in
                            Chip(text: (d > 0 ? "+" : "") + fmtWeight(d), small: true) {
                                weight = max(0, ((weight + d) * 100).rounded() / 100); patch { $0.weight = weight }
                            }
                        }
                        Spacer()
                        Chip(text: s.unit.rawValue, on: true, small: true) {
                            patch { $0.unit = $0.unit == .kg ? .lbs : .kg }
                        }
                        if v.isBarbell {
                            Chip(text: s.bar == .ez ? "EZ" : "BAR", small: true) { patch { $0.bar = $0.bar == .ez ? .straight : .ez } }
                        }
                    }
                } else {
                    Picker("Reps", selection: $reps) {
                        ForEach(0...40, id: \.self) { r in Text("\(r)").font(.system(size: 26, weight: .semibold)).monospacedDigit().tag(r) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 176)
                    .onChange(of: reps) { _, r in patch { $0.reps = r } }
                    HStack(spacing: 8) {
                        Chip(text: "+ at least", on: s.plus, small: true) { patch { $0.plus.toggle() } }
                        Chip(text: "partials \(s.partials ?? 0)", on: (s.partials ?? 0) > 0, small: true) {
                            patch { let n = (($0.partials ?? 0) + 1) % 6; $0.partials = n == 0 ? nil : n }
                        }
                        if v.arms == .one {
                            Chip(text: s.side?.rawValue ?? "L/R", on: s.side != nil, small: true) {
                                patch { $0.side = $0.side == nil ? .L : $0.side == .L ? .R : nil }
                            }
                        }
                        Spacer()
                    }
                }
                TextField("Note for this set (grip, notch, how it felt)", text: Binding(get: { s.note ?? "" }, set: { t in patch { $0.note = t.isEmpty ? nil : t } }))
                    .font(.system(size: 14))
                    .padding(10)
                    .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .foregroundStyle(p.text)
                HStack(spacing: 10) {
                    if field == .weight {
                        PillButton(title: "Reps →", full: true) { field = .reps }
                    } else if idx + 1 < item.sets.count {
                        PillButton(title: "Next set →", full: true) {
                            let next = item.sets[idx + 1]
                            onNext(ExerciseCardView.SetEdit(setId: next.id, field: .weight))
                        }
                    }
                    PillButton(title: "Done", style: .primary, full: true) { dismiss() }
                }
            }
            .padding(16)
            .onAppear {
                if !loaded {
                    loaded = true
                    weight = s.weight ?? ghost?.weight ?? last?.item.sets.first { $0.kind == .working && $0.weight != nil }?.weight ?? 0
                    reps = s.reps ?? ghost?.reps ?? v.repMax
                    if s.weight == nil && field == .weight { patch { $0.weight = weight } }
                    if s.reps == nil && field == .reps { patch { $0.reps = reps } }
                }
            }
            .onChange(of: field) { _, f in
                // Entering the reps step commits the reps the wheel is showing, so a quick "Done" counts the set.
                if f == .reps, s.reps == nil { patch { $0.reps = reps } }
            }
        }
    }

    private func weightValues(_ unit: WeightUnit) -> [Double] {
        let step = unit == .lbs ? 5.0 : 2.5
        let top = unit == .lbs ? 500.0 : 250.0
        var out: [Double] = []
        var w = 0.0
        while w <= top + 0.0001 { out.append((w * 100).rounded() / 100); w += step }
        if !out.contains(weight) { out.append(weight); out.sort() }
        return out
    }

    private func patch(_ f: (inout SetEntry) -> Void) {
        guard var w = store.workout(workoutId), let i = w.items.firstIndex(where: { $0.id == itemId }),
              let j = w.items[i].sets.firstIndex(where: { $0.id == setId }) else { return }
        f(&w.items[i].sets[j])
        store.put(w)
    }
}
