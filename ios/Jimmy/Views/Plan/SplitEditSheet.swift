import SwiftUI

/// Edit split (Michael, Nov 2): which routines a split holds and in what order, in one sheet that
/// works like editing a routine. In this split: tap a routine to edit its exercises, the red minus
/// takes it out, the copy icon duplicates it (the copy goes right after it), hold and drag to
/// change the order. New routine. Add an existing routine: Add, or swipe one left to duplicate it
/// or delete it for good ("Delete from everywhere?" asks first).
/// Each change saves as it's made; Done goes back to the split page.
struct SplitEditSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let splitId: String

    @State private var building = false
    /// The routine being duplicated, and the spot its copy takes (nil: the end).
    @State private var duplicating: Routine? = nil
    @State private var copySpot: Int? = nil
    @State private var renaming: Routine? = nil
    @State private var newName = ""
    @State private var taken: NameTaken? = nil
    @State private var editing: SplitEditorView.SlotEdit? = nil
    @State private var deleting: Routine? = nil

    private var split: Split? { store.splits.first { $0.id == splitId } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: split?.name ?? "Split", button: "Done") { dismiss() }
            if let s = split { list(s) }
        }
        .background(p.card)
        .sheet(isPresented: $building) {
            // New routine: it joins this split, and you come back here.
            RoutineBuilderSheet(mode: .create) { name, built in
                var r = Routine(name: name)
                r.add(built)
                store.put(r)
                if var ss = split { ss.add(r.id); ss.noteMadeHere(r.id); store.put(ss) }
            }
            .presentationDetents([.large])
            .presentationBackground(p.card)
        }
        .sheet(item: $editing) { e in
            RoutineDraftSheet(mode: .edit(splitId: splitId, slot: e.slot), routine: e.routine, takenNames: store.routines.map(\.name))
                .presentationDetents([.large])
                .presentationBackground(p.card)
        }
        .sheet(item: $duplicating) { r in
            RoutineDraftSheet(mode: .duplicate, routine: r, takenNames: store.routines.map(\.name)) {
                store.addCopy($0, toSplit: splitId, at: copySpot)
            }
            .presentationDetents([.large])
            .presentationBackground(p.card)
        }
        .alert("Rename routine", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                let n = newName.trimmingCharacters(in: .whitespaces)
                if let r = renaming, routineNameTaken(n, in: store.routines, except: r.id) {
                    let typed = newName
                    taken = NameTaken(name: n) { newName = typed; renaming = r }
                } else if var r = renaming, !n.isEmpty { r.name = n; store.put(r) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .nameTakenAlert($taken)
        .routineDeleteAlert($deleting)
        .routineUndoBar(splitId: splitId)
    }

    private func list(_ s: Split) -> some View {
        let inSplit = Set(s.routineIds)
        return List {
            SectionLabel("In this split").sheetLabelRow(top: 8)
            if s.routineIds.isEmpty {
                Text("No routines yet.")
                    .font(.system(size: 15)).foregroundStyle(p.muted)
                    .sheetLabelRow(top: 2)
            }
            ForEach(Array(s.routineIds.enumerated()), id: \.offset) { i, rid in
                slotRow(s, index: i, routineId: rid)
            }
            .onMove { from, to in
                guard var ss = split else { return }
                ss.routineIds.move(fromOffsets: from, toOffset: to)
                store.put(ss)
            }
            PillButton(title: "New routine", icon: "plus", full: true) { building = true }
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))
            SectionLabel("Add an existing routine").sheetLabelRow(top: 18)
            ForEach(store.routines) { r in
                existingRow(r, inSplit: inSplit.contains(r.id))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// A day of the split: remove, its number and name (tap to edit its exercises), duplicate, and
    /// the handle.
    private func slotRow(_ s: Split, index i: Int, routineId rid: String) -> some View {
        let r = store.routine(rid)
        let name = r?.name ?? "Missing routine"
        return HStack(spacing: 12) {
            RemoveTile(label: "Remove \(name)") {
                withAnimation(.snappy) {
                    guard var ss = split, ss.routineIds.indices.contains(i) else { return }
                    ss.routineIds.remove(at: i)
                    store.put(ss)
                }
            }
            Button {
                if let r { editing = SplitEditorView.SlotEdit(routine: r, slot: i) }
            } label: {
                HStack(spacing: 12) {
                    Text("\(i + 1)").font(.system(size: 13, weight: .bold)).monospacedDigit().foregroundStyle(p.muted)
                        .frame(minWidth: 16, alignment: .leading)
                    Text(name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let r {
                RowIconButton(icon: "doc.on.doc", label: "Duplicate \(name)") { copySpot = i + 1; duplicating = r }
            }
            DragHandle()
        }
        .padding(.vertical, 2)
        .sheetRow(p, leading: 26)
    }

    /// One of your routines: Add puts it at the end of the split (again, if it's in already).
    private func existingRow(_ r: Routine, inSplit: Bool) -> some View {
        HStack(spacing: 12) {
            Text(r.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(inSplit ? p.muted : p.text).lineLimit(1)
            Spacer(minLength: 0)
            Chip(text: "Add", small: true) {
                guard var ss = split else { return }
                withAnimation(.snappy) { ss.add(r.id); store.put(ss) }
            }
        }
        .padding(.vertical, 6)
        .sheetRow(p, leading: 30)
        .swipeActions {
            // Not role .destructive: that takes the row away before "Delete from everywhere?" is answered.
            Button { deleting = r } label: { Label("Delete", systemImage: "trash") }.tint(.red)
            Button { copySpot = nil; duplicating = r } label: { Label("Duplicate", systemImage: "doc.on.doc") }.tint(Color(hex: 0x4A4C55))
        }
        .contextMenu {
            RoutineMenu(rename: { newName = r.name; renaming = r },
                        duplicate: { copySpot = nil; duplicating = r },
                        delete: { deleting = r })
        }
    }
}
