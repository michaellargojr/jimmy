import SwiftUI

// Shared building blocks. Everything is a rounded rectangle: no circles anywhere.

struct Card<Content: View>: View {
    @Environment(\.palette) private var p
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// A variation as one collectible chip: its words in the theme color inside one outline, with a
/// thin line between them, because together they make the variation ("Cable | Two arms").
/// The muscle tags stay grey; color marks what you chose. A chip too long for one line breaks
/// onto two inside the same outline, always between the machine and how you use it:
/// "Machine | Plates | High row" over "Two arms | Arms behind".
struct VariationPill: View {
    enum Size { case small, regular, large }
    @Environment(\.palette) private var p
    let parts: [String]
    var size: Size = .regular

    private struct Metrics { let font, height, pad, radius, line: CGFloat }
    private func metrics(_ size: Size) -> Metrics {
        switch size {
        case .small: return Metrics(font: 12.5, height: 24, pad: 8, radius: 7, line: 1)
        case .regular: return Metrics(font: 14, height: 30, pad: 11, radius: 8, line: 1.5)
        case .large: return Metrics(font: 15, height: 32, pad: 12, radius: 9, line: 1.5)
        }
    }

    /// Where how you use it starts (arms, then position). With none, the middle.
    private var breakIndex: Int? {
        guard parts.count > 1 else { return nil }
        let how = Set([Arms.two, .one].flatMap { [$0.label(legs: false), $0.label(legs: true)] } + Position.allCases.map(\.label))
        if let i = parts.firstIndex(where: { how.contains($0.lowercased()) }), i > 0 { return i }
        return (parts.count + 1) / 2
    }

    /// One line when there's room; else two lines at its own size, then two small lines, and only
    /// as a last resort smaller words, so it never runs past the edge.
    var body: some View {
        let two: [[String]] = breakIndex.map { [Array(parts[..<$0]), Array(parts[$0...])] } ?? [parts]
        ViewThatFits(in: .horizontal) {
            chip([parts], size).fixedSize(horizontal: true, vertical: false)
            chip(two, size).fixedSize(horizontal: true, vertical: false)
            chip(two, .small).fixedSize(horizontal: true, vertical: false)
            chip(two, .small, squeeze: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(parts.joined(separator: ", "))
    }

    private func chip(_ rows: [[String]], _ size: Size, squeeze: Bool = false) -> some View {
        let m = metrics(size)
        let stacked = rows.count > 1
        let rowHeight = stacked ? m.height - 4 : m.height
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, words in
                HStack(spacing: 0) {
                    ForEach(Array(words.enumerated()), id: \.offset) { i, t in
                        if i > 0 {
                            Rectangle().fill(p.accent.opacity(0.45)).frame(width: m.line).padding(.vertical, (rowHeight * 0.23).rounded())
                        }
                        Text(t).font(.system(size: m.font, weight: .heavy)).foregroundStyle(p.accent).lineLimit(1)
                            .minimumScaleFactor(squeeze ? 0.6 : 1)
                            .padding(.horizontal, squeeze ? 6 : m.pad)
                    }
                }
                .frame(height: rowHeight)
            }
        }
        .padding(.vertical, stacked ? 2 : 0)
        .overlay(RoundedRectangle(cornerRadius: m.radius, style: .continuous).strokeBorder(p.accent.opacity(0.7), lineWidth: m.line))
    }
}

/// A variation's chip with an optional quiet note after it ("Rope", "3 Workouts - Last Oct 23"); the note
/// drops to the next line when there isn't room.
struct VariationChips: View {
    @Environment(\.palette) private var p
    let tags: [String]
    var size: VariationPill.Size = .regular
    var note: String? = nil
    /// The variation's nickname, as a tag before the chip ("Bayesian Curl").
    var nickname: String? = nil
    var body: some View {
        FlowRow(spacing: 8, lineSpacing: 5) {
            if let nickname { NicknameTag(text: nickname, size: size) }
            if !tags.isEmpty { VariationPill(parts: tags, size: size) }
            if let note, !note.isEmpty {
                Text(note).font(.system(size: size == .small ? 12.5 : 14, weight: .semibold)).foregroundStyle(p.muted).lineLimit(1)
            }
        }
    }
}

/// A nickname as a soft tag in the theme color ("Bayesian Curl"), beside the plain name. Filled
/// softly so it never reads as the outlined variation chip or the solid group chip.
struct NicknameTag: View {
    @Environment(\.palette) private var p
    let text: String
    var size: VariationPill.Size = .regular

