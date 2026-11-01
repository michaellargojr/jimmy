import SwiftUI

/// The app noticed a style keeps running heavier (or lighter) than the rest of its variation:
/// make it its own variation, or keep it a style. On the Workout tab, so it never shows mid-set.
struct SplitOfferCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let offer: SplitOffer

    var body: some View {
        if let st = store.style(offer.styleId), let v = store.version(offer.versionId) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(st.label) runs \(offer.heavier ? "heavier" : "lighter")")
                        .font(.system(size: 20, weight: .heavy)).tracking(-0.3).foregroundStyle(p.text)
                    VariationChips(tags: store.variationChips(v), size: .small)
                }
                HStack(spacing: 10) {
                    tile(st.label, offer.styleSet, accent: true)
                    tile("The rest", offer.restSet, accent: false)
                }
                PillButton(title: "Make it its own variation", style: .primary, full: true) { store.makeStyleOwnVariation(st.id) }
                Button { store.keepStyle(st.id) } label: {
                    Text("Keep as style").font(.system(size: 15, weight: .semibold)).foregroundStyle(p.secondary)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private func tile(_ title: String, _ s: SetEntry, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(accent ? p.accent : p.secondary).lineLimit(1)
            Text(s.valueText).font(.system(size: 20, weight: .heavy)).monospacedDigit().foregroundStyle(p.text)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }
}
