import SwiftUI

/// The set entry sheet: three big tabs (Weight, Reps, and Activation or Intensity), one big control under them,
/// a big Add note button, then Next set and Done. Every change saves as it is made, and Next set
/// or Done logs the set with what the wheels show.
struct SetPickerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let workoutId: String
    let itemId: String
    @State var setId: String
    @State var field: ExerciseCardView.SetField

    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var partials: Int = 0
    @State private var loadedFor: String? = nil
    @State private var writingNote = false
    @State private var draft = ""
    @State private var logged = 0
    @FocusState private var noteFocused: Bool

    private static let height: CGFloat = 520

    private var item: WorkoutItem? { store.workout(workoutId)?.items.first { $0.id == itemId } }
    private var set: SetEntry? { item?.sets.first { $0.id == setId } }
    private var version: Version? { item.flatMap { store.version($0.versionId) } }

    var body: some View {
        // A ZStack, not a Group: a Group hands its modifiers to its children, so the detents
        // below would be lost on any pass where the set can't be found.
        ZStack {
            if let item, let s = set, let v = version {
                if writingNote {
                    noteEditor
                } else {
                    let idx = item.sets.firstIndex { $0.id == setId } ?? 0
                    VStack(spacing: 14) {
                        tabs
                        Group {
                            if loadedFor == setId {
                                switch field {
                                case .weight: weightPane(s, v)
                                case .reps: repsPane(s)
                                case .rating: ratingPane(s)
                                }
                            }
                        }
                        .id(setId + field.rawValue)
                        .frame(height: 236)
                        noteButton(s)
                        HStack(spacing: 10) {
                            if idx + 1 < item.sets.count {
                                PillButton(title: "Next set →", full: true, height: 56) { logShown(); go(to: item.sets[idx + 1].id) }
                            }
                            PillButton(title: "Done", style: .primary, full: true, height: 56) { logShown(); dismiss() }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .presentationDetents(writingNote ? [.large] : [.height(Self.height)])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.impact(weight: .medium), trigger: logged)
        .onAppear { if loadedFor == nil { load() } }
    }

    // MARK: Tabs

    private var tabs: some View {
        HStack(spacing: 8) {
            tab(.weight, "Weight")
            tab(.reps, "Reps")
            tab(.rating, store.settings.rating.title)
        }
    }

    private func tab(_ f: ExerciseCardView.SetField, _ title: String) -> some View {
        let on = field == f
        return Button { select(f) } label: {
            Text(title).font(.system(size: 18, weight: .heavy))
                .foregroundStyle(on ? p.onAccent : p.text)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity).frame(height: 60)
                .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Panes

    private func weightPane(_ s: SetEntry, _ v: Version) -> some View {
        VStack(spacing: 12) {
            WheelPicker(values: weightValues(s.unit), selection: $weight, rowHeight: 37) { "\(fmtWeight($0)) \(s.unit.label)" }
                .onChange(of: weight) { _, w in patch { $0.weight = w } }
            HStack(spacing: 8) {
                Chip(text: s.unit.label) { patch { $0.unit = $0.unit == .kg ? .lbs : .kg } }
                if v.isBarbell {
                    Chip(text: s.bar == .ez ? "EZ bar" : "Straight bar") { patch { $0.bar = $0.bar == .ez ? .straight : .ez } }
                }
                Spacer()
            }
        }
    }

    private func repsPane(_ s: SetEntry) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("Full reps").font(.system(size: 15, weight: .bold)).foregroundStyle(p.secondary)
                WheelPicker(values: Array(0...40), selection: $reps) { "\($0)" }
                    .overlay(alignment: .trailing) { plusToggle(s).padding(.trailing, 6) }
                    .onChange(of: reps) { _, r in patch { $0.reps = r } }
            }
            VStack(spacing: 8) {
                Text("Partials").font(.system(size: 15, weight: .bold)).foregroundStyle(p.secondary)
                WheelPicker(values: Array(0...10), selection: $partials) { "\($0)" }
                    .onChange(of: partials) { _, n in patch { $0.partials = n == 0 ? nil : n } }
            }
        }
    }

    /// "+" right next to the reps number: at least this many.
    private func plusToggle(_ s: SetEntry) -> some View {
        Button { patch { $0.plus.toggle() } } label: {
            Text("+").font(.system(size: 22, weight: .heavy))
                .foregroundStyle(s.plus ? p.onAccent : p.secondary)
                .frame(width: 44, height: 36)
                .background(s.plus ? p.accent : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(s.plus ? .clear : p.border, lineWidth: 2))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("At least")
        .accessibilityAddTraits(s.plus ? .isSelected : [])
    }

    /// Activation (or Intensity, per Settings): three big buttons, the number with its word.
    /// Tapping the lit one clears it.
    private func ratingPane(_ s: SetEntry) -> some View {
        let r = store.settings.rating
        let current = s.rating(r)
        return HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { n in
                let on = current == n
                Button { patch { $0.setRating(r, on ? nil : n) } } label: {
                    VStack(spacing: 8) {
                        Text("\(n)").font(.system(size: 52, weight: .heavy)).monospacedDigit()
                        Text(r.words[n - 1]).font(.system(size: 16, weight: .bold))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(on ? p.onAccent : p.text)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity).frame(height: 168)
                    .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(r.title) \(n), \(r.words[n - 1])")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .frame(maxHeight: .infinity)
        .sensoryFeedback(.selection, trigger: current)
    }

    // MARK: Note

    private func noteButton(_ s: SetEntry) -> some View {
        let has = s.note?.isEmpty == false
        return Button { draft = s.note ?? ""; writingNote = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil").font(.system(size: 16, weight: .bold))
                Text(has ? s.note! : "Add note").lineLimit(1)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(has ? p.text : p.secondary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The note field, already focused so the keyboard is up and the cursor is in it.
    private var noteEditor: some View {
        VStack(spacing: 14) {
            TextField("", text: $draft, axis: .vertical)
                .focused($noteFocused)
                .lineLimit(4...8)
                .font(.system(size: 17))
                .foregroundStyle(p.text)
                .tint(p.accent)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { noteFocused = true }
                .keepsKeyboard()
            PillButton(title: "Save", style: .primary, full: true, height: 56) {
                let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                patch { $0.note = t.isEmpty ? nil : t }
                noteFocused = false
                writingNote = false
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .task {
            try? await Task.sleep(for: .milliseconds(80))
            noteFocused = true
        }
    }

    // MARK: State

    /// Start the wheels on what this set has, else last time's matching set, else the set before it.
    private func load() {
        guard let item, let s = set, let v = version else { return }
        let last = lastSession(versionId: v.id, styleId: item.styleId, workouts: store.workouts, versions: store.versions, excludeWorkoutId: workoutId)
        let ghost = last.flatMap { matchLast(now: s, nowAll: item.sets, lastAll: $0.item.sets) }
        let idx = item.sets.firstIndex { $0.id == setId } ?? 0
        let before = item.sets.prefix(idx).last { $0.weight != nil }
        weight = s.weight ?? ghost?.weight ?? before?.weight ?? last?.item.sets.first { $0.kind == .working && $0.weight != nil }?.weight ?? 0
        reps = s.reps ?? ghost?.reps ?? store.workout(workoutId).flatMap { store.repRange(item, in: $0) }?.hi ?? v.repMax
        partials = s.partials ?? 0
        loadedFor = setId
    }

    /// Next set and Done log the set: any number still blank takes what its wheel shows,
    /// so a quick Done after a glance at the wheels is enough. Bodyweight never logs a 0 kg.
    private func logShown() {
        guard let s = set, let v = version else { return }
        let w = weight, r = reps
        let addWeight = s.weight == nil && !(v.family == .body && w == 0)
        guard addWeight || s.reps == nil else { return }
        patch {
            if addWeight { $0.weight = w }
            if $0.reps == nil { $0.reps = r }
        }
        logged += 1
    }

    private func select(_ f: ExerciseCardView.SetField) {
        field = f
    }

    private func go(to id: String) {
        setId = id
        load()
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

/// A wheel like the system one, built on a snapping scroll view so two can sit side by side
/// without stealing each other's touches. Tap a row to jump to it.
struct WheelPicker<V: Hashable>: View {
    @Environment(\.palette) private var p
    let values: [V]
    @Binding var selection: V
    var rowHeight: CGFloat
    let label: (V) -> String
    @State private var scrolled: V?
    /// Off until the wheel has scrolled to the starting value, so the first layout (which sits at
    /// the top of the list) never writes the top value back.
    @State private var ready = false

    init(values: [V], selection: Binding<V>, rowHeight: CGFloat = 40, label: @escaping (V) -> String) {
        self.values = values
        self._selection = selection
        self.rowHeight = rowHeight
        self.label = label
        self._scrolled = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        let rh = rowHeight
        // Rows fade and shrink by their distance from the one in the band.
        let at = values.firstIndex(of: scrolled ?? selection) ?? 0
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(Array(values.enumerated()), id: \.element) { i, v in
                        // Worked out before the modifier chain: with the literals and CGFloat mixed in
                        // there, Xcode 26's type-checker gave up ("unable to type-check in reasonable time").
                        let d = Double(abs(i - at))
                        let fade = max(0.25, 1 - d * 0.32)
                        let shrink = CGFloat(max(0.76, 1 - d * 0.1))
                        Text(label(v))
                            .font(.system(size: 26, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(p.text)
                            .frame(maxWidth: .infinity).frame(height: rh)
                            .opacity(fade)
                            .scaleEffect(shrink)
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.snappy) { scrolled = v } }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.vertical, rh * 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolled, anchor: .center)
            .frame(height: rh * 5)
            .background {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(p.elevated).frame(height: rh + 6)
            }
            .clipped()
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
                DispatchQueue.main.async {
                    proxy.scrollTo(selection, anchor: .center)
                    scrolled = selection
                    ready = true
                }
            }
            .onChange(of: scrolled) { _, v in if ready, let v, v != selection { selection = v } }
            .onChange(of: selection) { _, v in if v != scrolled { scrolled = v } }
            .sensoryFeedback(.selection, trigger: scrolled) { _, _ in ready }
        }
    }
}