    var body: some View {
        let m: (font: CGFloat, height: CGFloat, pad: CGFloat, radius: CGFloat) = {
            switch size {
            case .small: return (12.5, 24, 8, 7)
            case .regular: return (14, 30, 11, 8)
            case .large: return (15, 32, 12, 9)
            }
        }()
        Text(text)
            .font(.system(size: m.font, weight: .heavy)).foregroundStyle(p.accent).lineLimit(1)
            .padding(.horizontal, m.pad).frame(height: m.height)
            .background(p.accentSoft, in: RoundedRectangle(cornerRadius: m.radius, style: .continuous))
            .fixedSize()
            .accessibilityLabel("Nickname, \(text)")
    }
}

/// A title with its nickname tag. Both sit on one line when they fit; the title may shrink a
/// little first, as titles already do, and only then does the tag drop under it.
struct NamedTitle: View {
    @Environment(\.palette) private var p
    let name: String
    let nickname: String?
    let size: CGFloat
    var tag: VariationPill.Size = .large

    var body: some View {
        if let nickname {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { title(size).fixedSize(); NicknameTag(text: nickname, size: tag) }
                HStack(spacing: 10) { title(size * NamedTitle.squeeze).fixedSize(); NicknameTag(text: nickname, size: tag) }
                VStack(alignment: .leading, spacing: 6) {
                    title(size).lineLimit(2).minimumScaleFactor(0.8)
                    NicknameTag(text: nickname, size: tag)
                }
            }
        } else {
            title(size).lineLimit(2).minimumScaleFactor(0.8)
        }
    }

    /// How far the title may shrink to keep its tag on the same line.
    static let squeeze: CGFloat = 0.88

    private func title(_ s: CGFloat) -> some View {
        Text(name).font(.system(size: s, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
    }
}

/// The Nickname field: what you type, with a clear button. Empty means none.
struct NicknameField: View {
    @Environment(\.palette) private var p
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            TextField("None", text: $text)
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(p.text)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .submitLabel(.done)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(p.secondary)
                        .frame(width: 36, height: 36)
                        .background(p.isDark ? Color(hex: 0x2A2C31) : p.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear nickname")
            }
        }
        .padding(.leading, 14).padding(.trailing, 6)
        .frame(height: 48)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }
}

struct SectionLabel: View {
    @Environment(\.palette) private var p
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(p.muted)
    }
}

extension ScreenTitle where Trailing == EmptyView {
    init(_ title: String) { self.init(title, trailing: { EmptyView() }) }
}

struct ScreenTitle<Trailing: View>: View {
    @Environment(\.palette) private var p
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title; self.trailing = trailing
    }
    var body: some View {
        HStack(alignment: .center) {
            Text(title).font(.system(size: 34, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

enum PillStyle { case primary, secondary, danger }

struct PillButton: View {
    @Environment(\.palette) private var p
    let title: String
    var style: PillStyle = .secondary
    var icon: String? = nil
    var full: Bool = false
    var height: CGFloat = 44
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(.system(size: height > 50 ? 18 : 16, weight: style == .primary ? .bold : .semibold))
            }
            .frame(maxWidth: full ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, 18)
            .foregroundStyle(fg)
            .background(bg, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    private var bg: Color {
        switch style {
        case .primary: return p.accent
        case .secondary: return p.elevated
        case .danger: return p.dangerSoft
        }
    }
    private var fg: Color {
        switch style {
        case .primary: return p.onAccent
        case .secondary: return p.text
        case .danger: return p.danger
        }
    }
}

struct Chip: View {
    @Environment(\.palette) private var p
    let text: String
    var on: Bool = false
    var small: Bool = false
    var action: (() -> Void)? = nil
    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }.buttonStyle(.plain)
            } else { label }
        }
    }
    private var label: some View {
        Text(text)
            .font(.system(size: small ? 13 : 14, weight: on ? .bold : .semibold))
            .foregroundStyle(on ? p.onAccent : p.secondary)
            .frame(height: small ? 32 : 36)
            .padding(.horizontal, small ? 12 : 14)
            .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }
}

enum BadgeKind { case up, down, neutral }

struct Badge: View {
    @Environment(\.palette) private var p
    let text: String
    var kind: BadgeKind = .neutral
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(kind == .up ? p.accent : kind == .down ? p.danger : p.secondary)
            .frame(height: 28)
            .padding(.horizontal, 10)
            .background(kind == .up ? p.accentSoft : kind == .down ? p.dangerSoft : p.elevated,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct Chevron: View {
    @Environment(\.palette) private var p
    var body: some View {
        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(p.border)
    }
}

/// A square check box, filled with the accent when on.
struct RectCheck: View {
    @Environment(\.palette) private var p
    let on: Bool
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(on ? p.accent : .clear)
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(on ? p.accent : p.border, lineWidth: 2)
            if on {
                Image(systemName: "checkmark").font(.system(size: size * 0.5, weight: .heavy)).foregroundStyle(p.onAccent)
            }
        }
        .frame(width: size, height: size)
    }
}

