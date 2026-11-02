import SwiftUI

/// One sheet for two jobs:
/// - Duplicate (Michael's pick A): name the copy, untick the exercises to leave out, Create routine.
/// - Edit from the split page (pick 2): remove, reorder or add, then Done. A routine taken from the
///   routine list asks first: Save as new routine, Update it, or Discard changes.
/// Nothing is saved until Create or Done.
struct RoutineDraftSheet: View {
    enum Mode: Equatable {
        case duplicate
        case edit(splitId: String, slot: Int)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    let original: Routine
    /// Duplicate only: the new routine, after the sheet has closed.
    var onCreated: (Routine) -> Void = { _ in }

    @State private var draft: RoutineDraft
    /// Duplicate: the rows unticked, left out of the copy.
    @State private var leftOut: Set<String> = []
    @State private var adding = false
    @State private var fromRoutines = false
    @State private var asking = false
    @State private var naming = false
    @State private var newName = ""
    @State private var taken: NameTaken? = nil
    @FocusState private var nameFocused: Bool

    init(mode: Mode, routine: Routine, takenNames: [String], onCreated: @escaping (Routine) -> Void = { _ in }) {
        self.mode = mode
        self.original = routine
        self.onCreated = onCreated
        _draft = State(initialValue: RoutineDraft(routine, name: mode == .duplicate ? copyName(routine.name, taken: takenNames) : nil))
    }

