import SwiftUI

/// Plan: full editing of splits, routines and exercises.
struct PlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var segment: Segment = .splits
    @State private var newName = ""
    @State private var naming: Segment? = nil
    @State private var newVersion = false
    @State private var path = NavigationPath()

    enum Segment: String, CaseIterable, Identifiable { case splits = "Splits", routines = "Routines", exercises = "Exercises"; var id: String { rawValue } }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScreenTitle("Plan") {
                    PillButton(title: "New", icon: "plus") {
                        if segment == .exercises { newVersion = true } else { newName = ""; naming = segment }
                    }
                }
                HStack(spacing: 8) {
                    ForEach(Segment.allCases) { s in Chip(text: s.rawValue, on: segment == s) { segment = s } }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
                switch segment {
                case .splits: SplitsList()
                case .routines: RoutinesList()
                case .exercises: ExercisesList()
                }
            }
            .screen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Routine.self) { r in RoutineEditorView(routineId: r.id) }
            .navigationDestination(for: Split.self) { s in SplitEditorView(splitId: s.id) }
            .navigationDestination(for: Version.self) { v in VersionEditorView(versionId: v.id) }
            .navigationDestination(for: Exercise.self) { e in BasePageView(exerciseId: e.id) }
            .alert(naming == .splits ? "New split" : "New routine", isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
                TextField("Name", text: $newName)
                Button("Create") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if naming == .splits {
                        let s = Split(name: name.isEmpty ? "New split" : name)
                        store.put(s)
                        if store.splits.count == 1 { store.update { $0.activeSplitId = s.id } }
                    } else {
                        store.put(Routine(name: name.isEmpty ? "New routine" : name))
                    }
                    naming = nil
                }
                Button("Cancel", role: .cancel) { naming = nil }
            }
            .sheet(isPresented: $newVersion) {
                AddExerciseSheet { _, _ in }
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            #if DEBUG
            .task(id: store.loaded) {
                guard store.loaded, RoutineDemo.once("plan", for: ["split", "edit", "ask", "duplicate", "routines"]) else { return }
                switch RoutineDemo.step {
                case "routines": segment = .routines
                case "duplicate":
                    if let rid = store.activeSplit?.routineIds.first, let r = store.routine(rid) { path.append(r) }
                default:
                    if let s = store.activeSplit { path.append(s) }
                }
            }
            #endif
        }
    }
}

struct SplitsList: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p

    var body: some View {
        List {
            if let active = store.activeSplit {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Active split").font(.system(size: 12, weight: .bold)).tracking(0.7).textCase(.uppercase).foregroundStyle(p.accent)
                                Text(active.name).font(.system(size: 22, weight: .heavy)).tracking(-0.4).foregroundStyle(p.text)
                            }
                            Spacer()
                            NavigationLink(value: active) { Chip(text: "Edit", small: true) }
                        }
                        VStack(spacing: 6) {
                            ForEach(Array(active.routineIds.enumerated()), id: \.offset) { i, rid in
                                if let r = store.routine(rid) {
                                    HStack(spacing: 10) {
                                        Text("\(i + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted).frame(width: 28)
                                        Text(r.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                                        Spacer()
                                        Text("\(r.items.count) ex").font(.system(size: 13)).foregroundStyle(p.muted)
                                        if store.upNextRoutine?.id == r.id { Badge(text: "next", kind: .up) }
                                    }
                                    .padding(.horizontal, 10).frame(height: 44)
                                    .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                                }
                            }
                            if active.routineIds.isEmpty {
                                Text("No routines yet. Tap Edit to add some.").font(.system(size: 13)).foregroundStyle(p.muted)
                            }
                        }
                        Text("Order sets what \"Up next\" shows on Home. The split cycles after the last one.").font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    .padding(18)
                    .rowCard(p, radius: Radius.card)
                }
            }
            Section {
                ForEach(store.splits.filter { $0.id != store.activeSplit?.id }) { s in
                    HStack(spacing: 12) {
                        NavigationLink(value: s) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                                Text("\(s.routineIds.count) routines · not active").font(.system(size: 13)).foregroundStyle(p.muted)
                            }
                        }
                        Spacer()
                        Chip(text: "Use", small: true) { store.update { $0.activeSplitId = s.id } }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .rowCard(p, radius: Radius.card)
                    .swipeActions { Button(role: .destructive) { store.deleteSplit(s.id) } label: { Label("Delete", systemImage: "trash") } }
                }
            }
            if store.splits.isEmpty {
                Text("A split is the order you cycle through routines. Tap New to make one.")
                    .font(.system(size: 14)).foregroundStyle(p.muted).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
        }
        .cardList()
    }
}

struct RoutinesList: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var duplicating: Routine? = nil
    @State private var justMade: Routine? = nil
    @State private var created: Routine? = nil
    @State private var renaming: Routine? = nil
    @State private var newName = ""

    var body: some View {
        List {
            ForEach(store.routines) { r in
                NavigationLink(value: r) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                            Text(r.items.compactMap { store.version($0.versionId).map { store.baseName($0) } }.joined(separator: " - "))
                                .font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(2)
                        }
                        Spacer()
                        Text(routineLast(r, workouts: store.workouts).map { "\(daysBetween($0.date, today()))d" } ?? "never").font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                }
                .rowCard(p, radius: Radius.card)
                .contextMenu { RoutineMenu(rename: { newName = r.name; renaming = r }, duplicate: { duplicating = r }, delete: { store.deleteRoutine(r.id) }) }
                .swipeActions {
                    Button(role: .destructive) { store.deleteRoutine(r.id) } label: { Label("Delete", systemImage: "trash") }
                    Button { duplicating = r } label: { Label("Duplicate", systemImage: "doc.on.doc") }.tint(Color(hex: 0x4A4C55))
                }
            }
            .onMove { from, to in
                var list = store.routines
                list.move(fromOffsets: from, toOffset: to)
                store.routines = list; store.markDirty()
            }
        }
        .cardList()
        // The copy opens once the sheet has gone, or the push is lost under it.
        .sheet(item: $duplicating, onDismiss: { created = justMade; justMade = nil }) { r in
            RoutineDraftSheet(mode: .duplicate, routine: r, takenNames: store.routines.map(\.name)) { justMade = $0 }
                .presentationDetents([.large])
                .presentationBackground(p.card)
        }
        .navigationDestination(item: $created) { c in RoutineEditorView(routineId: c.id) }
        .alert("Rename routine", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                let n = newName.trimmingCharacters(in: .whitespaces)
                if var r = renaming, !n.isEmpty { r.name = n; store.put(r) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }
}

/// What a held routine offers, the same as the ••• menu on its page. Remove takes it out of
/// one split only; Delete takes it out of the app.
struct RoutineMenu: View {
    var rename: () -> Void
    var duplicate: () -> Void
    var remove: (() -> Void)? = nil
    var delete: (() -> Void)? = nil

    var body: some View {
        Button(action: rename) { Label("Rename", systemImage: "pencil") }
        Button(action: duplicate) { Label("Duplicate", systemImage: "doc.on.doc") }
        if let remove { Button(role: .destructive, action: remove) { Label("Remove from split", systemImage: "minus.square") } }
        if let delete { Button(role: .destructive, action: delete) { Label("Delete routine", systemImage: "trash") } }
    }
}
