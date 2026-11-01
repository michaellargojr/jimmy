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
    @State private var fromRoutines = false

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
                } footer: {
                    Text("Drag to reorder. Swipe left to remove. Group… picks rows for a superset, triset or circuit.")
                        .font(.system(size: 13)).foregroundStyle(p.muted).padding(.horizontal, 16)
                }
                Section {
                    PillButton(title: "Add exercise", icon: "plus", full: true) { adding = true }
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    PillButton(title: "From my routines", icon: "square.on.square", full: true) { fromRoutines = true }
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    PillButton(title: "Start this routine", style: .primary, full: true) {
                        if store.canPickWorkout { store.startWorkout(from: r) }
                        nav.tab = .workout
                    }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
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
                Button("Save") { var rr = r; rr.name = name.trimmingCharacters(in: .whitespaces); if !rr.name.isEmpty { store.put(rr) } }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $adding) {
                AddExerciseSheet { v, st in var rr = r; rr.items.append(RoutineItem(versionId: v.id, styleId: st?.id)); store.put(rr) }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .sheet(isPresented: $fromRoutines) {
                FromRoutinesSheet(exclude: r.id) { picked in if var rr = store.routine(r.id) { rr.add(picked); store.put(rr) } }
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

struct SplitEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let splitId: String
    @State private var renaming = false
    @State private var name = ""
    @State private var goals = false
    @State private var naming = false
    @State private var newName = ""
    @State private var created: Routine? = nil
    @State private var editing: SlotEdit? = nil
    @State private var duplicating: Routine? = nil
    @State private var renamingRoutine: Routine? = nil
    @State private var routineName = ""
    /// A routine just made with New routine, offered exercises from the other routines first.
    @State private var picking: Routine? = nil
    @State private var pendingOpen: Routine? = nil
    /// Decided once, when the page opens: a split with no routines yet is being put together and
    /// keeps that layout until the page is left (splitSections).
    @State private var creating: Bool? = nil
    @Environment(\.editMode) private var editMode

    /// One spot of the cycle opened in the edit sheet.
    struct SlotEdit: Identifiable { let id = uid(); let routine: Routine; let slot: Int }

    private var split: Split? { store.splits.first { $0.id == splitId } }

    var body: some View {
        if let s = split {
            let inSplit = Set(s.routineIds)
            let creating = self.creating ?? s.routineIds.isEmpty
            List {
                ForEach(splitSections(creating: creating), id: \.self) { section in
                    switch section {
                    case .goals: goalsSection(s)
                    case .coverage: coverageSection(s)
                    case .newRoutine: newRoutineSection
                    case .inSplit: inSplitSection(s)
                    case .addRoutine: addRoutineSection(s, inSplit: inSplit)
                    }
                }
                Section {
                    if store.activeSplit?.id != s.id {
                        PillButton(title: "Use this split", style: .primary, full: true) { store.update { $0.activeSplitId = s.id } }
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                }
            }
            .cardList()
            .navigationTitle(s.name)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        EditButton()
                        Menu {
                            Button { name = s.name; renaming = true } label: { Label("Rename", systemImage: "pencil") }
                            Button(role: .destructive) { store.deleteSplit(s.id) } label: { Label("Delete split", systemImage: "trash") }
                        } label: { Image(systemName: "ellipsis") }
                    }
                }
            }
            .alert("Rename split", isPresented: $renaming) {
                TextField("Name", text: $name)
                Button("Save") { var ss = s; ss.name = name.trimmingCharacters(in: .whitespaces); if !ss.name.isEmpty { store.put(ss) } }
                Button("Cancel", role: .cancel) {}
            }
            .alert("New routine", isPresented: $naming) {
                TextField("Name", text: $newName)
                Button("Create") {
                    let n = newName.trimmingCharacters(in: .whitespaces)
                    let r = Routine(name: n.isEmpty ? "New routine" : n)
                    store.put(r)
                    var ss = s; ss.add(r.id); ss.noteMadeHere(r.id); store.put(ss)
                    if store.routines.contains(where: { $0.id != r.id && !$0.items.isEmpty }) {
                        // The offer waits for the alert to go, or the sheet is lost under it.
                        pendingOpen = r
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            picking = r
                        }
                    } else {
                        created = r
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationDestination(item: $created) { r in RoutineEditorView(routineId: r.id) }
            .sheet(isPresented: $goals) {
                GoalsSheet(splitId: s.id)
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .sheet(item: $editing) { e in
                RoutineDraftSheet(mode: .edit(splitId: s.id, slot: e.slot), routine: e.routine, takenNames: store.routines.map(\.name))
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            // Exercises from the other routines for the new routine; it opens once the sheet has gone.
            .sheet(item: $picking, onDismiss: { created = pendingOpen; pendingOpen = nil }) { r in
                FromRoutinesSheet(title: "Take from your routines", exclude: r.id) { picked in
                    if var rr = store.routine(r.id) { rr.add(picked); store.put(rr) }
                }
                .presentationDetents([.large])
                .presentationBackground(p.card)
            }
            // A copy made here joins the split, with Undo. The page stays put.
            .sheet(item: $duplicating) { r in
                RoutineDraftSheet(mode: .duplicate, routine: r, takenNames: store.routines.map(\.name)) { store.addCopy($0, toSplit: s.id) }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .alert("Rename routine", isPresented: Binding(get: { renamingRoutine != nil }, set: { if !$0 { renamingRoutine = nil } })) {
                TextField("Name", text: $routineName)
                Button("Save") {
                    let n = routineName.trimmingCharacters(in: .whitespaces)
                    if var r = renamingRoutine, !n.isEmpty { r.name = n; store.put(r) }
                    renamingRoutine = nil
                }
                Button("Cancel", role: .cancel) { renamingRoutine = nil }
            }
            .routineUndoBar(splitId: s.id)
            .task { if self.creating == nil { self.creating = s.routineIds.isEmpty } }
            #if DEBUG
            .task {
                if RoutineDemo.once("edit", for: ["edit", "ask"]), let rid = s.routineIds.first, let r = store.routine(rid) {
                    editing = SlotEdit(routine: r, slot: 0)
                }
            }
            #endif
        }
    }

    // MARK: Sections

    private func goalsSection(_ s: Split) -> some View {
        Section {
            Button { goals = true } label: { GoalsRow(goals: s.goals ?? SplitGoals()) }
                .buttonStyle(.plain)
                .rowCard(p, radius: Radius.card)
        }
    }

    private func coverageSection(_ s: Split) -> some View {
        Section {
            CoverageCard(splitId: s.id).rowCard(p, radius: Radius.card)
        }
    }

    private var newRoutineSection: some View {
        Section {
            PillButton(title: "New routine", icon: "plus", full: true) { newName = ""; naming = true }
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
    }

    private func inSplitSection(_ s: Split) -> some View {
        Section {
            if s.routineIds.isEmpty {
                Text("Nothing here yet. New routine below, or Add one of your routines.")
                    .font(.system(size: 14)).foregroundStyle(p.muted)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(Array(s.routineIds.enumerated()), id: \.offset) { i, rid in
                Button {
                    if editMode?.wrappedValue != .active, let r = store.routine(rid) { editing = SlotEdit(routine: r, slot: i) }
                } label: {
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted).frame(width: 24)
                        Text(store.routine(rid)?.name ?? "Missing routine").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        Spacer()
                        Text("\(store.routine(rid)?.items.count ?? 0) ex").font(.system(size: 13)).foregroundStyle(p.muted)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.border)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rowCard(p)
                .contextMenu {
                    if let r = store.routine(rid) {
                        RoutineMenu(rename: { routineName = r.name; renamingRoutine = r },
                                    duplicate: { duplicating = r },
                                    remove: { var ss = s; if ss.routineIds.indices.contains(i) { ss.routineIds.remove(at: i) }; store.put(ss) })
                    }
                }
            }
            .onMove { from, to in var ss = s; ss.routineIds.move(fromOffsets: from, toOffset: to); store.put(ss) }
            .onDelete { idx in var ss = s; ss.routineIds.remove(atOffsets: idx); store.put(ss) }
        } header: {
            SectionLabel("In this split").padding(.leading, 16)
        } footer: {
            Text("A routine can appear more than once, for example Push, Pull, Legs, Push, Pull, Legs. Tap one to edit it; hold one for Rename, Duplicate or Remove.")
                .font(.system(size: 13)).foregroundStyle(p.muted).padding(.horizontal, 16)
        }
    }

    private func addRoutineSection(_ s: Split, inSplit: Set<String>) -> some View {
        Section {
            ForEach(store.routines) { r in
                HStack {
                    Text(r.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(inSplit.contains(r.id) ? p.muted : p.text)
                    Spacer()
                    Chip(text: "Add", small: true) { var ss = s; ss.add(r.id); store.put(ss) }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .rowCard(p)
                .contextMenu {
                    RoutineMenu(rename: { routineName = r.name; renamingRoutine = r },
                                duplicate: { duplicating = r },
                                delete: { store.deleteRoutine(r.id) })
                }
            }
        } header: {
            SectionLabel("Add a routine").padding(.leading, 16)
        } footer: {
            Text("Hold a routine for Rename, Duplicate or Delete. A copy made here joins this split.")
                .font(.system(size: 13)).foregroundStyle(p.muted).padding(.horizontal, 16)
        }
    }
}
