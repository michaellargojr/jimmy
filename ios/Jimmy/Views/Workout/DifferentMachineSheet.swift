import SwiftUI

/// Mid-workout at another gym: pick the machine you're on. Yours of each kind, a kind you haven't
/// used yet, or another one by name. The card switches to it, sets logged so far included.
struct DifferentMachineSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let version: Version
    let onPick: (Version) -> Void

    @State private var spec: VariationSpec
    @State private var naming: MachineNaming? = nil
    @State private var name = ""

    init(version: Version, onPick: @escaping (Version) -> Void) {
        self.version = version; self.onPick = onPick
        _spec = State(initialValue: VariationSpec(version))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Different machine").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                    Spacer()
                    Button("Close") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
                }
                if let b = store.base(of: version) {
                    MachineBlock(base: b, spec: $spec, naming: $naming, name: $name)
                    let same = naming == nil && store.findVariation(baseId: b.id, key: spec.key)?.id == version.id
                    let needsName = naming != nil && machineName(name) == nil
                    PillButton(title: "Switch", style: .primary, full: true) {
                        let v = store.makeVariation(base: b, spec: spec, like: version)
                        onPick(v)
                        dismiss()
                    }
                    .disabled(same || needsName).opacity(same || needsName ? 0.4 : 1)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
