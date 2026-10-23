import SwiftUI

/// One exercise inside the live workout: illustration slot, name, last time, the set grid.
struct ExerciseCardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let workoutId: String
    let itemId: String
    var compact: Bool = false
    var onSwap: () -> Void = {}
    var onAddAfter: () -> Void = {}

    @State private var editing: SetEdit? = nil
    @State private var upTrigger = 0
    @State private var logTrigger = 0
    @State private var lastLogged: Double = 0
    @State private var showNote = false
    @State private var editVersion = false

    struct SetEdit: Identifiable { var id: String { setId + field.rawValue }; var setId: String; var field: SetField }
    enum SetField: String { case weight, reps }

    private var workout: Workout? { store.workout(workoutId) }
    private var item: WorkoutItem? { workout?.items.first { $0.id == itemId } }

    var body: some View {
        if let w = workout, let item, let v = store.version(item.versionId) {
            let last = lastSession(versionId: v.id, workouts: store.workouts, versions: store.versions, excludeWorkoutId: w.id)
            let other = last == nil ? otherVersionLast(version: v, workouts: store.workouts, versions: store.versions, excludeWorkoutId: w.id) : nil
            let verdictNow = verdict(item.sets, v)
            VStack(alignment: .leading, spacing: 12) {
                if !compact { illustration(v) }
                titleRow(v, verdictNow: verdictNow, item: item)
                lastLine(last: last, other: other)
                setGrid(w: w, item: item, v: v, last: last)
                if item.note?.isEmpty == false { Text(item.note!).font(.system(size: 13)).foregroundStyle(p.secondary).padding(.horizontal, 2) }
                statusRow(verdictNow, item: item)
            }
            .opacity(item.skipped == true ? 0.45 : 1)
            .sheet(item: $editing) { e in
                SetPickerSheet(workoutId: workoutId, itemId: itemId, setId: e.setId, field: e.field) { next in editing = next }
                    .presentationDetents([.medium, .large])
                    .presentationBackground(p.card)
            }
            .sheet(isPresented: $showNote) { noteSheet(item) }
            .sheet(isPresented: $editVersion) {
                NavigationStack { VersionEditorView(versionId: v.id) }.presentationBackground(p.bg)
            }
            .sensoryFeedback(.success, trigger: upTrigger)
            .sensoryFeedback(.impact(weight: .medium), trigger: logTrigger)
            .preference(key: SetLoggedKey.self, value: lastLogged)
            .onChange(of: verdictNow == .up) { _, isUp in
                if isUp { upTrigger += 1; Feedback.ding(sound: store.settings.sound) }
            }
        }
    }

    // MARK: Pieces

    private func illustration(_ v: Version) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(p.card)
            Image(systemName: symbol(for: v))
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(p.border)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text([store.muscle(of: v)?.rawValue, v.equipment.label, v.machine].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 12)).foregroundStyle(p.secondary).padding(14)
        }
        .frame(height: 150)
        .contextMenu { cardMenu(v) }
    }

    private func symbol(for v: Version) -> String {
        switch store.muscle(of: v) {
        case .Abs: return "figure.core.training"
        case .Legs, .Glutes, .Calves: return "figure.strengthtraining.functional"
        case .Back: return "figure.rowing"
        default: return "figure.strengthtraining.traditional"
        }
    }

    private func titleRow(_ v: Version, verdictNow: Verdict, item: WorkoutItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(v.name).font(.system(size: compact ? 22 : 28, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text).lineLimit(2).minimumScaleFactor(0.8)
                if compact {
                    Text([store.muscle(of: v)?.rawValue, v.equipment.label].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(p.muted)
                }
            }
            Spacer()
            Chip(text: v.repRange, small: true)
            Menu {
                cardMenu(v)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(p.secondary)
                    .frame(width: 36, height: 36).background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func cardMenu(_ v: Version) -> some View {
        Button { showNote = true } label: { Label("Note for today", systemImage: "square.and.pencil") }
        Button { toggleWarmup() } label: { Label(item?.sets.contains { $0.kind == .warmup } == true ? "Remove warm-up" : "Add warm-up", systemImage: "flame") }
        Button { removeLastSet() } label: { Label("Remove last set", systemImage: "minus.square") }
        Button { editVersion = true } label: { Label("Edit exercise", systemImage: "slider.horizontal.3") }
        Divider()
        Button { toggleSkip() } label: { Label(item?.skipped == true ? "Unskip" : "Skip today", systemImage: "forward") }
        Button { onSwap() } label: { Label("Swap for another", systemImage: "arrow.left.arrow.right") }
        Button { onAddAfter() } label: { Label("Add exercise after", systemImage: "plus") }
        Button(role: .destructive) { remove() } label: { Label("Remove from workout", systemImage: "trash") }
    }

    private func lastLine(last: LastSession?, other: LastSession?) -> some View {
        Group {
            if let last {
                let sets = last.item.sets.filter { $0.hasData }
                let line = "Last time · \(last.daysAgo == 0 ? "today" : "\(last.daysAgo)d ago") · " + sets.map { ($0.kind == .warmup ? "W " : "") + $0.formatted }.joined(separator: ", ")
                VStack(alignment: .leading, spacing: 2) {
                    Text(line).font(.system(size: 14)).italic().foregroundStyle(p.muted)
                    if let n = last.item.note, !n.isEmpty { Text(n).font(.system(size: 13)).foregroundStyle(p.muted) }
                    let notes = last.item.sets.filter { $0.note?.isEmpty == false }.map { "\($0.side?.rawValue ?? "")\($0.kind == .warmup ? "W" : "") \($0.note!)".trimmingCharacters(in: .whitespaces) }
                    if !notes.isEmpty { Text(notes.joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(p.muted) }
                }
            } else if let other {
                Text("\(other.version.name) \(other.daysAgo)d ago · " + other.item.sets.filter { $0.reps != nil }.map { $0.formatted }.joined(separator: ", "))
                    .font(.system(size: 14)).italic().foregroundStyle(p.muted)
            } else {
                Text("First time").font(.system(size: 14)).italic().foregroundStyle(p.muted)
            }
        }
        .padding(.horizontal, 2)
    }

    private func setGrid(w: Workout, item: WorkoutItem, v: Version, last: LastSession?) -> some View {
        let labels = setLabels(item.sets)
        let firstOpen = item.sets.firstIndex { $0.kind == .working && $0.reps == nil }
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Set").frame(width: 48)
                Text("Weight").frame(maxWidth: .infinity)
                Text("Reps").frame(maxWidth: .infinity)
                Text("").frame(width: 52)
            }
            .font(.system(size: 13)).foregroundStyle(p.muted)
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
            ForEach(Array(item.sets.enumerated()), id: \.element.id) { i, s in
                let lastMatch = last.map { matchLast(now: s, nowAll: item.sets, lastAll: $0.item.sets) } ?? nil
                SetRowView(set: s, label: labels[i], ghost: lastMatch, isCurrent: i == firstOpen,
                           improved: improved(now: s, last: lastMatch),
                           onWeight: { editing = SetEdit(setId: s.id, field: .weight) },
                           onReps: { editing = SetEdit(setId: s.id, field: .reps) },
                           onCheck: { check(s, ghost: lastMatch, prev: i > 0 ? item.sets[i - 1] : nil, v: v) },
                           onLabel: { toggleKind(s) })
            }
            Rectangle().fill(p.line).frame(height: 1).padding(.top, 8)
            Button { addSet(v) } label: {
                Label("Add set", systemImage: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(p.accent)
                    .frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(.plain)
        }
        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(verdict(item.sets, v) == .up ? p.accent : .clear, lineWidth: 2))
    }

    private func statusRow(_ verdictNow: Verdict, item: WorkoutItem) -> some View {
        HStack {
            switch verdictNow {
            case .up: Badge(text: "GO UP NEXT TIME", kind: .up)
            case .down: Badge(text: "UNDER RANGE", kind: .down)
            case .none:
                if item.isDone { Badge(text: "IN RANGE") } else { EmptyView() }
            }
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private func noteSheet(_ item: WorkoutItem) -> some View {
        NoteSheet(title: "Note for today", text: item.note ?? "", placeholder: "e.g. 3rd notch, underhand grip, felt it in the left shoulder") { text in
            update { $0.note = text.isEmpty ? nil : text }
        }
        .presentationDetents([.medium])
        .presentationBackground(p.card)
    }

    // MARK: Mutations

    private func update(_ f: (inout WorkoutItem) -> Void) {
        guard var w = workout, let i = w.items.firstIndex(where: { $0.id == itemId }) else { return }
        f(&w.items[i])
        store.put(w)
    }

    private func patch(_ setId: String, _ f: (inout SetEntry) -> Void) {
        update { item in
            if let j = item.sets.firstIndex(where: { $0.id == setId }) { f(&item.sets[j]) }
        }
    }

    /// Tapping the check: confirm the ghost values if the set is empty, or clear the set if it was done.
    private func check(_ s: SetEntry, ghost: SetEntry?, prev: SetEntry?, v: Version) {
        if s.reps != nil {
            patch(s.id) { $0.reps = nil }
            return
        }
        let weight = s.weight ?? ghost?.weight ?? prev?.weight
        let reps = ghost?.reps ?? prev?.reps ?? v.repMax
        patch(s.id) { $0.weight = weight; $0.reps = reps; if let g = ghost, g.plus { $0.plus = g.plus } }
        logTrigger += 1
        lastLogged = nowMs()
    }

    private func toggleKind(_ s: SetEntry) {
        patch(s.id) { $0.kind = $0.kind == .warmup ? .working : .warmup }
    }

    private func addSet(_ v: Version) {
        update { item in
            let lastWorking = item.sets.last { $0.kind == .working } ?? item.sets.last
            let unit = lastWorking?.unit ?? store.settings.unit
            let bar = lastWorking?.bar
            if v.arms == .one {
                item.sets.append(SetEntry(kind: .working, unit: unit, weight: lastWorking?.weight, side: .L, bar: bar))
                item.sets.append(SetEntry(kind: .working, unit: unit, weight: lastWorking?.weight, side: .R, bar: bar))
            } else {
                item.sets.append(SetEntry(kind: .working, unit: unit, weight: lastWorking?.weight, bar: bar))
            }
        }
    }

    private func removeLastSet() {
        update { item in
            if let i = item.sets.lastIndex(where: { $0.kind == .working }) { item.sets.remove(at: i) }
        }
    }

    private func toggleWarmup() {
        update { item in
            if item.sets.contains(where: { $0.kind == .warmup }) { item.sets.removeAll { $0.kind == .warmup } }
            else { item.sets.insert(SetEntry(kind: .warmup, unit: item.sets.first?.unit ?? store.settings.unit, bar: item.sets.first?.bar), at: 0) }
        }
    }

    private func toggleSkip() { update { $0.skipped = $0.skipped == true ? nil : true } }

    private func remove() {
        guard var w = workout else { return }
        w.items.removeAll { $0.id == itemId }
        w.groups.removeAll { g in !w.items.contains { $0.groupId == g.id } }
        store.put(w)
    }
}

struct SetRowView: View {
    @Environment(\.palette) private var p
    let set: SetEntry
    let label: String
    let ghost: SetEntry?
    let isCurrent: Bool
    let improved: Bool
    let onWeight: () -> Void
    let onReps: () -> Void
    let onCheck: () -> Void
    let onLabel: () -> Void

    private var done: Bool { set.kind == .working ? set.reps != nil : (set.reps != nil || set.weight != nil) }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Button(action: onLabel) {
                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isCurrent ? p.accent : set.kind == .warmup ? p.muted : p.secondary)
                        .frame(width: 48, height: 50)
                        .background(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(isCurrent ? p.accent : p.border, lineWidth: 2))
                }
                .buttonStyle(.plain)

                field(value: set.weight.map { fmtWeight($0) }, ghost: ghost?.weight.map { fmtWeight($0) }, suffix: set.unit.label, action: onWeight)
                field(value: set.reps.map { "\($0)\(set.plus ? "+" : "")" }, ghost: ghost?.reps.map { "\($0)\(ghost!.plus ? "+" : "")" },
                      suffix: (set.partials ?? 0) > 0 ? "p\(set.partials!)" : nil, action: onReps)

                Button(action: onCheck) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(done ? p.accent : p.elevated)
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(done ? .clear : p.border, lineWidth: 2)
                        if done { Image(systemName: "checkmark").font(.system(size: 18, weight: .heavy)).foregroundStyle(p.onAccent) }
                    }
                    .frame(width: 52, height: 50)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(done ? "Set \(label) done" : "Mark set \(label) done")
            }
            HStack(spacing: 8) {
                if set.bar != nil { Text(set.bar == .ez ? "EZ bar" : "Straight bar").font(.system(size: 11, weight: .semibold)).foregroundStyle(p.muted) }
                if improved { Text("✓ beat last time").font(.system(size: 11, weight: .bold)).foregroundStyle(p.accent) }
                if let n = set.note, !n.isEmpty { Text(n).font(.system(size: 11)).foregroundStyle(p.muted).lineLimit(1) }
                Spacer()
            }
            .padding(.leading, 56)
            .frame(minHeight: (set.bar != nil || improved || set.note?.isEmpty == false) ? 14 : 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
    }

    private func field(value: String?, ghost: String?, suffix: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if let value {
                    Text(value).font(.system(size: 24, weight: .bold)).monospacedDigit().foregroundStyle(p.text)
                    if let suffix { Text(suffix).font(.system(size: 12, weight: .semibold)).foregroundStyle(p.muted) }
                } else if let ghost {
                    Text(ghost).font(.system(size: 20, weight: .semibold)).monospacedDigit().foregroundStyle(p.muted)
                } else {
                    Text("–").font(.system(size: 20, weight: .semibold)).foregroundStyle(p.border)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct NoteSheet: View {
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State var text: String
    let placeholder: String
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 20, weight: .heavy)).foregroundStyle(p.text)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .foregroundStyle(p.text)
            PillButton(title: "Save", style: .primary, full: true) { onSave(text); dismiss() }
            Spacer()
        }
        .padding(16)
    }
}
