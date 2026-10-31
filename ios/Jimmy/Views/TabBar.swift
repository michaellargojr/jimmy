import SwiftUI

/// The floating bar: Home and Plan, the Workout tile in the middle, then History and Settings.
/// The tile is the one thing in the bar with color, so it's the one that calls you.
struct JimmyTabBar: View {
    @Environment(\.palette) private var p
    @Binding var tab: AppTab
    @Namespace private var lens

    var body: some View {
        HStack(spacing: 0) {
            item(.home, "Home", "house.fill")
            item(.plan, "Plan", "square.text.square.fill")
            WorkoutTile { select(.workout) }
            item(.history, "History", "chart.xyaxis.line")
            item(.settings, "Settings", "slider.horizontal.3")
        }
        .padding(.horizontal, 4)
        .frame(height: 64)
        .modifier(FloatingGlass())
        .padding(.horizontal, 14)
        .sensoryFeedback(.selection, trigger: tab)
    }

    private func select(_ t: AppTab) {
        // Typing ends first, so a half-typed note is saved just like leaving its page.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { tab = t }
    }

    private func item(_ t: AppTab, _ title: String, _ icon: String) -> some View {
        let on = tab == t
        return Button { select(t) } label: {
            VStack(spacing: 3) {
                // The same symbols the app always had, white, with the open tab in the theme color.
                Image(systemName: icon).font(.system(size: 24, weight: .medium)).frame(height: 28)
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? p.accent : p.text)
            .frame(maxWidth: 64)
            .frame(height: 56)
            .background {
                if on {
                    Capsule().fill(p.isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.06))
                        .matchedGeometryEffect(id: "lens", in: lens)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Liquid Glass where the system has it, frosted material before that.
private struct FloatingGlass: ViewModifier {
    @Environment(\.palette) private var p

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            content.background { Color.clear.glassEffect(.regular, in: Capsule()) }
        } else {
            frosted(content)
        }
        #else
        frosted(content)
        #endif
    }

    private func frosted(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(p.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(p.isDark ? 0.5 : 0.15), radius: 18, y: 8)
    }
}

/// The Workout button, as it first was: the app's J on an orange tile with Workout under it,
/// standing a little out of the bar. Only the word glows, softly. It stays still.
struct WorkoutTile: View {
    @Environment(\.palette) private var p
    let action: () -> Void

    static let size: CGFloat = 54
    /// How far the tile stands above the bar's top edge.
    static let rise: CGFloat = 11
    /// The width the bar keeps for it.
    static let slot: CGFloat = 84

    var body: some View {
        Color.clear
            .frame(width: Self.slot, height: 64)
            .overlay(alignment: .top) {
                Button(action: action) {
                    VStack(spacing: 2) {
                        JLogo().fill(p.onAccent).aspectRatio(JLogo.aspect, contentMode: .fit).frame(height: (Self.size * 0.585).rounded())
                            .frame(width: Self.size, height: Self.size)
                            .background(RoundedRectangle(cornerRadius: (Self.size * 0.3).rounded(), style: .continuous).fill(p.accent))
                        Text("Workout").font(.system(size: 11, weight: .heavy)).foregroundStyle(p.accent).lineLimit(1)
                            .shadow(color: p.accent.opacity(0.55), radius: 3.5)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(y: -Self.rise)
                .accessibilityLabel("Workout")
            }
    }
}

/// The app icon's flexing J, still. On the icon's grid its own bounds run x 206...790 and y 150...880;
/// the path is fitted into the frame, keeping its shape, centered.
struct JLogo: Shape {
    static let aspect: CGFloat = 584.0 / 730.0

    func path(in r: CGRect) -> Path {
        let s = min(r.width / 584, r.height / 730)
        let x0 = r.midX - 292 * s, y0 = r.midY - 365 * s
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x0 + (x - 206) * s, y: y0 + (y - 150) * s) }
        var path = Path()
        path.move(to: pt(606, 150))
        path.addLine(to: pt(760, 150))
        path.addCurve(to: pt(790, 180), control1: pt(778, 150), control2: pt(790, 162))
        path.addLine(to: pt(790, 600))
        path.addCurve(to: pt(506, 880), control1: pt(790, 774), control2: pt(676, 880))
        path.addCurve(to: pt(206, 690), control1: pt(330, 880), control2: pt(206, 800))
        path.addCurve(to: pt(410, 462), control1: pt(206, 560), control2: pt(300, 462))
        path.addCurve(to: pt(576, 610), control1: pt(500, 462), control2: pt(562, 520))
        path.addLine(to: pt(576, 180))
        path.addCurve(to: pt(606, 150), control1: pt(576, 162), control2: pt(588, 150))
        path.closeSubpath()
        return path
    }
}
