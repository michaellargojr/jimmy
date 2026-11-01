import SwiftUI

// The two picture pickers: cable height on the athletic figure, bench angle on the bench.
// The pictures themselves live in PickerArt.swift.

/// Where each height sits on the 1000 tall figure.
private let HEIGHT_Y: [CableHeight: CGFloat] = [
    .overhead: -40, .head: 70, .shoulder: 200, .chest: 268, .waist: 450, .hip: 530, .thigh: 640, .knee: 772, .shin: 868, .ankle: 950,
]

/// Tap a height. Each whole row is the target, so a sweaty tap still lands. One tap picks and closes.
struct CableHeightPicker: View {
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    var picked: CableHeight?
    let onPick: (CableHeight?) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Cable height").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                Spacer()
                if picked != nil {
                    Button("Clear") { onPick(nil); dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.muted)
                }
                Button("Close") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
            }
            GeometryReader { geo in
                // Art box: labels left of x -60, figure in x 0...490, heights from y -110 to 1000.
                let s = min(geo.size.width / 740, geo.size.height / 1110)
                let x0 = (geo.size.width - 740 * s) / 2 + 240 * s
                let y0 = 110 * s   // sit right under the title
                ZStack(alignment: .topLeading) {
                    AthleteFigure()
                        .frame(width: 490 * s, height: 1000 * s)
                        .offset(x: x0, y: y0)
                    ForEach(Array(CableHeight.allCases.enumerated()), id: \.element) { i, h in
                        heightRow(h, index: i, s: s, x0: x0, y0: y0, width: geo.size.width)
                    }
                }
            }
        }
        .padding(16)
    }

    private func heightRow(_ h: CableHeight, index i: Int, s: CGFloat, x0: CGFloat, y0: CGFloat, width: CGFloat) -> some View {
        let all = CableHeight.allCases
        let y = HEIGHT_Y[h] ?? 0
        let top = i == 0 ? y - 60 : (y + (HEIGHT_Y[all[i - 1]] ?? 0)) / 2
        let bottom = i == all.count - 1 ? y + 50 : (y + (HEIGHT_Y[all[i + 1]] ?? 0)) / 2
        let lineY = (y - top) * s
        let on = picked == h
        let bar = max(6, 14 * s)
        return Button { onPick(h); dismiss() } label: {
            ZStack(alignment: .topLeading) {
                Color.clear
                if on {
                    RoundedRectangle(cornerRadius: bar / 2, style: .continuous).fill(p.accent)
                        .frame(width: 552 * s, height: bar)
                        .offset(x: x0 - 62 * s, y: lineY - bar / 2)
                } else {
                    Rectangle().fill(p.border)
                        .frame(width: 56 * s, height: 1.5)
                        .offset(x: x0 - 60 * s, y: lineY - 0.75)
                }
                Text(h.label.replacingOccurrences(of: " height", with: ""))
                    .font(.system(size: on ? 17 : 15, weight: on ? .heavy : .semibold))
                    .foregroundStyle(on ? p.accent : p.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: max(0, x0 - 74 * s), height: 24, alignment: .trailing)
                    .offset(y: lineY - 12)
            }
            .frame(width: width, height: (bottom - top) * s, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(y: y0 + top * s)
    }
}

/// Pick a bench notch. Chips set the angle; the bench swings to it; Done keeps it.
struct BenchAnglePicker: View {
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State var angle: Int
    let onPick: (Int?) -> Void

    init(picked: Int?, onPick: @escaping (Int?) -> Void) {
        _angle = State(initialValue: picked ?? 0); self.onPick = onPick
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Bench angle").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                Spacer()
                Button("Clear") { onPick(nil); dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.muted)
                Button("Close") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
            }
            BenchDrawing(angle: Double(angle))
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .animation(.snappy(duration: 0.3), value: angle)
            Text(benchAngleLabel(angle)).font(.system(size: 28, weight: .heavy)).foregroundStyle(p.text)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(BENCH_ANGLES, id: \.self) { a in
                    Button { angle = a } label: {
                        Text(benchAngleLabel(a))
                            .font(.system(size: 15, weight: angle == a ? .bold : .semibold))
                            .foregroundStyle(angle == a ? p.onAccent : p.text)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(angle == a ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            PillButton(title: "Done", style: .primary, full: true) { onPick(angle); dismiss() }
            Spacer()
        }
        .padding(16)
    }
}

let ATTACHMENTS = ["rope", "straight bar", "EZ attachment", "D handle", "V bar", "cuff", "ankle strap"]
let GRIPS = ["overhand", "underhand", "neutral", "wide", "close"]

/// The Style block: only the fields that apply to the variation show.
struct StyleFields: View {
    @Environment(\.palette) private var p
    let family: EquipmentFamily
    let position: Position?
    @Binding var spec: StyleSpec
    /// Off while a new machine is being named: the name goes on the variation instead.
    var showsMachineName: Bool = true
    @State private var heightPicker = false
    @State private var benchPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if family == .cable {
                chips(ATTACHMENTS, pick: spec.attachment) { spec.attachment = toggle(spec.attachment, $0) }
                pickerRow(spec.cableHeight?.label ?? "Height", on: spec.cableHeight != nil, symbol: "figure.stand") { heightPicker = true }
            }
            if family == .bar {
                HStack(spacing: 8) {
                    ForEach(BarType.allCases, id: \.self) { b in
                        Chip(text: b.label, on: spec.barType == b, small: true) { spec.barType = spec.barType == b ? nil : b }
                    }
                }
            }
            if family == .machine && showsMachineName {
                TextField("Machine name", text: Binding(get: { spec.machine ?? "" }, set: { spec.machine = $0.isEmpty ? nil : $0 }))
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .padding(.horizontal, 12).frame(height: 40)
                    .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .foregroundStyle(p.text)
            }
            if position?.usesBench == true {
                pickerRow(spec.benchAngle.map { benchAngleLabel($0) } ?? "Bench angle", on: spec.benchAngle != nil, symbol: "angle") { benchPicker = true }
            }
            chips(GRIPS, pick: spec.grip) { spec.grip = toggle(spec.grip, $0) }
        }
        .sheet(isPresented: $heightPicker) {
            CableHeightPicker(picked: spec.cableHeight) { spec.cableHeight = $0 }
                .presentationDetents([.large]).presentationBackground(p.card)
        }
        .sheet(isPresented: $benchPicker) {
            BenchAnglePicker(picked: spec.benchAngle) { spec.benchAngle = $0 }
                .presentationDetents([.large]).presentationBackground(p.card)
        }
    }

    private func toggle(_ current: String?, _ value: String) -> String? { current == value ? nil : value }

    private func chips(_ options: [String], pick: String?, action: @escaping (String) -> Void) -> some View {
        FlowRow(spacing: 8, lineSpacing: 8) {
            ForEach(options, id: \.self) { o in Chip(text: capitalized(o), on: pick == o, small: true) { action(o) } }
        }
    }

    private func pickerRow(_ text: String, on: Bool, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 14, weight: .bold))
                Text(text).font(.system(size: 14, weight: on ? .bold : .semibold))
                Spacer()
                Chevron()
            }
            .foregroundStyle(on ? p.accent : p.text)
            .padding(.horizontal, 12).frame(height: 44)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The Variation block: family, arms, position.
struct VariationFields: View {
    @Environment(\.palette) private var p
    let legs: Bool
    @Binding var spec: VariationSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowRow(spacing: 8, lineSpacing: 8) {
                ForEach(EquipmentFamily.allCases, id: \.self) { f in
                    Chip(text: f.label, on: spec.family == f, small: true) { spec.family = f }
                }
            }
            HStack(spacing: 8) {
                Chip(text: capitalized(Arms.two.label(legs: legs)), on: spec.arms == .two, small: true) { spec.arms = .two }
                Chip(text: capitalized(Arms.one.label(legs: legs)), on: spec.arms == .one, small: true) { spec.arms = .one }
            }
            FlowRow(spacing: 8, lineSpacing: 8) {
                ForEach(Position.allCases, id: \.self) { pos in
                    Chip(text: capitalized(pos.label), on: spec.position == pos, small: true) { spec.position = spec.position == pos ? nil : pos }
                }
            }
        }
    }
}
