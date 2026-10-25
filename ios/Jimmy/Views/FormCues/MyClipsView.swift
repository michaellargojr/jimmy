import SwiftUI

/// Every stored clip, newest first. Two uses: pick clips to add to a variation, or look
/// after the library from Settings (play, see where a clip is used, delete unused ones).
struct MyClipsView: View {
    enum Mode { case pick(versionId: String), manage }

    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var selected: [String] = []
    @State private var playing: FormCuesView.PlayerStart? = nil

    private var pickingFor: String? { if case .pick(let id) = mode { return id } else { return nil } }

    private var shown: [Clip] {
        let all = store.clips.sorted { $0.addedAt > $1.addedAt }
        guard let id = pickingFor, let v = store.version(id) else { return all }
        return all.filter { !v.clipIds.contains($0.id) }
    }

    var body: some View {
        let list = shown
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Jimmy library").font(.system(size: 28, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
                    Text("\(store.clips.count) clips · \(byteLabel(ClipFiles.totalBytes(store.clips)))")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(p.secondary)
                }
                if list.isEmpty {
                    Text(store.clips.isEmpty ? "No clips yet." : "Every clip is already on this exercise.")
                        .font(.system(size: 15)).foregroundStyle(p.muted).padding(.top, 8)
                }
                LazyVGrid(columns: clipColumns, spacing: 6) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, c in
                        let used = store.usage(of: c.id)
                        Button { tap(c, index: i, list: list) } label: {
                            ClipTile(clip: c, selected: selected.contains(c.id), count: used.count)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { menu(c, used: used, index: i, list: list) }
                    }
                }
            }
            .padding(16)
        }
        .background(p.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(p.bg, for: .navigationBar)
        .toolbar {
            if let id = pickingFor {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.tint(p.accent) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selected.isEmpty ? "Add" : "Add \(selected.count)") {
                        store.attach(clipIds: selected, to: id)
                        dismiss()
                    }
                    .fontWeight(.bold).tint(p.accent).disabled(selected.isEmpty)
                }
            }
        }
        .fullScreenCover(item: $playing) { s in ClipPlayerView(clips: s.clips, start: s.index) }
    }

    private func tap(_ c: Clip, index: Int, list: [Clip]) {
        if pickingFor != nil {
            if let i = selected.firstIndex(of: c.id) { selected.remove(at: i) } else { selected.append(c.id) }
        } else {
            playing = FormCuesView.PlayerStart(clips: list, index: index)
        }
    }

    @ViewBuilder
    private func menu(_ c: Clip, used: [Version], index: Int, list: [Clip]) -> some View {
        Button { playing = FormCuesView.PlayerStart(clips: list, index: index) } label: { Label("Play", systemImage: "play") }
        if !used.isEmpty {
            Section("On") {
                ForEach(used) { v in Text(store.fullName(v)) }
            }
        }
        if pickingFor == nil, used.isEmpty {
            Button(role: .destructive) { store.deleteClip(c.id) } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
