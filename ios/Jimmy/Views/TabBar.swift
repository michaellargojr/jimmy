import SwiftUI

/// The floating bar: Home and Plan, the Workout circle in the middle, then History and Settings.
/// The circle is the one thing in the bar with color, so it's the one that calls you.
struct JimmyTabBar: View {
    @Environment(\.palette) private var p
    @Binding var tab: AppTab
    @Namespace private var lens

    var body: some View {
        HStack(spacing: 0) {
            item(.home, "Home", "house")
            item(.plan, "Plan", "square.text.square")
            WorkoutCircle { select(.workout) }
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
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 19, weight: .semibold)).frame(height: 24)
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? p.text : p.muted)
            .frame(maxWidth: 64)
            .frame(height: 52)
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
            content.glassEffect(.regular, in: Capsule())
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

/// The Workout button: a J on a circle in the theme color. During a workout it shows the time,
/// so it's also the way back in.
struct WorkoutCircle: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let action: () -> Void

    static let size: CGFloat = 50

    var body: some View {
        let live = store.activeWorkout
        Button(action: action) {
            ZStack {
                Circle().fill(p.accent)
                if let live {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(elapsedString(ms: ctx.date.timeIntervalSince1970 * 1000 - (live.startedAt ?? nowMs())))
                            .font(.system(size: 13, weight: .black)).monospacedDigit()
                            .foregroundStyle(p.onAccent)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .padding(.horizontal, 5)
                    }
                } else {
                    JMark()
                        .stroke(p.onAccent, style: StrokeStyle(lineWidth: JMark.weight * 28, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                }
            }
            .frame(width: Self.size, height: Self.size)
            .shadow(color: p.accent.opacity(0.35), radius: 8, y: 4)
            .frame(width: 64, height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Workout")
        .accessibilityValue(live == nil ? "" : "In progress")
    }
}

/// A plain, bold J drawn as one stroke: the letter in the theme, not the app icon.
/// Drawn on a 24 by 24 grid: the stem comes down the right, then the hook curls under to the left.
struct JMark: Shape {
    /// Stroke width as a share of the frame's width.
    static let weight: CGFloat = 3.4 / 24

    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        let x0 = r.midX - 12 * s, y0 = r.midY - 12 * s
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x0 + x * s, y: y0 + y * s) }
        var path = Path()
        path.move(to: pt(15, 4.2))
        path.addLine(to: pt(15, 13.6))
        // From the right of the hook, down under and back up on the left (angles grow downward on screen).
        path.addArc(center: pt(9.8, 13.6), radius: 5.2 * s, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        return path
    }
}
