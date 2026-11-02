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
        .background(p.bg)
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
    func groupRowCard(_ p: Palette, grouped: Bool, first: Bool, last: Bool) -> some View {
        let r = Radius.row
        let shape = UnevenRoundedRectangle(topLeadingRadius: first ? r : 0, bottomLeadingRadius: last ? r : 0,
                                           bottomTrailingRadius: last ? r : 0, topTrailingRadius: first ? r : 0, style: .continuous)
        return self.listRowBackground(
            shape.fill(p.card)
                .overlay(alignment: .leading) { if grouped { Rectangle().fill(p.accent).frame(width: 3) } }
                .clipShape(shape)
                .padding(.horizontal, 16).padding(.top, first ? 5 : 0).padding(.bottom, last ? 5 : 0)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: first ? 5 : 0, leading: 16, bottom: last ? 5 : 0, trailing: 16))
    }
}
