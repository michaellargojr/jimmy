import SwiftUI

struct RoutineEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.palette) private var p
    let routineId: String
    @State private var adding = false
    @State private var renaming = false
    @State private var name = ""
    @State private var selecting = false
    @State private var selected: Set<Int> = []

    private var routine: Routine? { store.routine(routineId) }

    var body: some View {
        if let r = routine {
            List {
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
                    PillButton(title: "Start this routine", style: .primary, full: true) {
                        if store.activeWorkout == nil { store.startWorkout(from: r) }
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
                                ForEach(GroupType.allCases, id: \.self) { t in Button(t.label) { group(r, as: t) } }
                                Button("Ungroup", role: .destructive) { ungroup(r) }
                            }.disabled(selected.isEmpty)
                            Button("Cancel") { selecting = false; selected = [] }
                        } else {
                            Button("Group…") { selecting = true }
                            Menu {
                                Button { name = r.name; renaming = true } label: { Label("Rename", systemImage: "pencil") }
                                Button(role: .destructive) { store.deleteRoutine(r.id) } label: { Label("Delete routine", systemImage: "trash") }
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
                AddExerciseSheet { v in var rr = r; rr.items.append(RoutineItem(versionId: v.id)); store.put(rr) }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
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
                Text(v?.name ?? "Missing exercise").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                HStack(spacing: 6) {
                    if let g { Text(g.type.label).font(.system(size: 12, weight: .bold)).foregroundStyle(p.accent) }
                    if let v { Text("\(v.equipment.label) · \(v.repRange) reps · \(v.defaultSets) sets").font(.system(size: 12)).foregroundStyle(p.muted) }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
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

    private var split: Split? { store.splits.first { $0.id == splitId } }

    var body: some View {
        if let s = split {
            let inSplit = Set(s.routineIds)
            List {
                Section {
                    ForEach(Array(s.routineIds.enumerated()), id: \.offset) { i, rid in
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted).frame(width: 24)
                            Text(store.routine(rid)?.name ?? "Missing routine").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                            Spacer()
                            Text("\(store.routine(rid)?.items.count ?? 0) ex").font(.system(size: 13)).foregroundStyle(p.muted)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .rowCard(p)
                    }
                    .onMove { from, to in var ss = s; ss.routineIds.move(fromOffsets: from, toOffset: to); store.put(ss) }
                    .onDelete { idx in var ss = s; ss.routineIds.remove(atOffsets: idx); store.put(ss) }
                } header: {
                    SectionLabel("In this split").padding(.leading, 16)
                } footer: {
                    Text("A routine can appear more than once, for example Push, Pull, Legs, Push, Pull, Legs.").font(.system(size: 13)).foregroundStyle(p.muted).padding(.horizontal, 16)
                }
                Section {
                    ForEach(store.routines) { r in
                        HStack {
                            Text(r.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(inSplit.contains(r.id) ? p.muted : p.text)
                            Spacer()
                            Chip(text: "Add", small: true) { var ss = s; ss.routineIds.append(r.id); store.put(ss) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .rowCard(p)
                    }
                } header: {
                    SectionLabel("Add a routine").padding(.leading, 16)
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
        }
    }
}

struct VersionEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let versionId: String

    private var version: Version? { store.version(versionId) }

    var body: some View {
        if let v = version {
            let b = Binding(get: { store.version(versionId) ?? v }, set: { store.put($0) })
            Form {
                Section {
                    TextField("Name", text: b.name)
                    Picker("Muscle", selection: Binding(get: { store.muscle(of: v) ?? .Back }, set: { m in
                        if var e = store.exercise(v.exerciseId) { e.muscleGroup = m; store.put(e) }
                    })) { ForEach(MuscleGroup.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Picker("Equipment", selection: b.equipment) { ForEach(Equipment.allCases, id: \.self) { Text($0.label).tag($0) } }
                    Picker("Arms", selection: b.arms) { Text("Two").tag(Arms.two); Text("One at a time").tag(Arms.one) }
                    TextField("Machine (optional)", text: Binding(get: { v.machine ?? "" }, set: { t in var vv = v; vv.machine = t.isEmpty ? nil : t; store.put(vv) }))
                }
                Section("Rep range") {
                    Stepper("Min \(v.repMin)", value: b.repMin, in: 1...50)
                    Stepper("Max \(v.repMax)", value: b.repMax, in: 1...60)
                    Text("Go up when set 1 reaches \(v.repMax + UP_FIRST_OFFSET) and set 2 reaches \(v.repMax + UP_SECOND_OFFSET). Go down when set 1 is under \(v.repMin).")
                        .font(.system(size: 13)).foregroundStyle(p.muted)
                }
                Section("Defaults") {
                    Stepper("Working sets \(v.defaultSets)", value: b.defaultSets, in: 1...8)
                    Toggle("Warm-up set", isOn: b.defaultWarmup)
                }
                Section("Notes") {
                    TextField("Setup, grip, what to watch", text: Binding(get: { v.notes ?? "" }, set: { t in var vv = v; vv.notes = t.isEmpty ? nil : t; store.put(vv) }), axis: .vertical).lineLimit(2...5)
                }
                Section {
                    NavigationLink { ExerciseProgressView(versionId: v.id) } label: { Label("Progress over time", systemImage: "chart.xyaxis.line") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(p.bg.ignoresSafeArea())
            .tint(p.accent)
            .navigationTitle(v.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(p.bg, for: .navigationBar)
        }
    }
}
