import SwiftUI

struct RoutineEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let routineId: String
    @State private var adding = false
    @State private var renaming = false
    @State private var name = ""
    /// Ticked rows, by place in the list. Starts empty every time the page opens.
    @State private var selected: Set<Int> = []
    /// The variation a row's name opened.
    @State private var opened: Version? = nil
    @State private var duplicating = false
    @State private var justMade: Routine? = nil
    @State private var created: Routine? = nil
    @State private var taken: NameTaken? = nil

    private var routine: Routine? { store.routine(routineId) }

    var body: some View {
        if let r = routine {
            let m = muscles(r)
            List {
                Section {
                    MuscleTags(primary: m.primary, secondary: m.secondary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .rowCard(p, radius: Radius.card)
                }
                Section {
                    // Rows keep their id when they move, so a drop lands at once instead of redrawing every row.
                    // A group is one row: holding its header moves the whole group (GroupSelect.swift).
                    ForEach(entries(r)) { e in
                        if e.block.group != nil {
                            groupCard(r, block: e.block)
                        } else {
                            row(r, index: e.block.range.lowerBound, item: r.items[e.block.range.lowerBound])
                        }
                    }
                    .onMove { from, to in
                        selected = ticks(selected, after: orderAfterBlockMove(r.blocks, from: from, to: to))
                        store.put(moveBlocks(r, from: from, to: to))
                    }
                    .onDelete { idx in
                        let blocks = r.blocks
                        let gone = IndexSet(idx.filter { blocks.indices.contains($0) }.flatMap { Array(blocks[$0].range) })
                        var rr = r; rr.items.remove(atOffsets: gone)
                        selected = ticksAfterDelete(selected, deleted: gone)
                        store.put(tidyGroups(rr))
                    }
                }
                Section {
                    PillButton(title: "Add exercises", icon: "plus", full: true) { adding = true }
                        .buttonRow()
                    PillButton(title: "Start this routine", style: .primary, full: true) {
                        if store.canPickWorkout { store.startWorkout(from: r) }
                        nav.tab = .workout
                    }
                    .buttonRow()
                }
            }
            .cardList()
            .safeAreaInset(edge: .bottom) { bottomBar(r) }
            .navigationTitle(r.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { name = r.name; renaming = true } label: { Label("Rename", systemImage: "pencil") }
                        Button { duplicating = true } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                        Button(role: .destructive) { dismiss(); store.deleteRoutine(r.id) } label: { Label("Delete routine", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis") }
                }
            }
            .alert("Rename routine", isPresented: $renaming) {
                TextField("Name", text: $name)
                Button("Save") {
                    let n = name.trimmingCharacters(in: .whitespaces)
                    if routineNameTaken(n, in: store.routines, except: r.id) {
                        let typed = name
                        taken = NameTaken(name: n) { name = typed; renaming = true }
                    } else if var rr = store.routine(r.id), !n.isEmpty { rr.name = n; store.put(rr) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .nameTakenAlert($taken)
            .sheet(isPresented: $adding) {
                RoutineBuilderSheet(mode: .add(to: r.id)) { _, built in if var rr = store.routine(r.id) { rr.add(built); store.put(rr) } }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            // The copy opens once the sheet has gone, or the push is lost under it.
            .sheet(isPresented: $duplicating, onDismiss: { created = justMade; justMade = nil }) {
                RoutineDraftSheet(mode: .duplicate, routine: r, takenNames: store.routines.map(\.name)) { justMade = $0 }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .navigationDestination(item: $created) { c in RoutineEditorView(routineId: c.id) }
            .navigationDestination(item: $opened) { v in VersionEditorView(versionId: v.id) }
            #if DEBUG
            .task { if RoutineDemo.once("duplicate", for: ["duplicate"]) { duplicating = true } }
            #endif
        }
    }

    /// Ticking loose exercises offers to group them; ticking a grouped one offers to ungroup,
    /// the same bar as the Workout page's Overview (GroupSelect.swift).
    private func bottomBar(_ r: Routine) -> some View {
        let ticked = selected.filter { r.items.indices.contains($0) }
        return GroupSelectBar(anyGrouped: ticked.contains(where: { r.liveGroup(at: $0) != nil }), count: ticked.count,
                              makeGroup: { regroup { makeGroup($0, at: ticked) } },
                              ungroup: { regroup { ungroup($0, at: ticked) } })
    }

    private func regroup(_ change: (Routine) -> Routine) {
        if let r = store.routine(routineId) { store.put(change(r)) }
        selected = []
    }

    /// A loose exercise or a whole group per row, each with an id that stays with it.
    private func entries(_ r: Routine) -> [BlockEntry] {
        let rows = routineRows(r.items)
        return r.blocks.map { b in BlockEntry(id: b.group.map { "group|" + $0 } ?? rows[b.range.lowerBound].id, block: b) }
    }

    /// Tick box, name and chips (tap to open the variation), drag handle: the Overview's row.
    private func row(_ r: Routine, index i: Int, item: RoutineItem) -> some View {
        HStack(spacing: 14) {
            rowContent(r, index: i, item: item)
            Image(systemName: "line.3.horizontal").font(.system(size: 17, weight: .semibold)).foregroundStyle(p.muted)
        }
        .padding(.leading, 6).padding(.trailing, 16).padding(.vertical, 8)
        .groupRowCard(p, grouped: false, first: true, last: true)
    }

    /// A group in one card. Hold a member for Delete, the way the Overview does, since a swipe
    /// would take the whole group.
    private func groupCard(_ r: Routine, block b: ExerciseBlock) -> some View {
        let rows = routineRows(r.items)
        let a = b.range.lowerBound
        return GroupBlockCard(ids: b.range.map { rows[$0].id }, move: { from, to in
            guard let rr = store.routine(routineId) else { return }
            selected = ticks(selected, after: orderAfterMemberMove(count: rr.items.count, from: a + from, to: a + to))
            store.put(moveMember(rr, from: a + from, to: a + to))
        }) { k in
            rowContent(r, index: a + k, item: r.items[a + k])
                .contextMenu {
                    Button(role: .destructive) { delete(at: a + k) } label: { Label("Delete", systemImage: "trash") }
                }
        }
        .groupRowCard(p, grouped: true, first: true, last: true)
        .deleteDisabled(true)
    }

    /// Tick box, then name and chips (tap to open the variation).
    private func rowContent(_ r: Routine, index i: Int, item: RoutineItem) -> some View {
        let v = store.version(item.versionId)
        return HStack(spacing: 14) {
            GroupTickBox(on: selected.contains(i)) {
                if selected.contains(i) { selected.remove(i) } else { selected.insert(i) }
            }
            Button { opened = v } label: {
                RoutineItemLabel(item: item, place: r.groupPlace(at: i))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .disabled(v == nil)
        }
        .buttonStyle(.plain)
    }

    private func delete(at i: Int) {
        guard var rr = store.routine(routineId), rr.items.indices.contains(i) else { return }
        rr.items.remove(at: i)
        selected = ticksAfterDelete(selected, deleted: IndexSet(integer: i))
        withAnimation { store.put(tidyGroups(rr)) }
    }

    /// Every muscle the routine works, primary first, each named once.
    private func muscles(_ r: Routine) -> (primary: [String], secondary: [String]) {
        var prim: [String] = [], sec: [String] = []
        for item in r.items {
            guard let v = store.version(item.versionId), let e = store.base(of: v) else { continue }
            let o = regionOverrides(base: e.name, variation: v)
            for m in o?.primary ?? e.primary where !prim.contains(m) { prim.append(m) }
            for m in o?.secondary ?? e.secondary where !sec.contains(m) { sec.append(m) }
        }
        sec.removeAll { prim.contains($0) }
        return (prim, sec)
    }
}

/// A routine exercise's name and chips, with its place in a group above: the same on the routine
/// page and in the routine sheets.
struct RoutineItemLabel: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let item: RoutineItem
    let place: GroupPlace

    private var v: Version? { store.version(item.versionId) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if place.group != nil { GroupMemberLabel(members: place.members, number: place.number) }
            Text(v.map { store.baseName($0) } ?? "Missing exercise").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
            if let v {
                VariationChips(tags: store.variationChips(v), size: .small,
                               note: [store.style(item.styleId)?.label, "\(v.repMin)-\(v.repMax) rep range"]
                                   .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - "), nickname: store.nickname(v))
                    .padding(.vertical, 2)
            }
        }
    }
}