/// A rectangular toggle (the system Toggle is a pill; this keeps the mechanical look).
struct RectToggle: View {
    @Environment(\.palette) private var p
    @Binding var on: Bool
    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { on.toggle() }
        } label: {
            ZStack(alignment: on ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? p.accent : p.border.opacity(0.6))
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(on ? p.onAccent : p.muted)
                    .frame(width: 24, height: 24)
                    .padding(4)
            }
            .frame(width: 52, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }
}

struct SettingsRow<Trailing: View>: View {
    @Environment(\.palette) private var p
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                if let subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(p.muted) }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// Lays its children out left to right and wraps to a new line when a row is full.
struct FlowRow: Layout {
    var spacing: CGFloat = 18
    var lineSpacing: CGFloat = 6

    private struct Line { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    /// A view at its own size; one wider than the row is offered the row's width, so it fits.
    private func fit(_ v: LayoutSubview, width: CGFloat) -> (size: CGSize, proposal: ProposedViewSize) {
        let ideal = v.sizeThatFits(.unspecified)
        guard width.isFinite, ideal.width > width else { return (ideal, .unspecified) }
        let proposal = ProposedViewSize(width: width, height: nil)
        return (v.sizeThatFits(proposal), proposal)
    }

    private func lines(_ subviews: Subviews, width: CGFloat) -> [Line] {
        var out = [Line()]
        for (i, v) in subviews.enumerated() {
            let size = fit(v, width: width).size
            let line = out[out.count - 1]
            let wide = line.items.isEmpty ? size.width : line.width + spacing + size.width
            if wide > width && !line.items.isEmpty {
                out.append(Line(items: [i], width: size.width, height: size.height))
            } else {
                out[out.count - 1].items.append(i)
                out[out.count - 1].width = wide
                out[out.count - 1].height = max(line.height, size.height)
            }
        }
        return out.filter { !$0.items.isEmpty }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ls = lines(subviews, width: proposal.width ?? .infinity)
        let height = ls.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, ls.count - 1))
        return CGSize(width: ls.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(subviews, width: bounds.width) {
            var x = bounds.minX
            for i in line.items {
                let (size, proposal) = fit(subviews[i], width: bounds.width)
                subviews[i].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2), proposal: proposal)
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }
}

struct Divider1: View {
    @Environment(\.palette) private var p
    var body: some View { Rectangle().fill(p.line).frame(height: 1).padding(.leading, 16) }
}

struct ScreenBackground: ViewModifier {
    @Environment(\.palette) private var p
    func body(content: Content) -> some View {
        content
            .background(p.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .toolbarBackground(p.bg, for: .navigationBar)
    }
}
extension View { func screen() -> some View { modifier(ScreenBackground()) } }

/// Style for the plain Lists used on Plan, History and Settings.
/// A search box that lives above a List, never inside it. A text field inside a List row is a
/// reusable cell: when the filtered rows below it change shape, the List rebuilds and the field
/// resigns the keyboard after the first letter.
struct SearchField: View {
    @Environment(\.palette) private var p
    var placeholder = "Search"
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.muted)
            TextField(placeholder, text: $text)
                .focused($focused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(p.text)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(p.muted).frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).frame(height: 44)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .padding(.horizontal, 16).padding(.bottom, 4)
    }
}

struct ListCardStyle: ViewModifier {
    @Environment(\.palette) private var p
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(p.bg.ignoresSafeArea())
    }
}
extension View { func cardList() -> some View { modifier(ListCardStyle()) } }

extension View {
    func rowCard(_ p: Palette, radius: CGFloat = Radius.row) -> some View {
        self.listRowBackground(
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(p.card)
                .padding(.horizontal, 16).padding(.vertical, 5)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }
}

extension Date {
    var dayKey: String { dayString(self) }
}

func monthDay(_ day: String) -> String {
    let f = DateFormatter(); f.dateFormat = "MMM d"
    return f.string(from: dayDate(day))
}
func weekdayShort(_ day: String) -> String {
    let f = DateFormatter(); f.dateFormat = "EEE"
    return f.string(from: dayDate(day)).uppercased()
}
func dayNumber(_ day: String) -> String {
    let f = DateFormatter(); f.dateFormat = "d"
    return f.string(from: dayDate(day))
}
func relativeDays(_ day: String) -> String {
    let d = daysBetween(day, today())
    switch d {
    case 0: return "Today"
    case 1: return "Yesterday"
    default: return "\(d) days ago"
    }
}
