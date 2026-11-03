import SwiftUI

/// Tapping an exercise's rep range: the templates boxed with each one's numbers for this
/// exercise, the number presets under them, then Custom. Every pick is for this workout only.
struct RepRangePicker: View {
    @Environment(\.palette) private var p
    /// Each template's numbers for this exercise.
    let ranges: [RepTemplate: RepRange]
    /// The ticked template; nil when the exercise is on numbers of its own.
    let picked: RepTemplate?
    let current: RepRange
    /// Holds keep their own range, so they get the numbers only.
    var templates: Bool = true
    let onTemplate: (RepTemplate) -> Void
    let onRange: (RepRange) -> Void
    let onCustom: () -> Void
    /// The menu's full height, measured. The popover asks for this much, and when the screen has
    /// less room under the button (a 375-wide phone, or the button low on the screen) it gets what
    /// fits and the menu scrolls, so Custom is never cut off out of reach.
    @State private var fullHeight: CGFloat = 400

    var body: some View {
        ScrollView(.vertical) {
            menu.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 300)
        .frame(idealHeight: fullHeight)
    }

    private var menu: some View {
        VStack(spacing: 0) {
            if templates {
                VStack(spacing: 0) {
                    ForEach(RepTemplate.allCases) { t in templateRow(t) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(p.border, lineWidth: 1.5))
                .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 12)
                divider
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(REP_PRESETS, id: \.self) { r in
                    let on = picked == nil && r == current
                    Button { onRange(r) } label: {
                        Text(r.text).font(.system(size: 16, weight: .bold)).monospacedDigit()
                            .foregroundStyle(on ? p.onAccent : p.text)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 12)
            divider
            Button(action: onCustom) {
                Text("Custom…").font(.system(size: 17, weight: .semibold)).foregroundStyle(p.text)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func templateRow(_ t: RepTemplate) -> some View {
        Button { onTemplate(t) } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(p.accent)
                    .opacity(picked == t ? 1 : 0).frame(width: 16)
                Text(t.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(p.text)
                Spacer()
                Text((ranges[t] ?? current).text).font(.system(size: 18, weight: .heavy)).monospacedDigit().foregroundStyle(p.accent)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { if t != RepTemplate.allCases.last { Rectangle().fill(p.border).frame(height: 1) } }
        .accessibilityLabel("\(t.title), \((ranges[t] ?? current).text)")
        .accessibilityAddTraits(picked == t ? .isSelected : [])
    }

    private var divider: some View { Rectangle().fill(p.border).frame(height: 1).padding(.horizontal, 10) }
}

/// The gear: one template for the whole workout, and what each exercise will work to.
/// Picking one starts every exercise over on it, so the list is always the truth.
struct WorkoutRepRangesSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let workoutId: String

    var body: some View {
        if let w = store.workout(workoutId) {
            let on = w.repTemplate ?? .standard
            VStack(alignment: .leading, spacing: 16) {
                Text("Rep ranges").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                HStack(spacing: 8) {
                    ForEach(RepTemplate.allCases) { t in
                        Button { store.setRepTemplate(t, workoutId: workoutId) } label: {
                            Text(t.title).font(.system(size: 16, weight: .bold))
                                .foregroundStyle(t == on ? p.onAccent : p.text)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(t == on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(t == on ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: on)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(w.items.enumerated()), id: \.element.id) { i, item in
                            if let v = store.version(item.versionId), let r = store.repRange(item, in: w) {
                                HStack(spacing: 12) {
                                    Text(store.workoutName(v)).font(.system(size: 16, weight: .bold)).foregroundStyle(p.text)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                    if let n = store.nickname(v) { NicknameTag(text: n, size: .small) }
                                    Spacer(minLength: 8)
                                    Text(r.text).font(.system(size: 18, weight: .heavy)).monospacedDigit().foregroundStyle(p.accent)
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 50)
                                .overlay(alignment: .top) { if i > 0 { Rectangle().fill(p.line).frame(height: 1) } }
                            }
                        }
                    }
                    .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .frame(maxHeight: .infinity, alignment: .top)
            .presentationDragIndicator(.visible)
        }
    }
}

/// Any rep range, for when the presets do not fit.
struct RepRangeSheet: View {
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let onSave: (RepRange) -> Void
    @State private var lo: Int
    @State private var hi: Int

    init(range: RepRange, onSave: @escaping (RepRange) -> Void) {
        self.onSave = onSave
        _lo = State(initialValue: range.lo)
        _hi = State(initialValue: range.hi)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                column("Min", $lo)
                column("Max", $hi)
            }
            PillButton(title: "Save", style: .primary, full: true, height: 56) {
                onSave(RepRange(lo, hi))
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
