import SwiftUI

/// Type two letters, tap. Searches your versions first, then the library, then offers to create.
struct AddExerciseSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let onPick: (Version) -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private struct Row: Identifiable {
        enum Kind { case version(Version), library(LibraryEntry), create }
        var id: String
        var title: String
        var subtitle: String
        var kind: Kind
    }

    private var rows: [Row] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        var out: [Row] = []
        let versions = store.versions.sorted { $0.name < $1.name }.filter { v in
            q.isEmpty || v.name.lowercased().contains(q) || (store.exercise(v.exerciseId)?.aliases.contains { $0.lowercased().contains(q) } ?? false)
        }
        for v in versions.prefix(q.isEmpty ? 40 : 20) {
            out.append(Row(id: "v" + v.id, title: v.name,
                           subtitle: [store.muscle(of: v)?.rawValue, v.equipment.label, v.repRange + " reps"].compactMap { $0 }.joined(separator: " · "),
                           kind: .version(v)))
        }
        if !q.isEmpty {
            let have = Set(store.versions.map { $0.name.lowercased() })
            for l in LIBRARY where l.name.lowercased().contains(q) && !have.contains(l.name.lowercased()) {
                out.append(Row(id: "l" + l.name, title: l.name, subtitle: "\(l.muscle.rawValue) · \(l.equipment.label) · library", kind: .library(l)))
            }
            if !out.contains(where: { $0.title.lowercased() == q }) {
                out.append(Row(id: "create", title: "Create \"\(query.trimmingCharacters(in: .whitespaces))\"", subtitle: "New exercise, machine, two arms", kind: .create))
            }
        }
        return out
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Add exercise").font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                Spacer()
                Button("Close") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(p.accent)
            }
            TextField("Search or type a new name", text: $query)
                .focused($focused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(12)
                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .foregroundStyle(p.text)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(rows) { r in
                        Button { pick(r) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                                    Text(r.subtitle).font(.system(size: 12)).foregroundStyle(p.muted)
                                }
                                Spacer()
                                Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(p.accent)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        // Focus once the sheet has settled. Focusing during the slide-up animation can leave
        // the field showing a cursor while the keyboard never attaches.
        .task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            focused = true
        }
    }

    private func pick(_ r: Row) {
        switch r.kind {
        case .version(let v): onPick(v)
        case .library(let l): onPick(store.makeVersion(name: l.name, muscle: l.muscle, equipment: l.equipment))
        case .create: onPick(store.makeVersion(name: query.trimmingCharacters(in: .whitespaces), muscle: .Back, equipment: .machine))
        }
        dismiss()
    }
}
