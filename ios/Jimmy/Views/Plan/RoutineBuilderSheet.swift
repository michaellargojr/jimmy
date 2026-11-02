import SwiftUI

/// The routine builder (Michael's picks A and 1). New routine: name it, then tick exercises out of
/// your routines (tap one to open it) or from your variations, and Create routine. From a
/// routine's page or the split page's edit sheet it is the same without the name, and Add.
/// Nothing is saved until Create or Add.
struct RoutineBuilderSheet: View {
    enum Mode: Equatable {
        case create
        /// Adding to a routine, which is left out of the Routines tab.
        case add(to: String)
    }
    private enum Tab { case routines, exercises }

    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    /// The name (create only) and the rows, once Create or Add is tapped.
    let onDone: (String, PickedExercises) -> Void

    @State private var name = ""
    @State private var tab: Tab = .routines
    @State private var picks: [BuilderPick] = []
    /// The routine opened in the Routines tab.
    @State private var open: String? = nil
    @State private var muscle: MuscleGroup? = nil
    @State private var groups: [MuscleVariations] = []
    @State private var newExercise = false
    @FocusState private var nameFocused: Bool

    private var isCreate: Bool { mode == .create }
    private var routines: [Routine] {
        let skip: String? = { if case let .add(id) = mode { return id }; return nil }()
        return store.routines.filter { $0.id != skip && !$0.items.isEmpty }
    }
    private var nameTaken: Bool { isCreate && routineNameTaken(name, in: store.routines) }
    private var canFinish: Bool { !picks.isEmpty && !nameTaken }
    private var buttonTitle: String {
        let n = picks.count
        let ex = n == 1 ? "1 exercise" : "\(n) exercises"
        if isCreate { return n == 0 ? "Create routine" : "Create routine - \(ex)" }
        return n == 0 ? "Add exercises" : "Add \(ex)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let rid = open, let r = routines.first(where: { $0.id == rid }) {
                insideHeader(r)
                List {
                    ForEach(r.items.indices, id: \.self) { i in routineRow(r, i) }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            } else {
                header
                if isCreate { nameField }
                tabs
                if tab == .routines { routineList } else { exerciseList }
            }
            PillButton(title: buttonTitle, style: .primary, full: true, height: 54) { finish() }
                .disabled(!canFinish)
                .opacity(canFinish ? 1 : 0.4)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
                .background(p.card)
        }
        .background(p.card)
        .interactiveDismissDisabled(!picks.isEmpty || !name.trimmingCharacters(in: .whitespaces).isEmpty)
        .sheet(isPresented: $newExercise) {
            AddExerciseSheet { v, st in picks.append(.variation(versionId: v.id, styleId: st?.id)) }
                .presentationDetents([.large])
                .presentationBackground(p.card)
        }
        .onAppear {
            reloadGroups()
            if routines.isEmpty { tab = .exercises }
        }
        .onChange(of: store.versions.count) { _, _ in reloadGroups() }
        .task {
            guard isCreate else { return }
            // Focus once the sheet has settled, or the keyboard never attaches.
            try? await Task.sleep(nanoseconds: 450_000_000)
            nameFocused = true
        }
    }

    // MARK: Top

    private var header: some View {
        HStack(spacing: 12) {
            Text(isCreate ? "New routine" : "Add exercises")
                .font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text).lineLimit(1)
            Spacer()
            Button("Cancel") { dismiss() }
                .font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
    }

    /// Above the lists, never inside one: a field in a List row loses the keyboard when rows change.
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Name").padding(.leading, 4)
            TextField("Name", text: $name)
                .focused($nameFocused)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { nameFocused = false }
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(p.text)
                .padding(.horizontal, 14).frame(height: 48)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            if nameTaken {
                Text("You already have \(name.trimmingCharacters(in: .whitespaces))")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(p.danger)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            Chip(text: "Routines", on: tab == .routines) { nameFocused = false; tab = .routines }
            Chip(text: "Exercises", on: tab == .exercises) { nameFocused = false; tab = .exercises }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    // MARK: Routines

    private var routineList: some View {
        List {
            if routines.isEmpty {
                Text("No routines with exercises yet.")
                    .font(.system(size: 15)).foregroundStyle(p.muted)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(routines) { r in
                Button { nameFocused = false; open = r.id } label: { routineCard(r) }
                    .buttonStyle(.plain)
                    .pickRow(p)
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
    }

    private func routineCard(_ r: Routine) -> some View {
        let n = picks.filter { if case let .routine(pk) = $0 { return pk.routineId == r.id }; return false }.count
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(r.name).font(.system(size: 17, weight: .bold)).foregroundStyle(p.text).lineLimit(1)
                Text(r.items.compactMap { store.version($0.versionId).map { store.baseName($0) } }.joined(separator: " - "))
                    .font(.system(size: 13)).foregroundStyle(p.muted).lineLimit(2)
            }
            Spacer(minLength: 8)
            if n > 0 {
                Text("\(n) added").font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent).fixedSize()
            }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func insideHeader(_ r: Routine) -> some View {
        let mine = r.items.indices.map { BuilderPick.routine(RoutinePick(routineId: r.id, index: $0)) }
        let all = mine.allSatisfy { picks.contains($0) }
        return HStack(spacing: 12) {
            Button { open = nil } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(p.text)
                    .frame(width: 44, height: 44)
                    .background(p.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Text(r.name).font(.system(size: 20, weight: .heavy)).foregroundStyle(p.text).lineLimit(1)
            Spacer(minLength: 8)
            Button(all ? "Remove all" : "Add all") {
                if all { picks.removeAll { mine.contains($0) } } else { picks.append(contentsOf: mine.filter { !picks.contains($0) }) }
            }
            .font(.system(size: 17, weight: .bold)).foregroundStyle(p.accent)
            .frame(minHeight: 44)
            .fixedSize()
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    private func routineRow(_ r: Routine, _ i: Int) -> some View {
        let pick = BuilderPick.routine(RoutinePick(routineId: r.id, index: i))
        let on = picks.contains(pick)
        let item = r.items[i]
        let v = store.version(item.versionId)
        let inGroup = item.groupId.map { gid in r.items.filter { $0.groupId == gid }.count } ?? 0
        return Button { toggle(pick) } label: {
            pickLabel(on: on, name: v.map { store.baseName($0) } ?? "Missing exercise", v: v,
                      style: store.style(item.styleId)?.label,
                      group: inGroup > 1 ? GroupType.forCount(inGroup).label : nil,
                      note: v.map { useNote($0.id) })
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .pickRow(p)
    }

    // MARK: Exercises (your variations)

    private var shownGroups: [MuscleVariations] { muscle.map { m in groups.filter { $0.muscle == m } } ?? groups }

    private var exerciseList: some View {
        VStack(spacing: 0) {
            PillButton(title: "New exercise", icon: "plus", full: true) { nameFocused = false; newExercise = true }
                .padding(.horizontal, 16).padding(.bottom, 8)
            if groups.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(groups) { g in
                            Chip(text: g.muscle.label, on: muscle == g.muscle, small: true) { muscle = muscle == g.muscle ? nil : g.muscle }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 4)
            }
            List {
                ForEach(shownGroups) { g in
                    SectionLabel(g.muscle.label)
                        .padding(.leading, 12).padding(.top, 8)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 2, trailing: 16))
                    ForEach(g.list) { u in variationRow(u) }
                }
                if groups.isEmpty {
                    Text("No exercises yet. Tap New exercise.")
                        .font(.system(size: 15)).foregroundStyle(p.muted)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
        }
    }

    /// Ticked when the variation is in the new routine, from either tab. Unticking takes every one out.
    private func variationRow(_ u: VariationUse) -> some View {
        let on = picks.contains { versionId(of: $0) == u.id }
        return Button {
            if on { picks.removeAll { versionId(of: $0) == u.id } }
            else { picks.append(.variation(versionId: u.id, styleId: lastStyleId(u.id, workouts: store.workouts))) }
        } label: {
            pickLabel(on: on, name: u.baseName, v: u.version, style: nil, group: nil, note: u.note)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .pickRow(p)
    }

    // MARK: Pieces

    private func pickLabel(on: Bool, name: String, v: Version?, style: String?, group: String?, note: String?) -> some View {
        HStack(spacing: 12) {
            RectCheck(on: on, size: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
                HStack(spacing: 6) {
                    if let group { Text(group).font(.system(size: 12, weight: .bold)).foregroundStyle(p.accent) }
                    if let v {
                        VariationChips(tags: store.variationChips(v), size: .small,
                                       note: [style, note].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - "),
                                       nickname: store.nickname(v))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func useNote(_ versionId: String) -> String {
        groups.lazy.flatMap(\.list).first { $0.id == versionId }?.note ?? "Not done yet"
    }

    private func versionId(of pick: BuilderPick) -> String? {
        switch pick {
        case let .variation(v, _): return v
        case let .routine(pk):
            guard let r = store.routine(pk.routineId), r.items.indices.contains(pk.index) else { return nil }
            return r.items[pk.index].versionId
        }
    }

    private func toggle(_ pick: BuilderPick) {
        if let i = picks.firstIndex(of: pick) { picks.remove(at: i) } else { picks.append(pick) }
    }

    private func reloadGroups() {
        groups = variationsByMuscle(versions: store.versions, exercises: store.exercises, workouts: store.workouts)
    }

    private func finish() {
        guard canFinish else { return }
        nameFocused = false
        onDone(newRoutineName(name, taken: store.routines.map(\.name)), builtExercises(picks, routines: store.routines))
        dismiss()
    }
}

private extension View {
    /// A row on the sheet: its own rounded card, a little apart from the next.
    func pickRow(_ p: Palette) -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.elevated)
                .padding(.horizontal, 16).padding(.vertical, 3)
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: 28, bottom: 3, trailing: 28))
    }
}
