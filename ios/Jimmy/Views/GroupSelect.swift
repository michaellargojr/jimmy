import SwiftUI

// The one way to group exercises anywhere in the app, first built for the Workout page's Overview:
// a tick box on each row, and a bar docked under the list that offers what fits the ticks.
// Ticking a grouped exercise offers Ungroup; ticking two or more loose ones offers
// Make a superset (triset, circuit). Group members share one card with an accent edge, and each
// says which it is: "TRISET 2".

/// The tick box at the front of a row. Its own button, so a tick never opens or jumps anywhere.
struct GroupTickBox: View {
    let on: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            RectCheck(on: on, size: 26).frame(width: 40, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Shows only while the ticks allow something, docked under the list.
struct GroupSelectBar: View {
    @Environment(\.palette) private var p
    /// Whether any ticked exercise is in a group.
    let anyGrouped: Bool
    /// How many are ticked.
    let count: Int
    let makeGroup: () -> Void
    let ungroup: () -> Void
    /// Behind the bar: the page's background unless a sheet gives its own.
    var background: Color? = nil

    var body: some View {
        if anyGrouped {
            button("Ungroup", ungroup)
        } else if count >= 2 {
            button("Make a \(GroupType.forCount(count).rawValue)", makeGroup)
        }
    }

    private func button(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation { action() } } label: {
            Text(title).font(.system(size: 18, weight: .heavy)).foregroundStyle(p.onAccent)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(p.accent, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(background ?? p.bg)
    }
}

/// "TRISET 2": which member of its group a row is, the same way the Workout cards say it.
struct GroupMemberLabel: View {
    @Environment(\.palette) private var p
    let members: Int
    let number: Int

    var body: some View {
        Text("\(GroupType.forCount(members).label) \(number)".uppercased())
            .font(.system(size: 12, weight: .heavy)).tracking(0.6).foregroundStyle(p.accent)
            .padding(.bottom, 2)
    }
}

extension View {
    /// A group's members share one card with an accent edge; loose exercises get a card each.
    /// A sheet already painted in the card color passes its own `fill`.
    func groupRowCard(_ p: Palette, grouped: Bool, first: Bool, last: Bool, fill: Color? = nil) -> some View {
        let r = Radius.row
        let shape = UnevenRoundedRectangle(topLeadingRadius: first ? r : 0, bottomLeadingRadius: last ? r : 0,
                                           bottomTrailingRadius: last ? r : 0, topTrailingRadius: first ? r : 0, style: .continuous)
        return self.listRowBackground(
            shape.fill(fill ?? p.card)
                .overlay(alignment: .leading) { if grouped { Rectangle().fill(p.accent).frame(width: 3) } }
                .clipShape(shape)
                .padding(.horizontal, 16).padding(.top, first ? 5 : 0).padding(.bottom, last ? 5 : 0)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: first ? 5 : 0, leading: 16, bottom: last ? 5 : 0, trailing: 16))
    }
}

/// A list row standing for a loose exercise or a whole group, with an id that stays put when it moves.
struct BlockEntry: Identifiable {
    let id: String
    let block: ExerciseBlock
}

/// A whole group as one row of a list, so holding its header lifts every member together
/// (the list's own drag). Each member's handle drags it to a new place inside the group.
struct GroupBlockCard<Member: View>: View {
    @Environment(\.palette) private var p
    /// One steady id per member, in order.
    let ids: [String]
    /// The card's color, for the lifted member. A sheet painted in the card color passes its own.
    var fill: Color? = nil
    /// A member moved from one place in the group to another.
    let move: (_ from: Int, _ to: Int) -> Void
    /// A member's row, left of its handle.
    @ViewBuilder let member: (Int) -> Member

    @State private var dragged: Int? = nil
    @State private var drag: CGFloat = 0
    @State private var target: Int? = nil
    @State private var heights: [String: CGFloat] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(ids.enumerated()), id: \.element) { k, id in
                HStack(spacing: 14) {
                    member(k)
                    handle(k)
                }
                .padding(.leading, 6).padding(.trailing, 16).padding(.vertical, 8)
                .background {
                    if dragged == k {
                        RoundedRectangle(cornerRadius: Radius.row, style: .continuous).fill(fill ?? p.card)
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[id] = $0 }
                .offset(y: shift(k))
                .zIndex(dragged == k ? 1 : 0)
            }
        }
        .sensoryFeedback(.selection, trigger: target) { old, new in old != nil && new != nil }
    }

    /// The top of the group, tinted with the accent and carrying the group's grip: hold here to
    /// lift the whole group.
    private var header: some View {
        HStack(spacing: 14) {
            Text(GroupType.forCount(ids.count).label.uppercased())
                .font(.system(size: 12, weight: .heavy)).tracking(0.6).foregroundStyle(p.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "line.3.horizontal").font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
        }
        .padding(.leading, 60).padding(.trailing, 16).frame(minHeight: 40)
        .background(p.accentSoft, in: UnevenRoundedRectangle(topLeadingRadius: Radius.row, bottomLeadingRadius: 0,
                                                             bottomTrailingRadius: 0, topTrailingRadius: Radius.row,
                                                             style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Drags at once, without a hold, and only inside the group.
    private func handle(_ k: Int) -> some View {
        Image(systemName: "line.3.horizontal").font(.system(size: 17, weight: .semibold))
            .foregroundStyle(dragged == k ? p.accent : p.muted)
            .padding(12).contentShape(Rectangle()).padding(-12)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { g in
                        if dragged == nil { dragged = k; target = k }
                        guard let d = dragged else { return }
                        drag = clamp(g.translation.height, for: d)
                        let t = place(for: d, drag)
                        if t != target { withAnimation(.snappy(duration: 0.22)) { target = t } }
                    }
                    .onEnded { _ in
                        guard let d = dragged else { return }
                        let t = target ?? d
                        withAnimation(.snappy(duration: 0.25)) {
                            if t != d { move(d, t) }
                            dragged = nil; target = nil; drag = 0
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private func height(_ k: Int) -> CGFloat { ids.indices.contains(k) ? heights[ids[k]] ?? 60 : 60 }

    /// Keeps the lifted member inside its group.
    private func clamp(_ t: CGFloat, for d: Int) -> CGFloat {
        let up = (0..<d).reduce(CGFloat(0)) { $0 + height($1) }
        let down = ((d + 1)..<max(d + 1, ids.count)).reduce(CGFloat(0)) { $0 + height($1) }
        return min(max(t, -up), down)
    }

    /// Where the lifted member would land: past each neighbour once it crosses that one's middle.
    private func place(for d: Int, _ t: CGFloat) -> Int {
        var to = d
        var passed: CGFloat = 0
        if t > 0 {
            for k in (d + 1)..<max(d + 1, ids.count) {
                guard t > passed + height(k) / 2 else { break }
                passed += height(k); to = k
            }
        } else {
            for k in stride(from: d - 1, through: 0, by: -1) {
                guard -t > passed + height(k) / 2 else { break }
                passed += height(k); to = k
            }
        }
        return to
    }

    /// The lifted member follows the finger; the ones it passes slide over to make room.
    private func shift(_ k: Int) -> CGFloat {
        guard let d = dragged else { return 0 }
        if k == d { return drag }
        let to = target ?? d
        let h = height(d)
        if d < to, k > d, k <= to { return -h }
        if to < d, k >= to, k < d { return h }
        return 0
    }
}
