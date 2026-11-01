import SwiftUI

/// Pick exercises out of the routines you already have, from as many of them as you like, for the
/// routine being built. Tap a routine to open it and tick exercises, or tick the box on the
/// routine's row to take all of it. A superset ticked whole stays a superset. Nothing changes
/// until Add.
struct FromRoutinesSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    var title = "From my routines"
    /// The routine being built, left out of the list.
    var exclude: String? = nil
    let onAdd: (PickedExercises) -> Void

    @State private var picks: Set<RoutinePick> = []
    @State private var open: Set<String> = []

    private var routines: [Routine] { store.routines.filter { $0.id != exclude && !$0.items.isEmpty } }
    private var count: Int { picks.count }
    private var addTitle: String {
        count == 0 ? "Add exercises" : count == 1 ? "Add 1 exercise" : "Add \(count) exercises"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if routines.isEmpty {
                Text("No other routines with exercises yet.")
                    .font(.system(size: 15)).foregroundStyle(p.muted)
                    .padding(.horizontal, 20).padding(.top, 8)
                Spacer()
            } else {
                list
            }
            PillButton(title: addTitle, style: .primary, full: true, height: 54) { add() }
                .disabled(count == 0)
                .opacity(count == 0 ? 0.4 : 1)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
                .background(p.card)
        }
        .background(p.card)
        .interactiveDismissDisabled(count > 0)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text).lineLimit(1)
            Spacer()
            Button("Cancel") { dismiss() }
                .font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
    }

    private var list: some View {
        List {
            ForEach(routines) { r in
                Section {
                    routineRow(r)
                    if open.contains(r.id) {
                        ForEach(Array(r.items.enumerated()), id: \.offset) { i, item in
                            exerciseRow(r, index: i, item: item)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// The routine's name opens and closes its exercises; the box on the right takes all of them.
    private func routineRow(_ r: Routine) -> some View {
        let picked = r.items.indices.filter { picks.contains(RoutinePick(routineId: r.id, index: $0)) }.count
        let all = picked == r.items.count
        let isOpen = open.contains(r.id)
        return HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { if isOpen { open.remove(r.id) } else { open.insert(r.id) } }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted).frame(width: 16)
                    Text(r.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(picked > 0 ? "\(picked) of \(r.items.count)" : "\(r.items.count) ex")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(picked > 0 ? p.accent : p.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                let ids = r.items.indices.map { RoutinePick(routineId: r.id, index: $0) }
                if all { picks.subtract(ids) } else { picks.formUnion(ids) }
            } label: {
                RectCheck(on: all, size: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(all ? "Untick all of \(r.name)" : "Tick all of \(r.name)")
        }
        .padding(.vertical, 8)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.elevated)
                .padding(.horizontal, 16).padding(.vertical, 3)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: 28, bottom: 3, trailing: 28))
    }

    private func exerciseRow(_ r: Routine, index: Int, item: RoutineItem) -> some View {
        let pick = RoutinePick(routineId: r.id, index: index)
        let on = picks.contains(pick)
        let v = store.version(item.versionId)
        let inGroup = item.groupId.map { gid in r.items.filter { $0.groupId == gid }.count } ?? 0
        return Button {
            if on { picks.remove(pick) } else { picks.insert(pick) }
        } label: {
            HStack(spacing: 12) {
                RectCheck(on: on, size: 26)
                VStack(alignment: .leading, spacing: 4) {
                    Text(v.map { store.baseName($0) } ?? "Missing exercise")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
                    HStack(spacing: 6) {
                        if inGroup > 1 {
                            Text(GroupType.forCount(inGroup).label).font(.system(size: 12, weight: .bold)).foregroundStyle(p.accent)
                        }
                        if let v {
                            VariationChips(tags: store.variationChips(v), size: .small, note: store.style(item.styleId)?.label, nickname: store.nickname(v))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.elevated)
                .padding(.horizontal, 16).padding(.vertical, 3)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: 44, bottom: 3, trailing: 28))
    }

    private func add() {
        onAdd(pickedExercises(from: routines, picks: picks))
        dismiss()
    }
}
