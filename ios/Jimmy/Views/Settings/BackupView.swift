import SwiftUI
import UniformTypeIdentifiers

/// Settings > Backup: the folder in iCloud Drive, Back up now, and the backups to restore from.
struct BackupView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var picking = false
    @State private var pickFolder = true
    @State private var pending: PendingRestore?
    @State private var error: String?
    @State private var busy = false
    @State private var note: String?

    enum PendingRestore: Identifiable {
        case backup(BackupFile), file(URL)
        var id: String {
            switch self {
            case .backup(let f): return f.id
            case .file(let u): return u.absoluteString
            }
        }
        var title: String {
            switch self {
            case .backup(let f): return "Restore \(backupDay(f.date))?"
            case .file: return "Restore this file?"
            }
        }
    }

    var body: some View {
        let b = store.backups
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if b.hasFolder {
                    Button { pick(folder: true) } label: {
                        SettingsRow(title: "Folder") {
                            Text(b.failed ? "Choose again" : (b.folderLabel ?? ""))
                                .font(.system(size: 14)).foregroundStyle(b.failed ? p.danger : p.muted).lineLimit(1)
                            Chevron()
                        }
                    }
                    .buttonStyle(.plain)
                    .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    PillButton(title: "Back up now", style: .primary, full: true, height: 52) { backUpNow() }
                        .disabled(busy)
                    noteLine
                    if !b.files.isEmpty {
                        SectionLabel("Backups").padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(b.files.enumerated()), id: \.element.id) { i, f in
                                if i > 0 { Divider1() }
                                Button { pending = .backup(f) } label: {
                                    SettingsRow(title: backupDay(f.date), subtitle: subtitle(f)) { EmptyView() }
                                }
                                .buttonStyle(.plain)
                                .disabled(busy)
                            }
                        }
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    textButton("Restore from another file")
                } else {
                    PillButton(title: "Choose a folder", style: .primary, full: true, height: 52) { pick(folder: true) }
                    noteLine
                    textButton("Restore from a file")
                }
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(p.bg, for: .navigationBar)
        .onAppear { b.refresh() }
        // One importer for both pickers: two on one view fight over which one opens.
        .fileImporter(isPresented: $picking, allowedContentTypes: pickFolder ? [.folder] : [.json, .plainText]) { result in
            switch result {
            case .success(let url):
                if pickFolder { chooseFolder(url) } else { pending = .file(url) }
            case .failure(let e):
                error = e.localizedDescription
            }
        }
        .alert(pending?.title ?? "Restore?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), presenting: pending) { r in
            Button("Restore", role: .destructive) { restore(r) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Replaces everything on this phone with this backup.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    @ViewBuilder private var noteLine: some View {
        if let note {
            Text(note).font(.system(size: 15, weight: .bold)).foregroundStyle(p.accent).frame(maxWidth: .infinity)
        }
    }

    private func textButton(_ title: String) -> some View {
        Button { pick(folder: false) } label: {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(p.accent)
                .frame(maxWidth: .infinity).frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    /// "8:14 PM - 12 workouts", or just the time until the file has been read.
    private func subtitle(_ f: BackupFile) -> String {
        let time = backupTime(f.date)
        guard let n = store.backups.counts[f.id] else { return time }
        return "\(time) - \(n) workout\(n == 1 ? "" : "s")"
    }

    private func pick(folder: Bool) {
        pickFolder = folder
        picking = true
    }

    private func chooseFolder(_ url: URL) {
        do {
            try store.backups.setFolder(url)
            backUpNow()
        } catch {
            self.error = "That folder can't be used. \(error.localizedDescription)"
        }
    }

    private func backUpNow() {
        busy = true
        store.backUp { ok in
            busy = false
            if ok { flash("Backed up") } else { error = "The backup couldn't be saved. Choose the folder again." }
        }
    }

    private func restore(_ r: PendingRestore) {
        busy = true
        Task {
            do {
                let s: Snapshot
                switch r {
                case .backup(let f): s = try await store.backups.read(f.url, folder: store.backups.folderURL())
                case .file(let u): s = try await store.backups.read(u, folder: nil)
                }
                store.restore(s)
                flash("Restored")
            } catch {
                self.error = "That backup couldn't be read. \(error.localizedDescription)"
            }
            busy = false
        }
    }

    private func flash(_ text: String) {
        note = text
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if note == text { note = nil }
        }
    }
}
