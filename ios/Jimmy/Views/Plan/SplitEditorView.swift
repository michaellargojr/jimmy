import SwiftUI

/// A split's page (Michael, Nov 2): Goals; "In this split", the routines in their order with Edit
/// beside the title; Coverage; Notes at the very bottom (splitSections). Tap a routine to edit its
/// exercises, hold one for Rename, Duplicate or Remove. Edit opens the Edit split sheet for
/// everything else. A split with no routines yet opens straight on that sheet.
struct SplitEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let splitId: String
    @State private var renaming = false
    @State private var name = ""
    @State private var goals = false
    @State private var editingSplit = false
    @State private var editing: SlotEdit? = nil
    @State private var duplicating: Routine? = nil
    @State private var copySpot: Int? = nil
    @State private var renamingRoutine: Routine? = nil
    @State private var routineName = ""
    @State private var taken: NameTaken? = nil
    /// Notes edit a local draft and save when you leave the field, so typing never re-lays the page.
    @FocusState private var notesFocused: Bool
    @State private var draftNotes = ""
    @State private var opened = false

    /// One spot of the cycle opened in the edit sheet.
    struct SlotEdit: Identifiable { let id = uid(); let routine: Routine; let slot: Int }

    private var split: Split? { store.splits.first { $0.id == splitId } }

    var body: some View {
        if let s = split {
            List {
                ForEach(splitSections(active: store.activeSplit?.id == s.id), id: \.self) { section in
                    switch section {
                    case .goals: goalsSection(s)
                    case .inSplit: inSplitSection(s)
                    case .coverage: coverageSection(s)
                    case .use: useSection(s)
                    case .notes: notesSection
                    }
                }
            }
            .cardList()
            .navigationTitle(s.name)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { name = s.name; renaming = true } label: { Label("Rename", systemImage: "pencil") }
                        Button(role: .destructive) { store.deleteSplit(s.id) } label: { Label("Delete split", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis") }
                }
            }
            .alert("Rename split", isPresented: $renaming) {
                TextField("Name", text: $name)
                Button("Save") { var ss = s; ss.name = name.trimmingCharacters(in: .whitespaces); if !ss.name.isEmpty { store.put(ss) } }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $goals) {
                GoalsSheet(splitId: s.id)
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .sheet(isPresented: $editingSplit) {
                SplitEditSheet(splitId: s.id)
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            .sheet(item: $editing) { e in
                RoutineDraftSheet(mode: .edit(splitId: s.id, slot: e.slot), routine: e.routine, takenNames: store.routines.map(\.name))
                    .presentationDetents([.large])
                    .presentationBackground(p.card)
            }
            // A copy made here goes right after the routine it came from, with Undo. The page stays put.
            .sheet(item: $duplicating) { r in
                RoutineDraftSheet(mode: .duplicate, routine: r, takenNames: store.routines.map(\.name)) {
                    store.addCopy($0, toSplit: s.id, at: copySpot)
                }
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
            .onChange(of: notesFocused) { _, _ in commitNotes() }
            .onDisappear { commitNotes() }
            .task {
                guard !opened else { return }
                opened = true
                draftNotes = s.notes ?? ""
                #if DEBUG
                if RoutineDemo.once("edit", for: ["edit", "ask"]), let rid = s.routineIds.first, let r = store.routine(rid) {
                    editing = SlotEdit(routine: r, slot: 0)
                    return
                }
                #endif
                // A new split: straight to putting it together, once the page has settled.
                if s.routineIds.isEmpty {
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    editingSplit = true
                }
            }
        }
    }

    private func commitNotes() {
        guard opened, var s = split else { return }
        let notes = draftNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if (notes.isEmpty ? nil : notes) != s.notes { s.notes = notes.isEmpty ? nil : notes; store.put(s) }
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

    private func useSection(_ s: Split) -> some View {
        Section {
            PillButton(title: "Use this split", style: .primary, full: true) { store.update { $0.activeSplitId = s.id } }
                .buttonRow()
        }
    }

    private func inSplitSection(_ s: Split) -> some View {
        Section {
            PartTitle(title: "In this split", button: "Edit") { editingSplit = true }
            if s.routineIds.isEmpty {
                Text("No routines yet. Tap Edit to add some.")
                    .font(.system(size: 14)).foregroundStyle(p.muted)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20))
            }
            ForEach(Array(s.routineIds.enumerated()), id: \.offset) { i, rid in
                Button {
                    if let r = store.routine(rid) { editing = SlotEdit(routine: r, slot: i) }
                } label: {
                    HStack(spacing: 12) {
                        DayNumber(n: i + 1)
                        Text(store.routine(rid)?.name ?? "Missing routine").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                        Spacer()
                        Text("\(store.routine(rid)?.items.count ?? 0) ex").font(.system(size: 13)).foregroundStyle(p.muted)
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.border)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rowCard(p)
                .contextMenu {
                    if let r = store.routine(rid) {
                        RoutineMenu(rename: { routineName = r.name; renamingRoutine = r },
                                    duplicate: { copySpot = i + 1; duplicating = r },
                                    remove: { var ss = s; if ss.routineIds.indices.contains(i) { ss.routineIds.remove(at: i) }; store.put(ss) })
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        Section {
            TextField("Notes", text: $draftNotes, axis: .vertical)
                .lineLimit(3...10)
                .focused($notesFocused)
                .font(.system(size: 16)).foregroundStyle(p.text)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .keepsKeyboard()
                .rowCard(p, radius: Radius.card)
        } header: {
            SectionLabel("Notes").padding(.leading, 16)
        }
    }
}
