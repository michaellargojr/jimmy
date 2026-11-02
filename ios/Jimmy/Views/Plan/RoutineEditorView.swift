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
    @State private var selecting = false
    @State private var selected: Set<Int> = []
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
                if let s = store.split(containing: r.id) {
                    Section { CoverageCard(splitId: s.id, routineId: r.id).rowCard(p, radius: Radius.card) }
                }
                Section {
                    ForEach(Array(r.items.enumerated()), id: \.offset) { i, item in
                        row(r, index: i, item: item)
                    }
                    .onMove { from, to in var rr = r; rr.items.move(fromOffsets: from, toOffset: to); store.put(rr) }
                    .onDelete { idx in
                        var rr = r; rr.items.remove(atOffsets: idx)
                        rr.groups.removeAll { g in !rr.items.contains { $0.groupId == g.id } }
                        store.put(rr)
                    }
                    ListNote("Drag to reorder. Swipe left to remove. Group… picks rows for a superset, triset or circuit.")
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
            .navigationTitle(r.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if selecting {
                            Menu("Group") {
                                Button("Make a \(GroupType.forCount(selected.count).rawValue)") { group(r, as: .forCount(selected.count)) }.disabled(selected.count < 2)
                                Button("Ungroup", role: .destructive) { ungroup(r) }
                            }.disabled(selected.isEmpty)
                            Button("Cancel") { selecting = false; selected = [] }
                        } else {
                            Button("Group…") { selecting = true }
                            Menu {
                                Button { name = r.name; renaming = true } label: { Label("Rename", systemImage: "pencil") }
                                Button { duplicating = true } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                                Button(role: .destructive) { dismiss(); store.deleteRoutine(r.id) } label: { Label("Delete routine", systemImage: "trash") }
                            } label: { Image(systemName: "ellipsis") }
                        }
                    }
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
            #if DEBUG
            .task { if RoutineDemo.once("duplicate", for: ["duplicate"]) { duplicating = true } }
            #endif
        }
    }

    @ViewBuilder
    private func row(_ r: Routine, index: Int, item: RoutineItem) -> some View {
        let v = store.version(item.versionId)
        if selecting {
            rowContent(r, index: index, item: item, v: v)
                .contentShape(Rectangle())
                .onTapGesture { if selected.contains(index) { selected.remove(index) } else { selected.insert(index) } }
                .rowCard(p)
        } else if let v {
            NavigationLink(value: v) { rowContent(r, index: index, item: item, v: v) }.rowCard(p)
        } else {
            rowContent(r, index: index, item: item, v: nil).rowCard(p)
        }
    }

    private func rowContent(_ r: Routine, index: Int, item: RoutineItem, v: Version?) -> some View {
        let g = item.groupId.flatMap { gid in r.groups.first { $0.id == gid } }
        return HStack(spacing: 12) {
            if selecting { RectCheck(on: selected.contains(index), size: 26) }
            else { Text("\(index + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted).frame(width: 24) }
            VStack(alignment: .leading, spacing: 2) {
                Text(v.map { store.baseName($0) } ?? "Missing exercise").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                HStack(spacing: 6) {
                    if g != nil { Text(GroupType.forCount(r.items.filter { $0.groupId == item.groupId }.count).label).font(.system(size: 12, weight: .bold)).foregroundStyle(p.accent) }
                    if let v {
                        VariationChips(tags: store.variationChips(v), size: .small,
                                       note: [store.style(item.styleId)?.label, "\(v.repMin)-\(v.repMax) rep range"]
                                           .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - "), nickname: store.nickname(v))
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
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

    private func group(_ r: Routine, as type: GroupType) {
        var rr = r
        let g = ExerciseGroup(id: uid(), type: type)
        rr.groups.append(g)
        let idxs = selected.sorted()
        var chosen = idxs.map { rr.items[$0] }
        for i in chosen.indices { chosen[i].groupId = g.id }
        for i in idxs.reversed() { rr.items.remove(at: i) }
        rr.items.insert(contentsOf: chosen, at: min(idxs.first ?? 0, rr.items.count))
        rr.groups.removeAll { gg in !rr.items.contains { $0.groupId == gg.id } }
        store.put(rr)
        selecting = false; selected = []
    }

    private func ungroup(_ r: Routine) {
        var rr = r
        for i in selected where i < rr.items.count { rr.items[i].groupId = nil }
        rr.groups.removeAll { gg in !rr.items.contains { $0.groupId == gg.id } }
        store.put(rr)
        selecting = false; selected = []
    }
}
