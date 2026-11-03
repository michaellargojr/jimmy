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
            List {
                Section {
                    MuscleTags(primary: muscles(r).primary, secondary: muscles(r).secondary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .rowCard(p, radius: Radius.card)
                }
                Section {
                    ForEach(Array(r.items.enumerated()), id: \.offset) { i, item in
                        row(r, index: i, item: item)
                    }
                    // A drag in or out of a group works the way it does in the Workout page's Overview.
                    .onMove { from, to in
                        selected = ticksAfterMove(selected, count: r.items.count, from: from, to: to)
                        store.put(moveItem(r, from: from, to: to))
                    }
                    .onDelete { idx in
                        var rr = r; rr.items.remove(atOffsets: idx)
                        selected = ticksAfterDelete(selected, deleted: idx)
                        store.put(tidyGroups(rr))
                    }
                }
                // Coverage is the last part of the page; the buttons stay under it.
                if let s = store.split(containing: r.id) {
                    Section { CoverageCard(splitId: s.id, routineId: r.id).rowCard(p, radius: Radius.card) }
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

    /// Tick box, name and chips (tap to open the variation), drag handle: the Overview's row.
    private func row(_ r: Routine, index i: Int, item: RoutineItem) -> some View {
        let v = store.version(item.versionId)
        let place = r.groupPlace(at: i)
        return HStack(spacing: 14) {
            GroupTickBox(on: selected.contains(i)) {
                if selected.contains(i) { selected.remove(i) } else { selected.insert(i) }
            }
            Button { opened = v } label: {
                RoutineItemLabel(item: item, place: place)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .disabled(v == nil)
            Image(systemName: "line.3.horizontal").font(.system(size: 17, weight: .semibold)).foregroundStyle(p.muted)
        }
        .buttonStyle(.plain)
        .padding(.leading, 6).padding(.trailing, 16).padding(.vertical, 8)
        .groupRowCard(p, grouped: place.group != nil, first: place.first, last: place.last)
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
