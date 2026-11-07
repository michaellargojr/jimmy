import SwiftUI

/// Fix how a variation is set up: the same Variation block and Nickname as adding one. Its
/// history, styles and routines stay with it. An edit that would match another variation of the
/// exercise can't be saved.
struct EditVariationSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let version: Version
    @State private var spec: VariationSpec
    @State private var nick: String

    init(version: Version) {
        self.version = version
        _spec = State(initialValue: VariationSpec(version))
        _nick = State(initialValue: version.nickname ?? "")
    }

    var body: some View {
        let b = store.base(of: version)
        let clash = store.variationClash(version.id, spec: spec, nickname: nick)
        let edited = store.editedSpec(version, spec)
        let changed = edited.key != version.key || cleanNickname(nick) != cleanNickname(version.nickname)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edit variation").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                        Text(store.baseName(version)).font(.system(size: 13)).foregroundStyle(p.muted)
                    }
                    Spacer()
                    Button("Close") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
                }
                Card(padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel("Variation")
                        VariationFields(legs: b?.isLegs ?? false, armRow: b?.hasArmPosition ?? false, spec: $spec)
                        if spec.family == .machine {
                            TextField("Machine name", text: Binding(get: { spec.machine ?? "" }, set: { spec.machine = $0.isEmpty ? nil : $0 }))
                                .textInputAutocapitalization(.words).autocorrectionDisabled()
                                .padding(.horizontal, 12).frame(height: 40)
                                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                                .foregroundStyle(p.text)
                        }
                        Rectangle().fill(p.line).frame(height: 1).padding(.vertical, 2)
                        SectionLabel("Nickname")
                        NicknameField(text: $nick)
                    }
                }
                if clash != nil {
                    Text("Matches a variation you have").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.muted)
                        .frame(minHeight: 24)
                }
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 16).padding(.top, 16)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            let can = changed && clash == nil
            PillButton(title: "Save", style: .primary, full: true) {
                if store.editVariation(version.id, spec: spec, nickname: nick) { dismiss() }
            }
            .disabled(!can).opacity(can ? 1 : 0.4)
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 16)
            .background(p.card)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
