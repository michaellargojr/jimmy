import SwiftUI
import AudioToolbox

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
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .bold)) }
                Text(title).font(.system(size: 16, weight: style == .primary ? .bold : .semibold))
            }
            .frame(maxWidth: full ? .infinity : nil)
            .frame(height: 44)
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

enum Feedback {
    static func ding(sound: Bool) {
        if sound { AudioServicesPlaySystemSound(1057) }
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
