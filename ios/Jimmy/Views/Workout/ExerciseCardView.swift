import SwiftUI

/// One exercise inside the live workout: full name, arms and rep range, style, last time, the set grid.
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
    @State private var newStyle = false
    @State private var showFormCues = false
    @State private var customRange = false
    /// The set a full swipe asked to delete, waiting on the "are you sure".
    @State private var pendingDelete: String? = nil

    struct SetEdit: Identifiable { var id: String { setId + field.rawValue }; var setId: String; var field: SetField }
    enum SetField: String { case weight, reps, rating }

    static let repRanges: [(Int, Int)] = [(3, 5), (5, 8), (6, 10), (8, 12), (10, 15), (12, 15), (15, 20)]

    private var workout: Workout? { store.workout(workoutId) }
    private var item: WorkoutItem? { workout?.items.first { $0.id == itemId } }

    var body: some View {
        if let w = workout, let item, let v = store.version(item.versionId) {
            let last = lastSession(versionId: v.id, styleId: item.styleId, workouts: store.workouts, versions: store.versions, excludeWorkoutId: w.id)
            let other = otherVersionLast(version: v, workouts: store.workouts, versions: store.versions, excludeWorkoutId: w.id)
            // The verdict waits until every set has its numbers, so a blank added set hides it.
            let complete = setsComplete(item.sets, bodyweight: v.family == .body)
            let verdictNow = complete ? verdict(item.sets, v) : Verdict.none
            VStack(alignment: .leading, spacing: 14) {
                titleBlock(v, item: item)
                lastTime(last: last, other: other)
                formCuesLine(v)
                setGrid(item: item, v: v, last: last, done: complete)
                if item.note?.isEmpty == false { Text(item.note!).font(.system(size: 14)).foregroundStyle(p.secondary).padding(.horizontal, 4) }
                if complete { statusBox(verdictNow) }
            }
            .opacity(item.skipped == true ? 0.45 : 1)
            .sheet(item: $editing) { e in
                SetPickerSheet(workoutId: workoutId, itemId: itemId, setId: e.setId, field: e.field)
                    .presentationBackground(p.card)
            }
            .sheet(isPresented: $showNote) { noteSheet(item) }
            .sheet(isPresented: $editVersion) {
                NavigationStack { VersionEditorView(versionId: v.id) }.presentationBackground(p.bg)
            }
            .sheet(isPresented: $showFormCues) {
                NavigationStack { FormCuesView(versionId: v.id, showsClose: true) }
                    .presentationDetents([.large]).presentationBackground(p.bg)
            }
            .sheet(isPresented: $newStyle) {
                StyleEditorSheet(version: v, style: nil) { s in update { $0.styleId = s.id } }
                    .presentationDetents([.large]).presentationBackground(p.card)
            }
            .sheet(isPresented: $customRange) {
                RepRangeSheet(version: v).presentationBackground(p.card)
            }
            .alert(deleteTitle(item), isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Delete", role: .destructive) { if let id = pendingDelete { deleteSet(id) }; pendingDelete = nil }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
            .sensoryFeedback(.success, trigger: upTrigger)
            .sensoryFeedback(.impact(weight: .medium), trigger: logTrigger)
            .preference(key: SetLoggedKey.self, value: lastLogged)
            .onChange(of: complete && verdictNow == .up) { _, isUp in
                if isUp { upTrigger += 1 }
            }
        }
    }

    // MARK: Title

    /// "Dumbbell Shoulder Press", then "Two arms" with the rep range, then the style.
    private func titleBlock(_ v: Version, item: WorkoutItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.workoutName(v))
                .font(.system(size: compact ? 23 : 28, weight: .heavy)).tracking(-0.5)
                .foregroundStyle(p.text).lineLimit(2).minimumScaleFactor(0.8)
                .contextMenu { cardMenu(v) }
            HStack(spacing: 6) {
                Text(store.armsText(v)).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.secondary).lineLimit(1)
                Spacer(minLength: 4)
                repRangeMenu(v)
                Menu { cardMenu(v) } label: {
                    Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(p.secondary)
                        .frame(width: 36, height: 36).background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                }
                .menuOrder(.fixed)
                .accessibilityLabel("More")
            }
            styleMenu(v, item: item)
        }
    }

    /// The rep range in the accent color. Picking another one changes the variation for good.
    private func repRangeMenu(_ v: Version) -> some View {
        Menu {
            ForEach(Self.repRanges.indices, id: \.self) { i in
                let r = Self.repRanges[i]
                Button { setRange(v.id, r.0, r.1) } label: {
                    if v.repMin == r.0 && v.repMax == r.1 { Label("\(r.0)-\(r.1)", systemImage: "checkmark") } else { Text("\(r.0)-\(r.1)") }
                }
            }
            Divider()
            Button("Custom…") { customRange = true }
        } label: {
            Text("\(v.repMin)-\(v.repMax)")
                .font(.system(size: 17, weight: .heavy)).monospacedDigit()
                .foregroundStyle(p.accent)
                .frame(height: 36).padding(.horizontal, 12)
                .background(p.accentSoft, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
        .menuOrder(.fixed)
        .accessibilityLabel("Rep range \(v.repMin) to \(v.repMax)")
    }

    /// A tappable badge under last time, modelled on "Go up next time", with the play button
    /// in a circle. It lights up (accent on soft accent, with the count) when the variation
    /// has form cues, and stays grey when it has none, still tappable to add one mid-workout.
    private func formCuesLine(_ v: Version) -> some View {
        let n = store.formCueCount(v.id)
        return Button { showFormCues = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "play.circle.fill").font(.system(size: 17, weight: .bold))
                Text(n > 0 ? "Form cues · \(n)" : "Form cues").font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(n > 0 ? p.accent : p.muted)
            .frame(height: 36)
            .padding(.horizontal, 12)
            .background(n > 0 ? p.accentSoft : p.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(n > 0 ? "Form cues, \(n)" : "Form cues")
    }

    /// The style, written out. The chevron opens the list to switch style or make one.
    private func styleMenu(_ v: Version, item: WorkoutItem) -> some View {
        let styles = store.styles(of: v.id)
        let current = store.style(item.styleId)
        return Menu {
            ForEach(styles) { s in
                Button { update { $0.styleId = s.id } } label: {
                    if s.id == item.styleId { Label(s.label, systemImage: "checkmark") } else { Text(s.label) }
                }
            }
            if item.styleId != nil { Button("No style") { update { $0.styleId = nil } } }
            Divider()
            Button { newStyle = true } label: { Label("New style", systemImage: "plus") }
        } label: {
            HStack(spacing: 8) {
                Text(current?.label ?? "No style")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(current == nil ? p.muted : p.text)
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(p.secondary)
                    .frame(width: 30, height: 26)
                    .background(p.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Style \(current?.label ?? "none"), change")
    }

    /// Main actions first, then the editing ones, then removal.
    @ViewBuilder
    private func cardMenu(_ v: Version) -> some View {
        Section {
            Button { toggleSkip() } label: { Label(item?.skipped == true ? "Unskip" : "Skip today", systemImage: "forward") }
            Button { onSwap() } label: { Label("Swap for another", systemImage: "arrow.left.arrow.right") }
        }
        Section {
            Button { onAddAfter() } label: { Label("Add exercise", systemImage: "plus") }
            Button { editVersion = true } label: { Label("Edit exercise", systemImage: "slider.horizontal.3") }
            Button { showNote = true } label: { Label("Note for today", systemImage: "square.and.pencil") }
        }
        Section {
            Button(role: .destructive) { remove() } label: { Label("Remove from workout", systemImage: "trash") }
        }
    }

    // MARK: Last time

    private func lastTime(last: LastSession?, other: LastSession?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let last {
                let sets = last.item.sets.filter { $0.hasData }
                let labels = setLabels(last.item.sets)
                // Two-arm working sets need no tag; the rest read W, D, 1L, WR ...
                let tags: [String: String] = Dictionary(last.item.sets.enumerated().map { i, s in
                    (s.id, s.kind == .working && s.side == nil ? "" : labels[i])
                }, uniquingKeysWith: { a, _ in a })
                // When the last time was a different style, say which, so the ghosts make sense.
                let styleNote = last.sameStyle ? nil : (store.style(last.item.styleId)?.label ?? "no style")
                let when = ([relativeDays(last.workout.date).lowercased(), styleNote] as [String?]).compactMap { $0 }.joined(separator: " · ")
                VStack(alignment: .leading, spacing: 8) {
                    (Text("Last time").foregroundStyle(p.accent) + Text(" · " + when).foregroundStyle(p.secondary))
                        .font(.system(size: 15, weight: .bold))
                    lastSets(sets, tags: tags)
                    let setNotes: [String] = last.item.sets.compactMap { s in
                        guard let n = s.note, !n.isEmpty else { return nil }
                        let tag = tags[s.id] ?? ""
                        return tag.isEmpty ? n : "\(tag) \(n)"
                    }
                    let notes = ([last.item.note ?? ""] + setNotes).filter { !$0.isEmpty }
                    if !notes.isEmpty {
                        Text(notes.joined(separator: " · ")).font(.system(size: 14)).foregroundStyle(p.muted)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(p.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                // Outlined like a finished set grid: an outline means done.
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(p.accent, lineWidth: 2))
            } else {
                Text("First time").font(.system(size: 15, weight: .semibold)).foregroundStyle(p.muted).padding(.horizontal, 4)
            }
            // The other variation of the same exercise: quieter, still readable.
            if let other {
                let sets: [String] = other.item.sets.filter { $0.kind != .warmup && $0.reps != nil }.prefix(3).map { $0.formatted }
                let parts: [String] = [store.variationText(other.version), relativeDays(other.workout.date).lowercased()] + (sets.isEmpty ? [] : [sets.joined(separator: ", ")])
                Text(parts.joined(separator: " · "))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
        }
    }

    /// Last time's sets, big. One arm reads as two rows, left arm on top: WL 1L 2L over WR 1R 2R.
    @ViewBuilder
    private func lastSets(_ sets: [SetEntry], tags: [String: String]) -> some View {
        if sets.contains(where: { $0.side != nil }) {
            let rows = [sets.filter { $0.side != .R }, sets.filter { $0.side == .R }]
            ViewThatFits(in: .horizontal) {
                sideGrid(rows, tags: tags, size: 22)
                sideGrid(rows, tags: tags, size: 18)
                sideGrid(rows, tags: tags, size: 15)
            }
        } else {
            // One line when it fits, shrinking a little first; wrap only when it really can't.
            ViewThatFits(in: .horizontal) {
                lastLine(sets, tags: tags, size: 22)
                lastLine(sets, tags: tags, size: 19)
                FlowRow(spacing: 18, lineSpacing: 6) {
                    ForEach(sets) { s in lastValue(s, tag: tags[s.id], size: 22) }
                }
            }
        }
    }

    private func lastLine(_ sets: [SetEntry], tags: [String: String], size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.75) {
            ForEach(sets) { s in lastValue(s, tag: tags[s.id], size: size) }
        }
        .fixedSize()
    }

    private func sideGrid(_ rows: [[SetEntry]], tags: [String: String], size: CGFloat) -> some View {
        Grid(alignment: .leading, horizontalSpacing: size * 0.75, verticalSpacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(rows[r]) { s in lastValue(s, tag: tags[s.id], size: size) }
                }
            }
        }
        .fixedSize()
    }

    private func lastValue(_ s: SetEntry, tag: String?, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let tag, !tag.isEmpty {
                Text(tag).font(.system(size: (size * 0.64).rounded(), weight: .bold)).foregroundStyle(p.muted)
            }
            Text(s.valueText).font(.system(size: size, weight: .heavy)).monospacedDigit().foregroundStyle(p.text)
        }
    }

    // MARK: Sets

    private func setGrid(item: WorkoutItem, v: Version, last: LastSession?, done: Bool) -> some View {
        let labels = setLabels(item.sets)
        let firstOpen = item.sets.firstIndex { $0.reps == nil }
        let bodyweight = v.family == .body
        let rating = store.settings.rating
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Set").frame(width: 44)
                Text("Weight").frame(maxWidth: .infinity)
                Text("Reps").frame(maxWidth: .infinity)
                Text(rating.title).fixedSize().frame(width: 48)
                Text("").frame(width: 48)
            }
            .font(.system(size: 13)).foregroundStyle(p.muted)
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
            ForEach(Array(item.sets.enumerated()), id: \.element.id) { i, s in
                let lastMatch = last.map { matchLast(now: s, nowAll: item.sets, lastAll: $0.item.sets) } ?? nil
                SetRowView(entry: s, label: labels[i], ghost: lastMatch, isCurrent: i == firstOpen,
                           improved: improved(now: s, last: lastMatch), bodyweight: bodyweight, rating: rating,
                           pendingDelete: pendingDelete == s.id,
                           onWeight: { editing = SetEdit(setId: s.id, field: .weight) },
                           onReps: { editing = SetEdit(setId: s.id, field: .reps) },
                           onRating: { editing = SetEdit(setId: s.id, field: .rating) },
                           onCheck: { check(s, ghost: lastMatch, prev: i > 0 ? item.sets[i - 1] : nil, v: v) },
                           onLabel: { update { $0.sets = cycleSetKind($0.sets, at: i) } },
                           onDelete: { pendingDelete = s.id })
            }
            Rectangle().fill(p.line).frame(height: 1).padding(.top, 8)
            Button { addSet(v) } label: {
                Label("Add set", systemImage: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(p.accent)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(done ? p.accent : .clear, lineWidth: 2))
    }

    /// Shown once every set is in. Going up gets the filled box; the other two are grey with the
    /// completion outline. Emoji, not arrows, so nothing reads as a way to scroll.
    @ViewBuilder
    private func statusBox(_ verdictNow: Verdict) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        switch verdictNow {
        case .up:
            Text("✅  Time to ascend")
                .font(.system(size: 18, weight: .heavy)).foregroundStyle(p.onAccent)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(p.accent, in: shape)
        case .down:
            Text("🙏  Lower the weight next time")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(p.elevated, in: shape)
                .overlay(shape.stroke(p.accent, lineWidth: 2))
        case .none:
            Text("💪  Keep working")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(p.elevated, in: shape)
                .overlay(shape.stroke(p.accent, lineWidth: 2))
        }
    }

    private func noteSheet(_ item: WorkoutItem) -> some View {
        NoteSheet(title: "Note for today", text: item.note ?? "", placeholder: "e.g. 3rd notch, underhand grip, felt it in the left shoulder") { text in
            update { $0.note = text.isEmpty ? nil : text }
        }
        .presentationDetents([.medium])
        .presentationBackground(p.card)
    }

    private func deleteTitle(_ item: WorkoutItem) -> String {
        guard let id = pendingDelete, let i = item.sets.firstIndex(where: { $0.id == id }) else { return "Delete set?" }
        return "Delete set \(setLabels(item.sets)[i])?"
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

    /// Tapping the check: confirm the ghost values if the set is open, or clear the set if it was done.
    /// With no weight to go on (first time), it opens the weight wheel instead.
    private func check(_ s: SetEntry, ghost: SetEntry?, prev: SetEntry?, v: Version) {
        let bodyweight = v.family == .body
        if s.reps != nil && (s.weight != nil || bodyweight) {
            patch(s.id) { $0.reps = nil }
            return
        }
        let weight = s.weight ?? ghost?.weight ?? prev?.weight
        if weight == nil && !bodyweight {
            editing = SetEdit(setId: s.id, field: .weight)
            return
        }
        let reps = s.reps ?? ghost?.reps ?? prev?.reps ?? v.repMax
        patch(s.id) { $0.weight = weight; $0.reps = reps; if let g = ghost, g.plus, s.reps == nil { $0.plus = g.plus } }
        logTrigger += 1
        lastLogged = nowMs()
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

    private func deleteSet(_ id: String) {
        update { $0.sets.removeAll { $0.id == id } }
    }

    private func setRange(_ versionId: String, _ lo: Int, _ hi: Int) {
        guard var v = store.version(versionId) else { return }
        v.repMin = lo; v.repMax = hi
        store.put(v)
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
    let entry: SetEntry
    let label: String
    let ghost: SetEntry?
    let isCurrent: Bool
    let improved: Bool
    var bodyweight: Bool = false
    /// Activation or Intensity, whichever Settings picked; it gets its own column.
    var rating: SetRating = .activation
    /// True while the "Delete set?" question is up for this row, so it stays swiped open.
    var pendingDelete: Bool = false
    let onWeight: () -> Void
    let onReps: () -> Void
    var onRating: () -> Void = {}
    let onCheck: () -> Void
    let onLabel: () -> Void
    var onDelete: () -> Void = {}

    @State private var dx: CGFloat = 0
    @State private var width: CGFloat = 0
    @State private var horizontal: Bool? = nil

    private static let deleteRed = Color(hex: 0xE5484D)
    private var done: Bool { entry.reps != nil && (entry.weight != nil || bodyweight) }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                // An accent outline means done, as everywhere on the card. The set you're on next
                // gets accent text on a soft fill instead.
                Button(action: onLabel) {
                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(done ? p.text : isCurrent ? p.accent : entry.kind == .working ? p.secondary : p.muted)
                        .frame(width: 44, height: 50)
                        .background(isCurrent && !done ? p.accentSoft : .clear, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(done ? p.accent : p.border, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set \(label)")
                .accessibilityHint("Changes the set type")

                field(value: entry.weight.map { fmtWeight($0) }, ghost: ghost?.weight.map { fmtWeight($0) }, suffix: entry.unit.label, action: onWeight)
                field(value: entry.reps.map { "\($0)\(entry.plus ? "+" : "")" }, ghost: ghost?.reps.map { "\($0)\(ghost!.plus ? "+" : "")" },
                      suffix: (entry.partials ?? 0) > 0 ? "p\(entry.partials!)" : nil, action: onReps)
                field(value: entry.rating(rating).map { "\($0)" }, ghost: ghost?.rating(rating).map { "\($0)" }, suffix: nil, action: onRating)
                    .frame(width: 48)
                    .accessibilityLabel("\(rating.title) for set \(label)")

                Button(action: onCheck) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(done ? p.accent : p.elevated)
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(done ? .clear : p.border, lineWidth: 2)
                        if done { Image(systemName: "checkmark").font(.system(size: 18, weight: .heavy)).foregroundStyle(p.onAccent) }
                    }
                    .frame(width: 48, height: 50)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(done ? "Set \(label) done" : "Mark set \(label) done")
            }
            HStack(spacing: 8) {
                if entry.bar != nil { Text(entry.bar == .ez ? "EZ bar" : "Straight bar").font(.system(size: 11, weight: .semibold)).foregroundStyle(p.muted) }
                if improved { Text("✓ beat last time").font(.system(size: 11, weight: .bold)).foregroundStyle(p.accent) }
                if let n = entry.note, !n.isEmpty { Text(n).font(.system(size: 11)).foregroundStyle(p.muted).lineLimit(1) }
                Spacer()
            }
            .padding(.leading, 50)
            .frame(minHeight: (entry.bar != nil || improved || entry.note?.isEmpty == false) ? 14 : 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
        .background(p.card)
        .offset(x: dx)
        .background(alignment: .trailing) {
            if dx < 0 {
                HStack(spacing: 8) {
                    Image(systemName: "trash").font(.system(size: 16, weight: .bold))
                    Text("Delete").font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .background(Self.deleteRed)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .simultaneousGesture(swipe)
        .onChange(of: pendingDelete) { _, pending in
            if !pending { withAnimation(.snappy) { dx = 0 } }
        }
        .accessibilityAction(named: "Delete set") { onDelete() }
    }

    /// A full swipe left asks to delete. A short one springs back, so a pocket brush does nothing.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { g in
                if horizontal == nil { horizontal = abs(g.translation.width) > abs(g.translation.height) * 1.5 }
                guard horizontal == true else { return }
                dx = min(0, g.translation.width)
            }
            .onEnded { g in
                defer { horizontal = nil }
                guard horizontal == true else { return }
                let far = width > 0 && (g.translation.width < -width * 0.55 || g.predictedEndTranslation.width < -width * 0.9)
                if far {
                    withAnimation(.snappy) { dx = -width }
                    onDelete()
                } else {
                    withAnimation(.snappy) { dx = 0 }
                }
            }
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
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Any rep range, for when the presets do not fit. Saves to the variation.
struct RepRangeSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let versionId: String
    @State private var lo: Int
    @State private var hi: Int

    init(version v: Version) {
        versionId = v.id
        _lo = State(initialValue: v.repMin)
        _hi = State(initialValue: v.repMax)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                column("Min", $lo)
                column("Max", $hi)
            }
            PillButton(title: "Save", style: .primary, full: true, height: 56) {
                guard var v = store.version(versionId) else { return }
                v.repMin = min(lo, hi); v.repMax = max(lo, hi)
                store.put(v)
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    private func column(_ title: String, _ value: Binding<Int>) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(p.secondary)
            WheelPicker(values: Array(1...40), selection: value) { "\($0)" }
        }
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