    private var isDuplicate: Bool { mode == .duplicate }
    private var changed: Bool {
        !draft.matches(original) || !leftOut.isEmpty || (isDuplicate && draft.name != copyName(original.name, taken: store.routines.map(\.name)))
    }
    private var kept: Int { draft.rows.count - leftOut.count }
    /// Duplicate: the name typed is another routine's.
    private var nameTaken: Bool { routineNameTaken(draft.name, in: store.routines) }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                if isDuplicate { nameField }
                rows
                if isDuplicate {
                    PillButton(title: "Create routine", style: .primary, full: true, height: 54) { create() }
                        .disabled(kept == 0 || nameTaken)
                        .opacity(kept == 0 || nameTaken ? 0.4 : 1)
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
                        .background(p.card)
                }
            }
            if asking { changedPanel }
        }
        .background(p.card)
        .interactiveDismissDisabled(changed)
        .alert("New routine", isPresented: $naming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveAsNew() }
        }
        .nameTakenAlert($taken)
        .sheet(isPresented: $adding) {
            AddExerciseSheet { v, st in draft.append(RoutineItem(versionId: v.id, styleId: st?.id)) }
                .presentationDetents([.large])
                .presentationBackground(p.card)
        }
        .sheet(isPresented: $fromRoutines) {
            FromRoutinesSheet(exclude: original.id) { draft.add($0) }
                .presentationDetents([.large])
                .presentationBackground(p.card)
        }
        #if DEBUG
        .task {
            // -routineDemo duplicate: untick the second to last exercise.
            // -routineDemo ask: remove it in the edit sheet, then tap Done.
            guard draft.rows.count > 1 else { return }
            let target = draft.rows[draft.rows.count - 2].id
            if isDuplicate {
                if RoutineDemo.once("untick", for: ["duplicate"]) { leftOut.insert(target) }
            } else if RoutineDemo.once("ask", for: ["ask"]) {
                try? await Task.sleep(nanoseconds: 600_000_000)
                draft.remove(id: target)
                done()
            }
        }
        #endif
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 12) {
            Text(isDuplicate ? "Duplicate" : original.name)
                .font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text).lineLimit(1)
            Spacer()
            Button(isDuplicate ? "Cancel" : "Done") { if isDuplicate { dismiss() } else { done() } }
                .font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
    }

    /// Above the list, never inside it: a field in a List row loses the keyboard when rows change.
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Name").padding(.leading, 4)
            TextField("Name", text: $draft.name)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { nameFocused = false }
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(p.text)
                .padding(.horizontal, 14).frame(height: 48)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            if nameTaken {
                Text("You already have \(draft.name.trimmingCharacters(in: .whitespaces))")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(p.danger)
                    .padding(.leading, 4)
            }
            HStack {
                SectionLabel("Exercises")
                Spacer()
                Text("\(kept) of \(draft.rows.count)").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
            }
            .padding(.horizontal, 4).padding(.top, 12)
        }
        .padding(.horizontal, 20).padding(.bottom, 4)
    }

    private var rows: some View {
        List {
            if isDuplicate {
                ForEach(draft.rows) { row in tickRow(row) }
            } else {
                ForEach(draft.rows) { row in rowView(row) }
                    .onMove { from, to in draft.move(from: from, to: to) }
                PillButton(title: "Add exercise", icon: "plus", full: true) { adding = true }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                PillButton(title: "From my routines", icon: "square.on.square", full: true) { fromRoutines = true }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func exerciseName(_ item: RoutineItem) -> String {
        store.version(item.versionId).map { store.baseName($0) } ?? "Missing exercise"
    }

    /// Name over its chips (and its superset label), the same in both kinds of row.
    private func exerciseLabel(_ row: RoutineDraft.Row) -> some View {
        let v = store.version(row.item.versionId)
        let inGroup = row.item.groupId.map { gid in draft.rows.filter { $0.item.groupId == gid }.count } ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            Text(exerciseName(row.item)).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
            HStack(spacing: 6) {
                if inGroup > 1 {
                    Text(GroupType.forCount(inGroup).label).font(.system(size: 12, weight: .bold)).foregroundStyle(p.accent)
                }
                if let v {
                    VariationChips(tags: store.variationChips(v), size: .small, note: store.style(row.item.styleId)?.label)
                }
            }
        }
    }

    /// Duplicate: tap anywhere on the row to tick or untick it. Unticked rows stay, dimmed.
    private func tickRow(_ row: RoutineDraft.Row) -> some View {
        let on = !leftOut.contains(row.id)
        return Button {
            if on { leftOut.insert(row.id) } else { leftOut.remove(row.id) }
        } label: {
            HStack(spacing: 12) {
                RectCheck(on: on, size: 26)
                exerciseLabel(row).opacity(on ? 1 : 0.45)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(exerciseName(row.item))
        .accessibilityAddTraits(on ? .isSelected : [])
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.elevated)
                .padding(.horizontal, 16).padding(.vertical, 3)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: 28, bottom: 3, trailing: 28))
    }

    /// Edit from the split page: remove on the left, hold and drag to reorder.
    private func rowView(_ row: RoutineDraft.Row) -> some View {
        let name = exerciseName(row.item)
        return HStack(spacing: 12) {
            Button { withAnimation(.snappy) { draft.remove(id: row.id) } } label: {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .heavy)).foregroundStyle(p.danger)
                    .frame(width: 32, height: 32)
                    .background(p.dangerSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -6)
            .accessibilityLabel("Remove \(name)")
            exerciseLabel(row)
            Spacer(minLength: 0)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.border)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.elevated)
                .padding(.horizontal, 16).padding(.vertical, 3)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: 26, bottom: 3, trailing: 28))
    }

    /// Done after a change to a routine from the list.
    private var changedPanel: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { withAnimation(.snappy) { asking = false } }
            VStack(alignment: .leading, spacing: 10) {
                Text("\(original.name) changed").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                Text(routineChanges(from: original.items, to: draft.items) { exerciseName($0) })
                    .font(.system(size: 15)).foregroundStyle(p.secondary)
                    .padding(.bottom, 8)
                PillButton(title: "Save as new routine", style: .primary, full: true, height: 52) {
                    newName = copyName(original.name, taken: store.routines.map(\.name))
                    naming = true
                }
                PillButton(title: "Update \(original.name)", full: true, height: 52) { update() }
                PillButton(title: "Discard changes", style: .danger, full: true, height: 52) { dismiss() }
            }
            .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                    .fill(p.elevated).ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom))
        }
    }

    // MARK: Actions

    private func create() {
        guard !nameTaken else { return }
        draft.remove(ids: leftOut)
        let n = draft.name.trimmingCharacters(in: .whitespaces)
        draft.name = n.isEmpty ? copyName(original.name, taken: store.routines.map(\.name)) : n
        let r = store.createRoutine(from: draft)
        onCreated(r)
        dismiss()
    }

    private func done() {
        guard case let .edit(splitId, _) = mode,
              let split = store.splits.first(where: { $0.id == splitId }),
              !draft.matches(original) else { dismiss(); return }
        if asksBeforeSaving(original.id, in: split, splits: store.splits) {
            nameFocused = false
            withAnimation(.snappy) { asking = true }
        } else {
            store.updateRoutine(draft, routineId: original.id, splitId: splitId, undoable: false)
            dismiss()
        }
    }

    private func update() {
        guard case let .edit(splitId, _) = mode else { return }
        store.updateRoutine(draft, routineId: original.id, splitId: splitId)
        dismiss()
    }

    private func saveAsNew() {
        guard case let .edit(splitId, slot) = mode else { return }
        let n = newName.trimmingCharacters(in: .whitespaces)
        if routineNameTaken(n, in: store.routines) {
            let typed = newName
            taken = NameTaken(name: n) { newName = typed; naming = true }
            return
        }
        draft.name = n.isEmpty ? copyName(original.name, taken: store.routines.map(\.name)) : n
        store.saveAsNewRoutine(draft, splitId: splitId, slot: slot)
        dismiss()
    }
}

/// "Saved Shoulders 2   Undo", for a few seconds on the split page after a routine change.
struct RoutineUndoBar: ViewModifier {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let splitId: String

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let u = store.routineUndo, u.splitId == splitId { bar(u) }
            }
            .animation(.snappy, value: store.routineUndo?.id)
    }

    private func bar(_ u: RoutineUndo) -> some View {
        HStack {
            Text(u.message).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text).lineLimit(1)
            Spacer()
            Button("Undo") { store.undoRoutineChange() }
                .font(.system(size: 16, weight: .heavy)).foregroundStyle(p.accent)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 18).padding(.trailing, 8).frame(height: 56)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .padding(.horizontal, 16).padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: u.id) {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if store.routineUndo?.id == u.id { store.routineUndo = nil }
        }
    }
}

extension View {
    func routineUndoBar(splitId: String) -> some View { modifier(RoutineUndoBar(splitId: splitId)) }
}
