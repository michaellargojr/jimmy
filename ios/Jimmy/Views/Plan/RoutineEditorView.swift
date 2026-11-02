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
                if let s = store.split(containing: r.id) {
                    Section { CoverageCard(splitId: s.id, routineId: r.id).rowCard(p, radius: Radius.card) }
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

struct SplitEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let splitId: String
    @State private var renaming = false
    @State private var name = ""
    @State private var goals = false
    @State private var created: Routine? = nil
    @State private var editing: SlotEdit? = nil
    @State private var duplicating: Routine? = nil
    @State private var renamingRoutine: Routine? = nil
    @State private var routineName = ""
    /// New routine: the builder is open; the routine it made opens once it has gone.
    @State private var building = false
    @State private var pendingOpen: Routine? = nil
    /// Decided once, when the page opens: a split with no routines yet is being put together and
    /// keeps that layout until the page is left (splitSections).
    @State private var creating: Bool? = nil
    @State private var taken: NameTaken? = nil
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
                            .buttonRow()
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
            // New routine: built in the sheet, joins this split, and opens once the sheet has gone.
            .sheet(isPresented: $building, onDismiss: { created = pendingOpen; pendingOpen = nil }) {
                RoutineBuilderSheet(mode: .create) { name, built in
                    var r = Routine(name: name)
                    r.add(built)
                    store.put(r)
                    if var ss = store.splits.first(where: { $0.id == splitId }) { ss.add(r.id); ss.noteMadeHere(r.id); store.put(ss) }
                    pendingOpen = r
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
                    if let r = renamingRoutine, routineNameTaken(n, in: store.routines, except: r.id) {
                        let typed = routineName
                        taken = NameTaken(name: n) { routineName = typed; renamingRoutine = r }
                    } else if var r = renamingRoutine, !n.isEmpty { r.name = n; store.put(r) }
                    renamingRoutine = nil
                }
                Button("Cancel", role: .cancel) { renamingRoutine = nil }
            }
            .nameTakenAlert($taken)
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
            PillButton(title: "New routine", icon: "plus", full: true) { building = true }
                .buttonRow()
        }
    }

    private func inSplitSection(_ s: Split) -> some View {
        Section {
            if s.routineIds.isEmpty {
                Text("Nothing here yet. New routine below, or Add an existing one.")
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
            ListNote("A routine can appear more than once, for example Push, Pull, Legs, Push, Pull, Legs. Tap one to edit it; hold one for Rename, Duplicate or Remove.")
        } header: {
            SectionLabel("In this split").padding(.leading, 16)
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
            ListNote("Hold a routine for Rename, Duplicate or Delete. A copy made here joins this split.")
        } header: {
            SectionLabel("Add an existing routine").padding(.leading, 16)
        }
    }
}
