import SwiftUI

/// The ··· menu on a variation's history page: copy or move its sessions to another exercise,
/// or erase them. Move and Erase each ask "Are you sure?", then a short Undo bar shows.
struct HistoryToolsMenu: ViewModifier {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let versionId: String

    private struct Target: Equatable { var version: Version; var styleId: String? }

    @State private var picking = false
    @State private var target: Target? = nil
    @State private var choosing = false
    @State private var sureMove = false
    @State private var sureErase = false
    @State private var landed: Version? = nil

    func body(content: Content) -> some View {
        let v = store.version(versionId)
        let n = historySessions(versionId, workouts: store.workouts).count
        let name = v.map { store.workoutName($0) } ?? ""
        content
            .toolbar {
                if n > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { target = nil; picking = true } label: { Label("Copy history to…", systemImage: "doc.on.doc") }
                            Button(role: .destructive) { sureErase = true } label: { Label("Erase history", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).foregroundStyle(p.text)
                                .frame(width: 44, height: 34)
                                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        }
                        .accessibilityLabel("More")
                    }
                }
            }
            // The usual exercise search, titled "Copy to". Picking can make a new variation on the spot.
            .sheet(isPresented: $picking, onDismiss: { if target != nil { choosing = true } }) {
                AddExerciseSheet(title: "Copy to") { picked, style in
                    if picked.id != versionId { target = Target(version: picked, styleId: style?.id) }
                }
                .presentationDetents([.large])
                .presentationBackground(p.card)
            }
            .confirmationDialog(target.map { "\(sessionsText(n)) to \(store.workoutName($0.version))" } ?? "",
                                isPresented: $choosing, titleVisibility: .visible) {
                Button("Copy") { run(move: false) }
                Button("Move", role: .destructive) { sureMove = true }
                Button("Cancel", role: .cancel) { target = nil }
            }
            .alert("Are you sure?", isPresented: $sureMove) {
                Button("Move", role: .destructive) { run(move: true) }
                Button("Cancel", role: .cancel) { target = nil }
            } message: {
                Text("\(name) loses \(sessionsText(n)).")
            }
            .alert("Are you sure?", isPresented: $sureErase) {
                Button("Erase", role: .destructive) { if let v { store.eraseHistory(v) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Erase \(sessionsText(n)) of \(name).")
            }
            .navigationDestination(item: $landed) { t in ExerciseProgressView(versionId: t.id) }
            .overlay(alignment: .bottom) {
                if let u = store.historyUndo, u.landedOn == versionId { undoBar(u) }
            }
            .animation(.snappy, value: store.historyUndo?.id)
    }

    private func run(move: Bool) {
        guard let v = store.version(versionId), let t = target else { return }
        store.copyHistory(from: v, to: t.version, styleId: t.styleId, move: move)
        target = nil
        landed = store.version(t.version.id)
    }

    private func undoBar(_ u: HistoryUndo) -> some View {
        HStack {
            Text(u.message).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
            Spacer()
            Button("Undo") {
                store.undoHistory()
                // After a copy or move this page is the one it landed on: go back to where it came from.
                if u.kind != .erase { dismiss() }
            }
            .font(.system(size: 16, weight: .heavy)).foregroundStyle(p.accent)
        }
        .padding(.horizontal, 18).frame(height: 56)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .padding(.horizontal, 16).padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: u.id) {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if store.historyUndo?.id == u.id { store.historyUndo = nil }
        }
    }
}

extension View {
    func historyTools(versionId: String) -> some View { modifier(HistoryToolsMenu(versionId: versionId)) }
}
