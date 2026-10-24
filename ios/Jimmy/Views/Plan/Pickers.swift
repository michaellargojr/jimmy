import SwiftUI

// The two picture pickers: cable height on a full silhouette, bench angle on a bench.

/// The approved V2 athletic figure, drawn in a 200 by 500 box.
struct SilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / 200, rect.height / 500)
        let ox = rect.midX - 100 * s, oy = rect.minY
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
        var p = Path()
        p.move(to: P(88, 64)); p.addLine(to: P(112, 64)); p.addLine(to: P(112, 76)); p.addLine(to: P(146, 86))
        p.addQuadCurve(to: P(160, 102), control: P(158, 90)); p.addLine(to: P(186, 236))
        p.addQuadCurve(to: P(174, 256), control: P(188, 252)); p.addQuadCurve(to: P(156, 244), control: P(160, 258))
        p.addLine(to: P(132, 134)); p.addLine(to: P(128, 200)); p.addLine(to: P(134, 250)); p.addLine(to: P(146, 484))
        p.addQuadCurve(to: P(134, 496), control: P(146, 496)); p.addLine(to: P(112, 496)); p.addLine(to: P(110, 484))
        p.addLine(to: P(100, 310)); p.addLine(to: P(90, 484)); p.addLine(to: P(88, 496)); p.addLine(to: P(66, 496))
        p.addQuadCurve(to: P(54, 484), control: P(54, 496)); p.addLine(to: P(66, 250)); p.addLine(to: P(72, 200)); p.addLine(to: P(68, 134))
        p.addLine(to: P(44, 244)); p.addQuadCurve(to: P(26, 256), control: P(40, 258)); p.addQuadCurve(to: P(14, 236), control: P(12, 252))
        p.addLine(to: P(40, 102)); p.addQuadCurve(to: P(54, 86), control: P(42, 90)); p.addLine(to: P(88, 76)); p.closeSubpath()
        p.addEllipse(in: CGRect(x: ox + 72 * s, y: oy + 8 * s, width: 56 * s, height: 56 * s))
        return p
    }
}

/// Where each height sits on the 500 tall figure.
private let HEIGHT_Y: [CableHeight: CGFloat] = [
    .overhead: 6, .head: 36, .shoulder: 88, .chest: 130, .waist: 192, .hip: 245, .thigh: 300, .knee: 370, .shin: 430, .ankle: 484,
]

/// Tap a point on the figure. One tap picks and closes.
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
                let h = geo.size.height - 24
                let s = h / 500
                let figureW: CGFloat = 200 * s
                let left: CGFloat = 8
                ZStack(alignment: .topLeading) {
                    SilhouetteShape().fill(p.isDark ? Color(hex: 0xD7D9DE) : Color(hex: 0x6B7280))
                        .frame(width: figureW, height: h)
                        .offset(x: left, y: 12)
                    ForEach(CableHeight.allCases, id: \.self) { hgt in
                        let y = (HEIGHT_Y[hgt] ?? 0) * s + 12
                        let on = picked == hgt
                        Button { onPick(hgt); dismiss() } label: {
                            HStack(spacing: 0) {
                                Rectangle().fill(on ? p.accent : p.border).frame(width: 36, height: 2)
                                Text(hgt.label.replacingOccurrences(of: " height", with: ""))
                                    .font(.system(size: 15, weight: on ? .bold : .semibold))
                                    .foregroundStyle(on ? p.onAccent : p.text)
                                    .frame(height: 38)
                                    .padding(.horizontal, 14)
                                    .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .offset(x: left + figureW - 4, y: y - 19)
                        if on {
                            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(p.accent)
                                .frame(width: figureW * 0.9, height: 4)
                                .offset(x: left + figureW * 0.05, y: y - 2)
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

/// The approved V1 bench: rail, two posts, seat, and a back pad that rotates to the angle.
struct BenchShape: View {
    @Environment(\.palette) private var p
    let angle: Int
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 300, size.height / 220)
            let ox = (size.width - 300 * s) / 2, oy = (size.height - 220 * s) / 2
            func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 4) -> Path {
                Path(roundedRect: CGRect(x: ox + x * s, y: oy + y * s, width: w * s, height: h * s), cornerRadius: r * s)
            }
            let frame = p.border, seat = p.secondary
            ctx.fill(R(35, 196, 230, 10, 5), with: .color(frame))
            ctx.fill(R(64, 150, 10, 50, 3), with: .color(frame))
            ctx.fill(R(146, 150, 10, 50, 3), with: .color(frame))
            ctx.fill(R(45, 132, 110, 22, 6), with: .color(seat))
            var pad = ctx
            pad.translateBy(x: ox + 155 * s, y: oy + 143 * s)
            pad.rotate(by: .degrees(Double(-angle)))
            pad.translateBy(x: -(ox + 155 * s), y: -(oy + 143 * s))
            pad.fill(R(155, 132, 110, 22, 6), with: .color(p.accent))
        }
    }
}

/// Pick a bench notch. Chips set the angle; the bench shows it; Done keeps it.
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
            BenchShape(angle: angle)
                .frame(height: 200)
                .animation(.snappy(duration: 0.25), value: angle)
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
            if family == .machine {
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { o in Chip(text: capitalized(o), on: pick == o, small: true) { action(o) } }
            }
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EquipmentFamily.allCases, id: \.self) { f in
                        Chip(text: f.label, on: spec.family == f, small: true) { spec.family = f }
                    }
                }
            }
            HStack(spacing: 8) {
                Chip(text: capitalized(Arms.two.label(legs: legs)), on: spec.arms == .two, small: true) { spec.arms = .two }
                Chip(text: capitalized(Arms.one.label(legs: legs)), on: spec.arms == .one, small: true) { spec.arms = .one }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Position.allCases, id: \.self) { pos in
                        Chip(text: capitalized(pos.label), on: spec.position == pos, small: true) { spec.position = spec.position == pos ? nil : pos }
                    }
                }
            }
        }
    }
}
