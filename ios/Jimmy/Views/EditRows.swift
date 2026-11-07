import SwiftUI

// The pieces every edit sheet shares (a routine's, a split's), so a list you edit looks and works
// the same everywhere: the name and one accent word at the top, a red minus on the left of a row
// takes it out, three lines on the right mean hold and drag to move it.

/// A sheet's top line: its name on the left, one accent word (Done, Cancel) on the right.
struct SheetHeader: View {
    @Environment(\.palette) private var p
    let title: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text).lineLimit(1)
            Spacer()
            Button(button, action: action)
                .font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
    }
}

/// The red minus that takes a row out of the list.
struct RemoveTile: View {
    @Environment(\.palette) private var p
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus")
                .font(.system(size: 15, weight: .heavy)).foregroundStyle(p.danger)
                .frame(width: 32, height: 32)
                .background(p.dangerSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -6)
        .accessibilityLabel(label)
    }
}

/// Three lines: hold the row and drag it to move it.
struct DragHandle: View {
    @Environment(\.palette) private var p

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.border)
            .accessibilityHidden(true)
    }
}

/// A plain icon button in a row (Duplicate, for one), a full tap target around a small glyph.
struct RowIconButton: View {
    @Environment(\.palette) private var p
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The big title of a page's main part ("In this split"), with an accent word on its right.
struct PartTitle: View {
    @Environment(\.palette) private var p
    let title: String
    var button: String? = nil
    var action: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 22, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
            Spacer()
            if let button {
                Button(button, action: action)
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
        }
        .listRowBackground(Color.clear).listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
    }
}

/// A day of a split: its number on a small accent tile.
struct DayNumber: View {
    @Environment(\.palette) private var p
    let n: Int

    var body: some View {
        Text("\(n)")
            .font(.system(size: 14, weight: .heavy)).monospacedDigit().foregroundStyle(p.onAccent)
            .frame(width: 30, height: 30)
            .background(p.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel("Day \(n)")
    }
}

extension View {
    /// A row in a sheet's list: its own rounded tile, a little apart from the next.
    func sheetRow(_ p: Palette, leading: CGFloat = 26) -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.elevated)
                .padding(.horizontal, 16).padding(.vertical, 3)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: leading, bottom: 3, trailing: 28))
    }

    /// A small label above a part of a sheet's list, on the sheet itself.
    func sheetLabelRow(top: CGFloat = 14) -> some View {
        listRowBackground(Color.clear).listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 24, bottom: 4, trailing: 24))
    }
}
