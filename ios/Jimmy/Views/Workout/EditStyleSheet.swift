import SwiftUI

/// Mid-workout: pick one of this variation's styles and add to it (the cable height you only
/// learn at the gym) instead of making a second style. Saving picks it on the card and closes
/// straight back to the workout.
struct EditStyleSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let version: Version
    /// The style on the card, listed first.
    let currentId: String?
    let onSave: (Style) -> Void

    @State private var picked: Style? = nil

    var body: some View {
        if let s = picked {
            // Same sheet, so the editor's Save and Close end on the workout, not back on this list.
            StyleEditorSheet(version: version, style: s, onSave: onSave).id(s.id)
        } else {
            list
        }
    }

    private var list: some View {
        let styles = editStyleOrder(store.styles(of: version.id), currentId: currentId)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edit style").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                        Text(store.fullName(version)).font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    Spacer()
                    Button("Close") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
                }
                VStack(spacing: 0) {
                    ForEach(Array(styles.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { Divider1() }
                        row(s)
                    }
                }
                .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
            .padding(16)
            .padding(.bottom, 24)
        }
    }

    private func row(_ s: Style) -> some View {
        Button { picked = s } label: {
            HStack(spacing: 12) {
                Text(s.label.isEmpty ? "Style" : dashed(s.label))
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if s.id == currentId {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(p.accent)
                }
                Chevron()
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s.id == currentId ? "\(s.label), on the card" : s.label)
    }
}

/// The styles to edit: the one on the card first, the rest as they are.
func editStyleOrder(_ styles: [Style], currentId: String?) -> [Style] {
    guard let currentId, let i = styles.firstIndex(where: { $0.id == currentId }) else { return styles }
    var out = styles
    out.insert(out.remove(at: i), at: 0)
    return out
}
