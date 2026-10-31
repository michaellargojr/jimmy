import SwiftUI

/// Naming a machine in the Machine block: a second machine of a kind, or a kind not in the list.
enum MachineNaming: Equatable {
    /// Another machine of the kind with this name ("Iso-lateral pulldown").
    case another(String)
    case other
}

/// The Machine block: Plates or Stack, then the kinds of machine for this exercise. A kind you
/// don't have yet (or not with this loading) is one tap and becomes its own variation with no
/// question; the switch jumps to how that kind usually comes, and you can switch it. A kind you
/// have shows yours with its last weights, plus Another one to name a second (another gym's).
/// Other names a kind not listed. It writes the pick into `spec` (loading, tag, position, name).
struct MachineBlock: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let base: Exercise
    @Binding var spec: VariationSpec
    @Binding var naming: MachineNaming?
    @Binding var name: String
    @FocusState private var nameFocused: Bool
    @State private var choosing = false

    private var types: [MachineType] { machineTypes(forBase: base.name) }

    /// Your machine that is picked, when it's one you have.
    private var picked: Version? { naming == nil ? store.findVariation(baseId: base.id, key: spec.key) : nil }

    /// The kind that is picked, from the list.
    private var pickedType: MachineType? {
        switch naming {
        case .another(let n)?: return types.first { $0.name == n }
        case .other?: return nil
        case nil: return types.first { $0.fits(tag: spec.tag, position: spec.position) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Machine")
            LoadingSwitch(loading: spec.loading) { setLoading($0) }
                .padding(.bottom, 4)
            ForEach(types) { t in typeRow(t) }
            ForEach(store.unlistedMachines(base: base, arms: spec.arms, loading: spec.loading)) { v in
                mineRow(v, on: picked?.id == v.id, inset: false)
            }
            if types.count > 1 { helpRow }
            otherRow
        }
        .onAppear { if spec.loading == nil { spec = store.withLoading(spec, base: base) } }
        .onChange(of: name) { _, _ in applyName() }
        .sheet(isPresented: $choosing) {
            HelpMeChooseView(base: base, arms: spec.arms, types: types) { t, l in pick(t, loading: l) }
                .presentationDetents([.large]).presentationBackground(p.card)
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func typeRow(_ t: MachineType) -> some View {
        let mine = store.machines(of: t, baseId: base.id, arms: spec.arms, position: spec.position, loading: spec.loading)
        let on = pickedType == t
        if on && !mine.isEmpty {
            // Yours, then Another one for a second machine of this kind.
            VStack(alignment: .leading, spacing: 8) {
                Text(t.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                    .padding(.horizontal, 2)
                ForEach(mine) { v in mineRow(v, on: picked?.id == v.id, inset: true) }
                anotherRow(t)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        } else {
            Button { pick(t) } label: {
                HStack(spacing: 10) {
                    Text(t.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                    Spacer(minLength: 4)
                    if let v = mine.first, let last = lastText(v) {
                        Text(last).font(.system(size: 12.5)).foregroundStyle(p.muted).lineLimit(1)
                    }
                    if on { check }
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(on ? p.accentSoft : p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func mineRow(_ v: Version, on: Bool, inset: Bool) -> some View {
        Button {
            naming = nil; nameFocused = false
            spec.tag = v.tag; spec.position = v.position; spec.machine = v.machine; spec.loading = v.loading
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    VariationChips(tags: store.variationChips(v), size: .small)
                    if let last = lastText(v) {
                        Text(last).font(.system(size: 12.5)).foregroundStyle(p.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if on { check }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(on ? p.accentSoft : (inset ? p.card : p.elevated), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func anotherRow(_ t: MachineType) -> some View {
        let on = naming == .another(t.name)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                naming = .another(t.name); applyName(); nameFocused = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Another one").font(.system(size: 16, weight: .semibold))
                    Spacer(minLength: 4)
                    if on { check }
                }
                .foregroundStyle(p.text)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if on { nameField }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(on ? p.accentSoft : p.card, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }

    /// Help me choose: a few plain questions that narrow the list.
    private var helpRow: some View {
        Button { naming = nil; nameFocused = false; choosing = true } label: {
            HStack(spacing: 10) {
                Text("Help me choose").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                Spacer(minLength: 4)
                Chevron()
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var otherRow: some View {
        let on = naming == .other
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                naming = .other; applyName(); nameFocused = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("Other").font(.system(size: 16, weight: .semibold))
                    Spacer(minLength: 4)
                    if on { check }
                }
                .foregroundStyle(on ? p.text : p.secondary)
                .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if on { nameField }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(on ? p.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(on ? Color.clear : p.border, lineWidth: 1))
    }

    private var nameField: some View {
        TextField("Name", text: $name)
            .focused($nameFocused)
            .textInputAutocapitalization(.words).autocorrectionDisabled()
            .submitLabel(.done)
            .padding(.horizontal, 12).frame(height: 42)
            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .foregroundStyle(p.text)
    }

    private var check: some View {
        Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(p.accent)
    }

    // MARK: Picking

    /// A kind: yours when you have one (with this loading if you have that, else the other),
    /// otherwise a new variation of that kind, loaded the way it usually comes. Help me choose
    /// passes the loading you told it, which wins.
    private func pick(_ t: MachineType, loading told: Loading? = nil) {
        naming = nil; nameFocused = false
        let pos = t.position ?? spec.position
        let mine: (Loading?) -> [Version] = { store.machines(of: t, baseId: base.id, arms: spec.arms, position: pos, loading: $0) }
        let have: [Loading?] = told.map { [$0] } ?? ([spec.loading] + Loading.allCases.filter { $0 != spec.loading }.map { Optional($0) })
        if let v = have.lazy.compactMap({ mine($0).first }).first {
            spec.tag = v.tag; spec.position = v.position; spec.machine = v.machine; spec.loading = v.loading
        } else {
            spec.tag = t.tag
            if let fixed = t.position { spec.position = fixed }
            spec.machine = nil
            spec.loading = told ?? t.loading
        }
    }

    /// Plates or Stack. Picking a machine you have stays on yours; otherwise it's that kind, new.
    private func setLoading(_ l: Loading) {
        spec.loading = l
        guard naming == nil else { return }
        if let t = pickedType {
            spec.machine = store.machines(of: t, baseId: base.id, arms: spec.arms, position: spec.position, loading: l).first?.machine
        } else if let v = store.unlistedMachines(base: base, arms: spec.arms, loading: l).first(where: { $0.loading == l && $0.tag == spec.tag }) {
            spec.machine = v.machine
        }
    }

    /// Writes the typed name into the variation: a second machine's own name, or for Other the
    /// kind it names (a kind from the list when you type one, else a kind of its own).
    private func applyName() {
        switch naming {
        case .another(let n)?:
            if let t = types.first(where: { $0.name == n }) {
                spec.tag = t.tag
                if let pos = t.position { spec.position = pos }
            }
            spec.machine = machineName(name)
        case .other?:
            if let t = machineType(named: name, in: types) {
                spec.tag = t.tag
                if let pos = t.position { spec.position = pos }
            } else {
                spec.tag = machineName(name)
            }
            spec.machine = nil
        case nil:
            break
        }
    }

    private func lastText(_ v: Version) -> String? {
        guard let last = lastSession(versionId: v.id, workouts: store.workouts, versions: store.versions) else { return nil }
        let sets = last.item.sets.filter { $0.isDone }.prefix(2).map { $0.formatted }.joined(separator: ", ")
        return (last.daysAgo == 0 ? "today" : "\(last.daysAgo)d ago") + (sets.isEmpty ? "" : " - " + sets)
    }
}

/// Plates or Stack, the one picked lit. Neither is lit for a machine named before the list.
struct LoadingSwitch: View {
    @Environment(\.palette) private var p
    let loading: Loading?
    /// Ways it can't switch to (you have that machine the other way already).
    var disabled: Set<Loading> = []
    let onPick: (Loading) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Loading.allCases, id: \.self) { l in
                let on = loading == l
                Button { onPick(l) } label: {
                    Text(capitalized(l.label)).font(.system(size: 15, weight: on ? .bold : .semibold))
                        .foregroundStyle(on ? p.onAccent : p.secondary)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(disabled.contains(l)).opacity(disabled.contains(l) ? 0.4 : 1)
            }
        }
    }
}

/// The two ways a named machine can go, the app's pick lit: its own variation, or a style.
struct VariationOrStyle: View {
    @Environment(\.palette) private var p
    let asVariation: Bool
    let onPick: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            segment("New variation", on: asVariation) { onPick(true) }
            segment("New style", on: !asVariation) { onPick(false) }
        }
    }

    private func segment(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: on ? .bold : .semibold))
                .foregroundStyle(on ? p.onAccent : p.secondary)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(on ? p.accent : p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
